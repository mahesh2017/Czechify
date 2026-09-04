import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/learner_profiles.dart';

part 'profile_dao.g.dart';

/// Transactional persistence and outbox writes for account-scoped profile
/// data. Remote merges never enqueue, preventing pull/push echo loops.
@DriftAccessor(tables: [LearnerProfiles, ReminderPreferences])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  Future<LearnerProfile?> learnerProfile() =>
      (select(learnerProfiles)
        ..where((row) => row.key.equals('primary'))).getSingleOrNull();

  Stream<LearnerProfile?> watchLearnerProfile() =>
      (select(learnerProfiles)
        ..where((row) => row.key.equals('primary'))).watchSingleOrNull();

  Future<ReminderPreference?> reminderPreference() =>
      (select(reminderPreferences)
        ..where((row) => row.key.equals('primary'))).getSingleOrNull();

  Stream<ReminderPreference?> watchReminderPreference() =>
      (select(reminderPreferences)
        ..where((row) => row.key.equals('primary'))).watchSingleOrNull();

  Future<void> saveLearnerProfile(LearnerProfilesCompanion companion) =>
      attachedDatabase.transaction(() async {
        await into(learnerProfiles).insertOnConflictUpdate(companion);
        final row = await learnerProfile();
        if (row == null) return;
        await attachedDatabase.syncDao.enqueue(
          entity: 'learner_profiles',
          entityKey: row.key,
          payload: learnerProfilePayload(row),
        );
      });

  Future<void> saveReminderPreference(ReminderPreferencesCompanion companion) =>
      attachedDatabase.transaction(() async {
        await into(reminderPreferences).insertOnConflictUpdate(companion);
        final row = await reminderPreference();
        if (row == null) return;
        await attachedDatabase.syncDao.enqueue(
          entity: 'reminder_preferences',
          entityKey: row.key,
          payload: reminderPreferencePayload(row),
        );
      });

  /// Last-write-wins for editable fields, with monotonic onboarding completion.
  Future<void> mergeRemoteLearnerProfile({
    required String displayName,
    required String selfAssessedCefr,
    String? primaryGoal,
    required String secondaryGoalsJson,
    String? examTrack,
    String? targetHorizon,
    required String focusSkillsJson,
    required int dailyCommitmentMinutes,
    required int studyDaysPerWeek,
    required String preferredVoice,
    required double ttsSpeechRate,
    required int dailyGoalXp,
    required int onboardingVersion,
    required int onboardingLastStep,
    DateTime? onboardingCompletedAt,
    required DateTime updatedAt,
  }) async {
    final existing = await learnerProfile();
    final completion = _later(
      existing?.onboardingCompletedAt,
      onboardingCompletedAt,
    );
    // A higher onboarding version describes a richer profile schema. Never
    // let a legacy device replace those structured fields merely because its
    // wall clock is later. Conversely, a higher-version remote profile must
    // be installed in full even when that device's clock is behind ours.
    if (existing != null && existing.onboardingVersion > onboardingVersion) {
      if (completion != existing.onboardingCompletedAt) {
        await (update(learnerProfiles)
          ..where((row) => row.key.equals(existing.key))).write(
          LearnerProfilesCompanion(onboardingCompletedAt: Value(completion)),
        );
      }
      return;
    }
    final remoteSchemaIsNewer =
        existing == null || onboardingVersion > existing.onboardingVersion;
    if (existing != null &&
        !remoteSchemaIsNewer &&
        existing.updatedAt.isAfter(updatedAt)) {
      if (completion != existing.onboardingCompletedAt ||
          onboardingVersion > existing.onboardingVersion) {
        await (update(learnerProfiles)
          ..where((row) => row.key.equals(existing.key))).write(
          LearnerProfilesCompanion(
            onboardingVersion: Value(
              onboardingVersion > existing.onboardingVersion
                  ? onboardingVersion
                  : existing.onboardingVersion,
            ),
            onboardingCompletedAt: Value(completion),
          ),
        );
      }
      return;
    }
    await into(learnerProfiles).insertOnConflictUpdate(
      LearnerProfilesCompanion.insert(
        key: const Value('primary'),
        displayName: Value(displayName),
        selfAssessedCefr: Value(selfAssessedCefr),
        primaryGoal: Value(primaryGoal),
        secondaryGoalsJson: Value(secondaryGoalsJson),
        examTrack: Value(examTrack),
        targetHorizon: Value(targetHorizon),
        focusSkillsJson: Value(focusSkillsJson),
        dailyCommitmentMinutes: Value(dailyCommitmentMinutes),
        studyDaysPerWeek: Value(studyDaysPerWeek),
        preferredVoice: Value(preferredVoice),
        ttsSpeechRate: Value(ttsSpeechRate),
        dailyGoalXp: Value(dailyGoalXp),
        onboardingVersion: Value(
          existing == null || onboardingVersion > existing.onboardingVersion
              ? onboardingVersion
              : existing.onboardingVersion,
        ),
        onboardingLastStep: Value(
          existing == null || onboardingLastStep > existing.onboardingLastStep
              ? onboardingLastStep
              : existing.onboardingLastStep,
        ),
        onboardingCompletedAt: Value(completion),
        updatedAt: updatedAt,
      ),
    );
  }

  Future<void> mergeRemoteReminderPreference({
    required bool wantsReminder,
    int? preferredHour,
    int? preferredMinute,
    required String daysOfWeekJson,
    required bool catchUpEnabled,
    required bool allowGoalSpecificText,
    required DateTime updatedAt,
  }) async {
    final existing = await reminderPreference();
    if (existing != null && existing.updatedAt.isAfter(updatedAt)) return;
    await into(reminderPreferences).insertOnConflictUpdate(
      ReminderPreferencesCompanion.insert(
        key: const Value('primary'),
        wantsReminder: Value(wantsReminder),
        preferredHour: Value(preferredHour),
        preferredMinute: Value(preferredMinute),
        daysOfWeekJson: Value(daysOfWeekJson),
        catchUpEnabled: Value(catchUpEnabled),
        allowGoalSpecificText: Value(allowGoalSpecificText),
        updatedAt: updatedAt,
      ),
    );
  }

  static Map<String, dynamic> learnerProfilePayload(LearnerProfile row) => {
    'key': row.key,
    'display_name': row.displayName,
    'self_assessed_cefr': row.selfAssessedCefr,
    'primary_goal': row.primaryGoal,
    'secondary_goals': _json(row.secondaryGoalsJson, const []),
    'exam_track': row.examTrack,
    'target_horizon': row.targetHorizon,
    'focus_skills': _json(row.focusSkillsJson, const []),
    'daily_commitment_minutes': row.dailyCommitmentMinutes,
    'study_days_per_week': row.studyDaysPerWeek,
    'preferred_voice': row.preferredVoice,
    'tts_speech_rate': row.ttsSpeechRate,
    'daily_goal_xp': row.dailyGoalXp,
    'onboarding_version': row.onboardingVersion,
    'onboarding_last_step': row.onboardingLastStep,
    'onboarding_completed_at':
        row.onboardingCompletedAt?.toUtc().toIso8601String(),
  };

  static Map<String, dynamic> reminderPreferencePayload(
    ReminderPreference row,
  ) => {
    'key': row.key,
    'wants_reminder': row.wantsReminder,
    'preferred_hour': row.preferredHour,
    'preferred_minute': row.preferredMinute,
    'days_of_week': _json(row.daysOfWeekJson, const [1, 2, 3, 4, 5, 6, 7]),
    'catch_up_enabled': row.catchUpEnabled,
    'allow_goal_specific_text': row.allowGoalSpecificText,
  };

  static Object _json(String source, Object fallback) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return fallback;
    }
  }

  static DateTime? _later(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
