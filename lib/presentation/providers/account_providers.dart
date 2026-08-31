import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/account/account_service.dart';
import 'chat_providers.dart';
import 'curriculum_providers.dart';
import 'database_providers.dart';
import 'gamification_providers.dart';
import 'lesson_providers.dart';
import 'pronunciation_providers.dart';
import 'reminder_coordinator.dart';
import 'review_providers.dart';
import 'settings_providers.dart';
import 'sync_providers.dart';
import 'writing_providers.dart';

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(
    ref.watch(backendServiceProvider),
    ref.watch(databaseProvider),
    ref.watch(syncServiceProvider),
    onAccountChanged: () => ref.invalidate(accountUserProvider),
    onDeviceRemindersReset:
        () =>
            ref
                .read(reminderCoordinatorProvider.notifier)
                .resetDeviceReminders(),
    onLocalDataChanged: () {
      ref.invalidate(gamificationProvider);
      ref.invalidate(lessonSessionProvider);
      ref.invalidate(reviewSessionProvider);
      ref.invalidate(dueCardCountProvider);
      ref.invalidate(completedLessonIdsProvider);
      ref.invalidate(curriculumEntitlementProvider);
      ref.invalidate(curriculumAccessProvider);
      ref.invalidate(chatProvider);
      ref.invalidate(pronunciationProvider);
      ref.invalidate(writingEvalProvider);
      ref.invalidate(settingsProvider);
    },
  );
});

final accountUserProvider = StreamProvider<User?>((ref) async* {
  await ref.watch(backendInitProvider.future);
  final backend = ref.watch(backendServiceProvider);
  yield backend.currentUser;
  if (backend.client != null) {
    yield* backend.authChanges.map((state) => state.session?.user);
  }
});
