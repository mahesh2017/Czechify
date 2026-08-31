import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/profile/learner_profile_repository.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase database;
  final now = DateTime.utc(2026, 8, 30, 12);

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() => database.close());

  test(
    'legacy profile and reminder are backfilled into the sync outbox',
    () async {
      SharedPreferences.setMockInitialValues({
        'settings_onboarding_done': true,
        'settings_learner_name': 'Mahesh',
        'settings_starting_level': CEFRLevel.a1.index,
        'settings_tts_voice_gender': 1,
        'settings_tts_rate': 0.675,
        'settings_daily_goal_xp': 300,
        'settings_reminders_enabled': true,
        'settings_reminder_hour': 18,
        'settings_reminder_minute': 45,
        'settings_catch_up_enabled': false,
      });
      final repository = LearnerProfileRepository(database, clock: () => now);

      await repository.migrateLegacyPreferences();

      final profile = await repository.getProfile();
      expect(profile?.displayName, 'Mahesh');
      expect(profile?.selfAssessedCefr, 'a1');
      expect(profile?.preferredVoice, 'male');
      expect(profile?.ttsSpeechRate, 0.675);
      expect(profile?.onboardingCompletedAt, now.toLocal());
      final reminder = await repository.getReminderPreference();
      expect(reminder?.wantsReminder, isTrue);
      expect(reminder?.preferredHour, 18);
      expect(reminder?.preferredMinute, 45);
      final queued = await database.select(database.syncQueue).get();
      expect(
        queued.map((row) => row.entity),
        containsAll(<String>['learner_profiles', 'reminder_preferences']),
      );
    },
  );

  test(
    'structured onboarding answers are stored as an account profile',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LearnerProfileRepository(database, clock: () => now);

      await repository.saveOnboardingProfile(
        displayName: ' Anna ',
        selfAssessedLevel: 'b1OrHigher',
        primaryGoal: 'workAndCareer',
        focusSkills: const ['speaking', 'vocabularyAndGrammar'],
        dailyCommitmentMinutes: 15,
        studyDaysPerWeek: 5,
        preferredVoice: 'female',
        ttsSpeechRate: 0.6,
        dailyGoalXp: 300,
        onboardingVersion: 2,
        onboardingLastStep: 7,
        completed: true,
      );

      final profile = await repository.getProfile();
      expect(profile?.displayName, 'Anna');
      expect(profile?.selfAssessedCefr, 'b1OrHigher');
      expect(profile?.primaryGoal, 'workAndCareer');
      expect(profile?.focusSkillsJson, '["speaking","vocabularyAndGrammar"]');
      expect(profile?.ttsSpeechRate, 0.6);
      expect(profile?.onboardingVersion, 2);
      expect(profile?.onboardingCompletedAt, now.toLocal());
    },
  );

  test('completed onboarding milestones never regress locally', () async {
    SharedPreferences.setMockInitialValues({});
    var clock = now;
    final repository = LearnerProfileRepository(database, clock: () => clock);

    await repository.saveOnboardingProfile(
      displayName: 'Anna',
      selfAssessedLevel: 'a2',
      primaryGoal: 'everydayLife',
      dailyCommitmentMinutes: 15,
      studyDaysPerWeek: 5,
      preferredVoice: 'female',
      ttsSpeechRate: 0.45,
      dailyGoalXp: 300,
      onboardingVersion: 2,
      onboardingLastStep: 7,
      completed: true,
    );

    clock = now.add(const Duration(hours: 1));
    await repository.saveOnboardingProfile(
      displayName: 'Anna',
      selfAssessedLevel: 'a2',
      primaryGoal: 'everydayLife',
      dailyCommitmentMinutes: 15,
      studyDaysPerWeek: 5,
      preferredVoice: 'female',
      ttsSpeechRate: 0.45,
      dailyGoalXp: 300,
      onboardingVersion: 1,
      onboardingLastStep: 1,
      completed: false,
    );

    final profile = await repository.getProfile();
    expect(profile?.onboardingVersion, 2);
    expect(profile?.onboardingLastStep, 7);
    expect(profile?.onboardingCompletedAt, now.toLocal());
    expect(profile?.primaryGoal, 'everydayLife');
  });

  test('a newer profile schema wins independently of device clock', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LearnerProfileRepository(database, clock: () => now);

    await repository.saveOnboardingProfile(
      displayName: 'Legacy local',
      selfAssessedLevel: 'a1',
      primaryGoal: 'everydayLife',
      dailyCommitmentMinutes: 15,
      studyDaysPerWeek: 5,
      preferredVoice: 'female',
      ttsSpeechRate: 0.45,
      dailyGoalXp: 300,
      onboardingVersion: 1,
      onboardingLastStep: 1,
      completed: true,
    );

    await database.profileDao.mergeRemoteLearnerProfile(
      displayName: 'Cloud learner',
      selfAssessedCefr: 'a2',
      primaryGoal: 'workAndCareer',
      secondaryGoalsJson: '[]',
      examTrack: null,
      targetHorizon: 'withinSixMonths',
      focusSkillsJson: '["speaking"]',
      dailyCommitmentMinutes: 30,
      studyDaysPerWeek: 5,
      preferredVoice: 'male',
      ttsSpeechRate: 0.6,
      dailyGoalXp: 600,
      onboardingVersion: 2,
      onboardingLastStep: 7,
      onboardingCompletedAt: now.subtract(const Duration(days: 2)),
      // Deliberately older: schema dominance must beat wall-clock LWW.
      updatedAt: now.subtract(const Duration(days: 2)),
    );

    var profile = await repository.getProfile();
    expect(profile?.displayName, 'Cloud learner');
    expect(profile?.primaryGoal, 'workAndCareer');
    expect(profile?.focusSkillsJson, '["speaking"]');
    expect(profile?.onboardingVersion, 2);

    await database.profileDao.mergeRemoteLearnerProfile(
      displayName: 'Legacy overwrite',
      selfAssessedCefr: 'preA1',
      primaryGoal: null,
      secondaryGoalsJson: '[]',
      examTrack: null,
      targetHorizon: null,
      focusSkillsJson: '[]',
      dailyCommitmentMinutes: 5,
      studyDaysPerWeek: 7,
      preferredVoice: 'female',
      ttsSpeechRate: 0.45,
      dailyGoalXp: 120,
      onboardingVersion: 1,
      onboardingLastStep: 1,
      onboardingCompletedAt: now.add(const Duration(days: 2)),
      // Deliberately newer: a legacy schema still cannot erase v2 fields.
      updatedAt: now.add(const Duration(days: 2)),
    );

    profile = await repository.getProfile();
    expect(profile?.displayName, 'Cloud learner');
    expect(profile?.primaryGoal, 'workAndCareer');
    expect(profile?.focusSkillsJson, '["speaking"]');
    expect(profile?.onboardingVersion, 2);
    expect(
      profile?.onboardingCompletedAt,
      now.add(const Duration(days: 2)).toLocal(),
    );
  });
}
