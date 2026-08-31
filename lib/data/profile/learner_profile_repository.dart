import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/enums.dart';
import '../database/database.dart';

/// Owns the account-scoped profile and its one-time migration from the legacy
/// SharedPreferences-only implementation.
class LearnerProfileRepository {
  LearnerProfileRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Stream<LearnerProfile?> watchProfile() =>
      _db.profileDao.watchLearnerProfile();

  Future<LearnerProfile?> getProfile() => _db.profileDao.learnerProfile();

  Stream<ReminderPreference?> watchReminderPreference() =>
      _db.profileDao.watchReminderPreference();

  Future<ReminderPreference?> getReminderPreference() =>
      _db.profileDao.reminderPreference();

  /// Existing installs upload the profile information they already have once.
  /// A fresh install has none of these values and therefore creates no row.
  Future<void> migrateLegacyPreferences() async {
    if (await getProfile() != null) return;
    final prefs = await SharedPreferences.getInstance();
    final hasLegacyProfile =
        (prefs.getBool('settings_onboarding_done') ?? false) ||
        prefs.containsKey('settings_learner_name') ||
        prefs.containsKey('settings_starting_level');
    if (!hasLegacyProfile) return;

    final levelIndex = prefs.getInt('settings_starting_level') ?? 0;
    final level =
        CEFRLevel.values[levelIndex.clamp(0, CEFRLevel.values.length - 1)];
    final completed = prefs.getBool('settings_onboarding_done') ?? false;
    final now = _clock();
    await _db.profileDao.saveLearnerProfile(
      LearnerProfilesCompanion.insert(
        key: const Value('primary'),
        displayName: Value(prefs.getString('settings_learner_name') ?? ''),
        selfAssessedCefr: Value(level.name),
        preferredVoice: Value(
          (prefs.getInt('settings_tts_voice_gender') ?? 0) == 1
              ? 'male'
              : 'female',
        ),
        ttsSpeechRate: Value(prefs.getDouble('settings_tts_rate') ?? 0.45),
        dailyGoalXp: Value(prefs.getInt('settings_daily_goal_xp') ?? 300),
        dailyCommitmentMinutes: Value(
          _minutesForXp(prefs.getInt('settings_daily_goal_xp') ?? 300),
        ),
        onboardingVersion: const Value(1),
        onboardingLastStep: Value(completed ? 1 : 0),
        onboardingCompletedAt: Value(completed ? now : null),
        updatedAt: now,
      ),
    );

    if (prefs.containsKey('settings_reminder_hour') ||
        prefs.containsKey('settings_reminders_enabled')) {
      await _db.profileDao.saveReminderPreference(
        ReminderPreferencesCompanion.insert(
          key: const Value('primary'),
          wantsReminder: Value(
            prefs.getBool('settings_reminders_enabled') ?? false,
          ),
          preferredHour: Value(prefs.getInt('settings_reminder_hour')),
          preferredMinute: Value(prefs.getInt('settings_reminder_minute')),
          catchUpEnabled: Value(
            prefs.getBool('settings_catch_up_enabled') ?? true,
          ),
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> saveOnboardingProfile({
    required String displayName,
    required String selfAssessedLevel,
    required String primaryGoal,
    List<String> secondaryGoals = const [],
    String? examTrack,
    String? targetHorizon,
    List<String> focusSkills = const [],
    required int dailyCommitmentMinutes,
    required int studyDaysPerWeek,
    required String preferredVoice,
    required double ttsSpeechRate,
    required int dailyGoalXp,
    required int onboardingVersion,
    required int onboardingLastStep,
    required bool completed,
  }) async {
    final now = _clock();
    final existing = await getProfile();
    // Onboarding versions are profile-schema versions, not merely progress
    // counters. A legacy writer must not blank the richer answers captured by
    // a newer flow while retaining only its version/completion markers.
    if (existing != null && existing.onboardingVersion > onboardingVersion) {
      return;
    }
    await _db.profileDao.saveLearnerProfile(
      LearnerProfilesCompanion.insert(
        key: const Value('primary'),
        displayName: Value(displayName.trim()),
        selfAssessedCefr: Value(selfAssessedLevel),
        primaryGoal: Value(primaryGoal),
        secondaryGoalsJson: Value(jsonEncode(secondaryGoals)),
        examTrack: Value(examTrack),
        targetHorizon: Value(targetHorizon),
        focusSkillsJson: Value(jsonEncode(focusSkills)),
        dailyCommitmentMinutes: Value(dailyCommitmentMinutes),
        studyDaysPerWeek: Value(studyDaysPerWeek),
        preferredVoice: Value(preferredVoice),
        ttsSpeechRate: Value(ttsSpeechRate),
        dailyGoalXp: Value(dailyGoalXp),
        onboardingVersion: Value(
          existing != null && existing.onboardingVersion > onboardingVersion
              ? existing.onboardingVersion
              : onboardingVersion,
        ),
        onboardingLastStep: Value(
          existing != null && existing.onboardingLastStep > onboardingLastStep
              ? existing.onboardingLastStep
              : onboardingLastStep,
        ),
        onboardingCompletedAt: Value(
          completed
              ? (existing?.onboardingCompletedAt ?? now)
              : existing?.onboardingCompletedAt,
        ),
        updatedAt: now,
      ),
    );
  }

  Future<void> updateDisplayName(String displayName) =>
      _updateProfile(displayName: displayName.trim());

  Future<void> updateSelfAssessedLevel(CEFRLevel level) =>
      _updateProfile(selfAssessedCefr: level.name);

  Future<void> updatePreferredVoice(String voice) =>
      _updateProfile(preferredVoice: voice);

  Future<void> updateTtsSpeechRate(double rate) =>
      _updateProfile(ttsSpeechRate: rate);

  Future<void> updateDailyGoal(int xp) => _updateProfile(
    dailyGoalXp: xp,
    dailyCommitmentMinutes: _minutesForXp(xp),
  );

  Future<void> updateReminderIntent({
    bool? wantsReminder,
    int? preferredHour,
    int? preferredMinute,
    bool? catchUpEnabled,
    List<int>? daysOfWeek,
    bool? allowGoalSpecificText,
  }) async {
    final existing = await getReminderPreference();
    await _db.profileDao.saveReminderPreference(
      ReminderPreferencesCompanion.insert(
        key: const Value('primary'),
        wantsReminder: Value(wantsReminder ?? existing?.wantsReminder ?? false),
        preferredHour: Value(preferredHour ?? existing?.preferredHour),
        preferredMinute: Value(preferredMinute ?? existing?.preferredMinute),
        daysOfWeekJson: Value(
          jsonEncode(
            daysOfWeek ??
                _decodeIntList(existing?.daysOfWeekJson) ??
                const [1, 2, 3, 4, 5, 6, 7],
          ),
        ),
        catchUpEnabled: Value(
          catchUpEnabled ?? existing?.catchUpEnabled ?? true,
        ),
        allowGoalSpecificText: Value(
          allowGoalSpecificText ?? existing?.allowGoalSpecificText ?? false,
        ),
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> _updateProfile({
    String? displayName,
    String? selfAssessedCefr,
    String? preferredVoice,
    double? ttsSpeechRate,
    int? dailyGoalXp,
    int? dailyCommitmentMinutes,
  }) async {
    final existing = await getProfile();
    if (existing == null) {
      await migrateLegacyPreferences();
      final migrated = await getProfile();
      if (migrated == null) return;
      return _updateProfile(
        displayName: displayName,
        selfAssessedCefr: selfAssessedCefr,
        preferredVoice: preferredVoice,
        ttsSpeechRate: ttsSpeechRate,
        dailyGoalXp: dailyGoalXp,
        dailyCommitmentMinutes: dailyCommitmentMinutes,
      );
    }
    await _db.profileDao.saveLearnerProfile(
      LearnerProfilesCompanion.insert(
        key: Value(existing.key),
        displayName: Value(displayName ?? existing.displayName),
        selfAssessedCefr: Value(selfAssessedCefr ?? existing.selfAssessedCefr),
        primaryGoal: Value(existing.primaryGoal),
        secondaryGoalsJson: Value(existing.secondaryGoalsJson),
        examTrack: Value(existing.examTrack),
        targetHorizon: Value(existing.targetHorizon),
        focusSkillsJson: Value(existing.focusSkillsJson),
        dailyCommitmentMinutes: Value(
          dailyCommitmentMinutes ?? existing.dailyCommitmentMinutes,
        ),
        studyDaysPerWeek: Value(existing.studyDaysPerWeek),
        preferredVoice: Value(preferredVoice ?? existing.preferredVoice),
        ttsSpeechRate: Value(ttsSpeechRate ?? existing.ttsSpeechRate),
        dailyGoalXp: Value(dailyGoalXp ?? existing.dailyGoalXp),
        onboardingVersion: Value(existing.onboardingVersion),
        onboardingLastStep: Value(existing.onboardingLastStep),
        onboardingCompletedAt: Value(existing.onboardingCompletedAt),
        updatedAt: _clock(),
      ),
    );
  }

  static int _minutesForXp(int xp) => switch (xp) {
    <= 120 => 5,
    <= 300 => 15,
    <= 600 => 30,
    _ => 45,
  };

  static List<int>? _decodeIntList(String? source) {
    if (source == null) return null;
    try {
      return (jsonDecode(source) as List)
          .whereType<num>()
          .map((value) => value.toInt())
          .toList();
    } catch (_) {
      return null;
    }
  }
}
