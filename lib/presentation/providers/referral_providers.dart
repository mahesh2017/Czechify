import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/monetization/monetization_api.dart';
import '../../data/referrals/play_integrity_service.dart';
import '../../data/referrals/referral_api.dart';
import '../../data/referrals/referral_integrity_consent.dart';
import '../../data/referrals/referral_store.dart';
import '../../data/referrals/referral_uploader.dart';
import 'account_providers.dart';
import 'monetization_providers.dart';
import 'billing_providers.dart';
import 'database_providers.dart';
import 'sync_providers.dart';

final referralStoreProvider = Provider<ReferralStore>(
  (ref) => ReferralStore(ref.watch(databaseProvider)),
);

final referralApiProvider = Provider<ReferralApi?>((ref) {
  final client = ref.watch(backendServiceProvider).client;
  return client == null ? null : ReferralApi(supabaseMonetizationCall(client));
});

final playIntegrityServiceProvider = Provider<PlayIntegrityService>(
  (ref) => const AndroidPlayIntegrityService(),
);

/// Null without a backend: receipts then simply wait in the outbox.
final referralUploaderProvider = Provider<ReferralUploader?>((ref) {
  final api = ref.watch(referralApiProvider);
  if (api == null) return null;
  final backend = ref.watch(backendServiceProvider);
  return ReferralUploader(
    store: ref.watch(referralStoreProvider),
    api: api,
    integrity: ref.watch(playIntegrityServiceProvider),
    currentAccount: () => backend.userId,
    integrityAllowed: ReferralIntegrityConsent.granted,
  );
});

/// This account's Play Integrity choice for its invitation; off until chosen.
final referralIntegrityConsentProvider = FutureProvider<bool>((ref) async {
  ref.watch(accountUserProvider.select((user) => user.value?.id));
  final account = ref.read(backendServiceProvider).userId;
  return account != null && await ReferralIntegrityConsent.granted(account);
});

/// Records the choice; receipts already waiting follow the new answer.
final setReferralIntegrityConsentProvider =
    Provider<Future<void> Function(bool)>(
      (ref) => (granted) async {
        final account = ref.read(backendServiceProvider).userId;
        if (account == null) return;
        await ReferralIntegrityConsent.set(account, granted);
        ref.invalidate(referralIntegrityConsentProvider);
      },
    );

/// Starts one upload pass. Never throws: failures stay queued in the outbox.
void drainReferralReceipts(Ref ref) {
  final uploader = ref.read(referralUploaderProvider);
  if (uploader == null) return;
  unawaited(uploader.drain().catchError((Object _) {}));
}

/// Uploads anything left from earlier sessions once the backend is up.
final referralUploadBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(backendInitProvider.future);
  ref.watch(accountUserProvider.select((user) => user.value?.id));
  await recoverReferralClaim(ref);
  if (ref.mounted) drainReferralReceipts(ref);
});

/// Claims an invite code for the signed-in account. Returns null on success,
/// otherwise the server's refusal code for the screen to explain.
final referralClaimProvider = Provider<Future<String?> Function(String code)>(
  (ref) => (code) async {
    final api = ref.read(referralApiProvider);
    final account = ref.read(backendServiceProvider).userId;
    if (api == null || account == null) return 'verification_unavailable';
    final result = await api.claim(code);
    final claimId = result.claimId;
    if (claimId == null) return result.code;
    // The session may have changed while the claim was in flight.
    if (!ref.mounted || ref.read(backendServiceProvider).userId != account) {
      return 'verification_unavailable';
    }
    await ref
        .read(referralStoreProvider)
        .saveClaim(account, claimId, DateTime.now().toUtc());
    return null;
  },
);

/// Shows invitations in staging builds before the server opens them for a
/// cohort. The server still refuses codes and claims while it is closed.
const referralsPreview = bool.fromEnvironment('MONETIZATION_REFERRALS_PREVIEW');

/// Whether invitations are offered. Off unless the server opens them.
final referralsEnabledProvider = FutureProvider<bool>((ref) async {
  if (referralsPreview) return true;
  return (await ref.watch(
    monetizationConfigurationProvider.future,
  )).referralClaimsEnabled;
});

/// The account's referral picture: its code, units earned, friends by number
/// and its own progress as an invited learner. Null when it cannot load.
final referralStatusProvider = FutureProvider.autoDispose<ReferralStatus?>((
  ref,
) async {
  ref.watch(accountUserProvider.select((user) => user.value?.id));
  final api = ref.watch(referralApiProvider);
  if (api == null) return null;
  final account = ref.read(backendServiceProvider).userId;
  final status = await api.status();
  if (!ref.mounted ||
      account == null ||
      ref.read(backendServiceProvider).userId != account) {
    return null;
  }
  final claimId = status?.ownClaim?.claimId;
  if (claimId != null) {
    await ref
        .read(referralStoreProvider)
        .saveClaim(account, claimId, DateTime.now().toUtc());
  }
  if (!ref.mounted || ref.read(backendServiceProvider).userId != account) {
    return null;
  }
  // Reward status is not itself authorization. Fetch a new signed snapshot.
  ref.invalidate(monetizationLoadProvider);
  return status;
});

/// Recover server attribution after reinstall/switch before collecting evidence.
/// Offline learners keep their existing account-scoped local claim.
Future<String?> recoverReferralClaim(Ref ref) async {
  final account = ref.read(backendServiceProvider).userId;
  if (account == null) return null;
  final store = ref.read(referralStoreProvider);
  final local = await store.activeClaim(account);
  if (!ref.mounted || ref.read(backendServiceProvider).userId != account) {
    return null;
  }
  if (local != null) return local;
  try {
    final status = await ref
        .read(referralApiProvider)
        ?.status()
        .timeout(const Duration(seconds: 3));
    if (!ref.mounted || ref.read(backendServiceProvider).userId != account) {
      return null;
    }
    final claimId = status?.ownClaim?.claimId;
    if (claimId != null) {
      await store.saveClaim(account, claimId, DateTime.now().toUtc());
    }
    return ref.mounted && ref.read(backendServiceProvider).userId == account
        ? claimId
        : null;
  } catch (_) {
    return null;
  }
}
