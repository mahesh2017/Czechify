import 'package:czechify/data/account/account_restore_materializer.dart';
import 'package:czechify/data/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() => database.close());

  test(
    'restores account profile but keeps reminder authorization local',
    () async {
      final updatedAt = DateTime.utc(2026, 8, 30, 10);
      await database.profileDao.mergeRemoteLearnerProfile(
        displayName: 'Mahesh',
        selfAssessedCefr: 'b1OrHigher',
        primaryGoal: 'permanentResidenceA2',
        secondaryGoalsJson: '[]',
        examTrack: 'permanentResidenceA2',
        targetHorizon: 'threeToSixMonths',
        focusSkillsJson: '["listening","writing"]',
        dailyCommitmentMinutes: 30,
        studyDaysPerWeek: 6,
        preferredVoice: 'male',
        ttsSpeechRate: 0.6,
        dailyGoalXp: 600,
        onboardingVersion: 2,
        onboardingLastStep: 7,
        onboardingCompletedAt: updatedAt,
        updatedAt: updatedAt,
      );
      await database.profileDao.mergeRemoteReminderPreference(
        wantsReminder: true,
        preferredHour: 19,
        preferredMinute: 15,
        daysOfWeekJson: '[1,2,3,4,5]',
        catchUpEnabled: false,
        allowGoalSpecificText: false,
        updatedAt: updatedAt,
      );
      final before = await SharedPreferences.getInstance();
      await before.setString('settings_learner_name', 'Previous account');
      await before.setBool('settings_reminders_enabled', true);

      final summary = await AccountRestoreMaterializer(database).materialize();

      expect(summary.onboardingComplete, isTrue);
      expect(summary.legacyProgressOnly, isFalse);
      expect(summary.learnerName, 'Mahesh');
      expect(summary.hasSavedReminder, isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('settings_learner_name'), 'Mahesh');
      expect(preferences.getInt('settings_starting_level'), 2);
      expect(preferences.getInt('settings_tts_voice_gender'), 1);
      expect(preferences.getDouble('settings_tts_rate'), 0.6);
      expect(preferences.getInt('settings_daily_goal_xp'), 600);
      expect(preferences.getInt('settings_reminder_hour'), 19);
      expect(preferences.getInt('settings_reminder_minute'), 15);
      expect(preferences.getBool('settings_catch_up_enabled'), isFalse);
      expect(preferences.getBool('settings_reminders_enabled'), isFalse);
      expect(preferences.getBool('settings_onboarding_done'), isTrue);
    },
  );

  test('legacy synced progress bypasses repeated onboarding', () async {
    await database.customStatement(
      "INSERT INTO user_progress (key,value) VALUES ('streak','4')",
    );

    final summary = await AccountRestoreMaterializer(database).materialize();

    expect(summary.onboardingComplete, isTrue);
    expect(summary.legacyProgressOnly, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('settings_onboarding_done'), isTrue);
  });

  test(
    'ordinary sync hydration preserves this device reminder state',
    () async {
      final updatedAt = DateTime.utc(2026, 8, 30, 11);
      await database.profileDao.mergeRemoteReminderPreference(
        wantsReminder: false,
        preferredHour: 20,
        preferredMinute: 30,
        daysOfWeekJson: '[1,2,3,4,5,6,7]',
        catchUpEnabled: false,
        allowGoalSpecificText: false,
        updatedAt: updatedAt,
      );
      final before = await SharedPreferences.getInstance();
      await before.setBool('settings_reminders_enabled', true);

      await AccountRestoreMaterializer(database).hydratePortablePreferences();

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('settings_reminder_hour'), 20);
      expect(preferences.getInt('settings_reminder_minute'), 30);
      expect(preferences.getBool('settings_catch_up_enabled'), isFalse);
      expect(preferences.getBool('settings_reminders_enabled'), isTrue);
    },
  );

  test(
    'an empty incomplete account resumes onboarding and clears stale data',
    () async {
      SharedPreferences.setMockInitialValues({
        'settings_learner_name': 'Wrong account',
        'settings_onboarding_done': true,
        'settings_reminders_enabled': true,
      });

      final summary = await AccountRestoreMaterializer(database).materialize();

      expect(summary.onboardingComplete, isFalse);
      expect(summary.legacyProgressOnly, isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('settings_learner_name'), isNull);
      expect(preferences.getBool('settings_onboarding_done'), isFalse);
      expect(preferences.getBool('settings_reminders_enabled'), isFalse);
    },
  );
}
