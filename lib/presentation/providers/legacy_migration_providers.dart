import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/monetization/monetization_api.dart';
import '../../domain/entities/legacy_lesson_record.dart';
import 'account_providers.dart';
import 'billing_providers.dart';
import 'course_admission_providers.dart';
import 'database_providers.dart';
import 'monetization_providers.dart';
import 'sync_providers.dart';

/// The existing-user migration for the signed-in account, or null when there
/// is nothing to explain: the paywall is off, no migration was applied, or
/// the server could not be reached.
final legacyMigrationStatusProvider = FutureProvider<LegacyMigrationStatus?>((
  ref,
) async {
  await ref.watch(backendInitProvider.future);
  ref.watch(accountUserProvider.select((user) => user.value?.id));
  // Grace and kept units only matter once the course has a paywall.
  if (!await ref.watch(coursePaywallEnabledProvider.future)) return null;
  final api = ref.watch(monetizationApiProvider);
  if (api == null) return null;
  try {
    return await api.fetchLegacyStatus().timeout(const Duration(seconds: 5));
  } on TimeoutException {
    return null;
  }
});

/// This device's record from before the cutoff, when it could still be
/// claimed and would reach a unit the account does not already keep.
final legacyLessonRecordProvider = FutureProvider<LegacyLessonRecord?>((
  ref,
) async {
  final status = await ref.watch(legacyMigrationStatusProvider.future);
  if (status == null || !status.canClaim) return null;
  final record = await ref
      .read(databaseProvider)
      .progressDao
      .legacyLessonRecord(status.cutoffAt);
  return record.isEmpty || !record.addsTo(status.legacyUnitIds) ? null : record;
});

/// Sends this device's record as the account's one offline claim. Returns
/// the server's answer, or throws [LegacyClaimException] with its code.
final legacyClaimProvider = Provider<Future<LegacyClaim> Function()>(
  (ref) => () async {
    final api = ref.read(monetizationApiProvider);
    final account = ref.read(backendServiceProvider).userId;
    final record = await ref.read(legacyLessonRecordProvider.future);
    if (api == null || account == null || record == null) {
      throw const LegacyClaimException('verification_unavailable');
    }
    final claim = await api.submitLegacyClaim(
      completedLessonIds: record.completedLessonIds.toList()..sort(),
      attemptedLessonIds: record.attemptedLessonIds.toList()..sort(),
    );
    // The session may have changed while the claim was in flight; the new
    // account's screens must not show this answer.
    if (!ref.mounted || ref.read(backendServiceProvider).userId != account) {
      throw const LegacyClaimException('verification_unavailable');
    }
    ref.invalidate(legacyMigrationStatusProvider);
    ref.invalidate(monetizationLoadProvider);
    return claim;
  },
);

String _dismissedKey(String account) => 'legacy_notice_dismissed_v1:$account';

/// Whether this account put away the explanation on Home. The upgrade screen
/// always shows it.
final legacyNoticeDismissedProvider = FutureProvider<bool>((ref) async {
  ref.watch(accountUserProvider.select((user) => user.value?.id));
  final account = ref.read(backendServiceProvider).userId;
  if (account == null) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_dismissedKey(account)) ?? false;
});

final dismissLegacyNoticeProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final account = ref.read(backendServiceProvider).userId;
    if (account == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey(account), true);
    ref.invalidate(legacyNoticeDismissedProvider);
  },
);
