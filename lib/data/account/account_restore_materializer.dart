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
    await _writePortableValues(preferences, profile, reminder);
    // A background sync may confirm onboarding, but must never un-confirm it:
    // the flag is only ever raised here, never cleared.
    if (profile?.onboardingCompletedAt != null) {
      await preferences.setBool('settings_onboarding_done', true);
    }
  }

  Future<AccountRestoreSummary> materialize() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in accountScopedPreferenceKeys) {
      await preferences.remove(key);
    }

    final profile = await _db.profileDao.learnerProfile();
    final reminder = await _db.profileDao.reminderPreference();
    await _writePortableValues(preferences, profile, reminder);
    await preferences.setBool('settings_reminders_enabled', false);

    final completed = profile?.onboardingCompletedAt != null;
    // Only a profile-less account can be legacy progress, so the four probe
    // queries stay unrun for everyone who has one.
    final legacyProgressOnly = profile == null && await _hasLocalProgress();
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

  /// Writes the preference values both restore paths share.
  ///
  /// `settings_onboarding_done` is deliberately not written here: a background
  /// sync may only raise it, while a full restore has to write it either way.
  Future<void> _writePortableValues(
    SharedPreferences preferences,
    LearnerProfile? profile,
    ReminderPreference? reminder,
  ) async {
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
  }

  /// Whether anything was ever learned on this device, for accounts that
  /// predate the learner profile.
  Future<bool> _hasLocalProgress() async =>
      (await (_db.select(_db.lessonProgress)..limit(1)).get()).isNotEmpty ||
      (await (_db.select(_db.earnedBadges)..limit(1)).get()).isNotEmpty ||
      (await (_db.select(_db.userProgress)..limit(1)).get()).isNotEmpty ||
      (await (_db.select(_db.gamificationStateTable)..limit(1)).get())
          .isNotEmpty;

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
