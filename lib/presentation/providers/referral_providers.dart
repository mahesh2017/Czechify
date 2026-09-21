import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/monetization/monetization_api.dart';
import '../../data/referrals/play_integrity_service.dart';
import '../../data/referrals/referral_api.dart';
import '../../data/referrals/referral_store.dart';
import '../../data/referrals/referral_uploader.dart';
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
  );
});

/// Starts one upload pass. Never throws: failures stay queued in the outbox.
void drainReferralReceipts(Ref ref) {
  final uploader = ref.read(referralUploaderProvider);
  if (uploader == null) return;
  unawaited(uploader.drain().catchError((Object _) {}));
}

/// Uploads anything left from earlier sessions once the backend is up.
final referralUploadBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(backendInitProvider.future);
  drainReferralReceipts(ref);
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
    if (ref.read(backendServiceProvider).userId != account) {
      return 'verification_unavailable';
    }
    await ref
        .read(referralStoreProvider)
        .saveClaim(account, claimId, DateTime.now().toUtc());
    return null;
  },
);
