import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile/learner_profile_repository.dart';
import 'database_providers.dart';
import 'sync_providers.dart';

final learnerProfileRepositoryProvider = Provider<LearnerProfileRepository>(
  (ref) => LearnerProfileRepository(ref.watch(databaseProvider)),
);

/// Runs once per process. Existing installs gain a cloud profile without
/// blocking startup; fresh installs remain profile-less until onboarding.
final learnerProfileBootstrapProvider = FutureProvider<void>((ref) async {
  // Pull first so an older install cannot manufacture a legacy v1 row and
  // push it over a richer cloud v2 learning plan. Backend initialization is
  // background-only, so this ordering never delays the first usable frame.
  await ref.watch(backendInitProvider.future);
  await ref.read(syncServiceProvider).sync();
  await ref.watch(learnerProfileRepositoryProvider).migrateLegacyPreferences();
  // Upload a genuine legacy backfill promptly; no-op while offline.
  await ref.read(syncServiceProvider).push();
});

final learnerProfileProvider = StreamProvider(
  (ref) => ref.watch(learnerProfileRepositoryProvider).watchProfile(),
);

final reminderPreferenceProvider = StreamProvider(
  (ref) =>
      ref.watch(learnerProfileRepositoryProvider).watchReminderPreference(),
);
