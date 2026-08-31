import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/enums.dart';
import '../database/database.dart';

/// What was recovered after an existing account replaced local learner data.
/// Notification authorization is intentionally absent: it belongs to this
/// device and must be requested locally after the restore.
class AccountRestoreSummary {
  const AccountRestoreSummary({
    required this.onboardingComplete,
    required this.legacyProgressOnly,
    this.learnerName,
    this.savedReminderHour,
    this.savedReminderMinute,
    this.wantsReminder = false,
  });

  final bool onboardingComplete;
  final bool legacyProgressOnly;
  final String? learnerName;
  final int? savedReminderHour;
  final int? savedReminderMinute;
  final bool wantsReminder;

  bool get hasSavedReminder =>
      wantsReminder && savedReminderHour != null && savedReminderMinute != null;
}

/// Bridges restored account records into the existing Settings layer.
///
/// Portable preference values are restored; notification permission and the
/// actual enabled schedule are always reset for the current device.
class AccountRestoreMaterializer {
  const AccountRestoreMaterializer(this._db);

  final AppDatabase _db;

  /// Applies portable changes received during an ordinary background sync.
  /// Unlike a full account replacement, this preserves device authorization
  /// and the actual reminder enabled state.
  Future<void> hydratePortablePreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final profile = await _db.profileDao.learnerProfile();
    final reminder = await _db.profileDao.reminderPreference();
    if (profile != null) {
      await preferences.setString('settings_learner_name', profile.displayName);
      await preferences.setInt(
        'settings_starting_level',
        _curriculumLevel(profile.selfAssessedCefr).index,
      );
      await preferences.setInt(
        'settings_tts_voice_gender',
        profile.preferredVoice == 'male' ? 1 : 0,
      );
      await preferences.setDouble('settings_tts_rate', profile.ttsSpeechRate);
      await preferences.setInt('settings_daily_goal_xp', profile.dailyGoalXp);
      if (profile.onboardingCompletedAt != null) {
        await preferences.setBool('settings_onboarding_done', true);
      }
    }
    if (reminder != null) {
      final hour = reminder.preferredHour;
      final minute = reminder.preferredMinute;
      if (hour != null && minute != null) {
        await preferences.setInt('settings_reminder_hour', hour);
        await preferences.setInt('settings_reminder_minute', minute);
      }
      await preferences.setBool(
        'settings_catch_up_enabled',
        reminder.catchUpEnabled,
      );
    }
  }

  Future<AccountRestoreSummary> materialize() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in accountScopedPreferenceKeys) {
      await preferences.remove(key);
    }

    final profile = await _db.profileDao.learnerProfile();
    final reminder = await _db.profileDao.reminderPreference();
    final hasProgress =
        (await (_db.select(_db.lessonProgress)..limit(1)).get()).isNotEmpty ||
        (await (_db.select(_db.earnedBadges)..limit(1)).get()).isNotEmpty ||
        (await (_db.select(_db.userProgress)..limit(1)).get()).isNotEmpty ||
        (await (_db.select(
          _db.gamificationStateTable,
        )..limit(1)).get()).isNotEmpty;

    if (profile != null) {
      await preferences.setString('settings_learner_name', profile.displayName);
      await preferences.setInt(
        'settings_starting_level',
        _curriculumLevel(profile.selfAssessedCefr).index,
      );
      await preferences.setInt(
        'settings_tts_voice_gender',
        profile.preferredVoice == 'male' ? 1 : 0,
      );
      await preferences.setDouble('settings_tts_rate', profile.ttsSpeechRate);
      await preferences.setInt('settings_daily_goal_xp', profile.dailyGoalXp);
    }

    if (reminder != null) {
      final hour = reminder.preferredHour;
      final minute = reminder.preferredMinute;
      if (hour != null && minute != null) {
        await preferences.setInt('settings_reminder_hour', hour);
        await preferences.setInt('settings_reminder_minute', minute);
      }
      await preferences.setBool(
        'settings_catch_up_enabled',
        reminder.catchUpEnabled,
      );
    }
    await preferences.setBool('settings_reminders_enabled', false);

    final completed = profile?.onboardingCompletedAt != null;
    final legacyProgressOnly = profile == null && hasProgress;
    final onboardingComplete = completed || legacyProgressOnly;
    await preferences.setBool('settings_onboarding_done', onboardingComplete);

    return AccountRestoreSummary(
      onboardingComplete: onboardingComplete,
      legacyProgressOnly: legacyProgressOnly,
      learnerName: profile?.displayName,
      savedReminderHour: reminder?.preferredHour,
      savedReminderMinute: reminder?.preferredMinute,
      wantsReminder: reminder?.wantsReminder ?? false,
    );
  }

  static const accountScopedPreferenceKeys = <String>{
    'settings_learner_name',
    'settings_starting_level',
    'settings_onboarding_done',
    'settings_tts_rate',
    'settings_tts_voice_gender',
    'settings_daily_goal_xp',
    'settings_reminder_hour',
    'settings_reminder_minute',
    'settings_reminders_enabled',
    'settings_catch_up_enabled',
    'srs_new_cards_today',
    'srs_new_cards_date',
    'exam_checkpoint_a1',
    'exam_checkpoint_a2',
  };

  static CEFRLevel _curriculumLevel(String selfAssessment) =>
      switch (selfAssessment) {
        'a1' => CEFRLevel.a1,
        'a2' || 'b1OrHigher' => CEFRLevel.a2,
        _ => CEFRLevel.preA1,
      };
}
