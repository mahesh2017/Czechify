import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/lesson_progress.dart';
import '../tables/earned_badges.dart';
import '../tables/user_progress.dart';
import '../tables/lesson_attempts.dart';
import '../tables/reward_ledger.dart';
import '../tables/gamification_state.dart';
import '../tables/exercise_attempts.dart';
import '../tables/learning_evidence_events.dart';
import '../tables/placement_profiles.dart';
import '../tables/delayed_transfer_assignments.dart';
import '../../../domain/entities/exercise_attempt_evidence.dart';
import '../../../domain/entities/exercise_outcome.dart';
import '../../../domain/entities/learning_evidence.dart';
import '../../../domain/engines/placement_engine.dart';

part 'progress_dao.g.dart';

/// Data access object for progress, badges, and lesson completion.
@DriftAccessor(
  tables: [
    LessonProgress,
    EarnedBadges,
    UserProgress,
    LessonAttempts,
    RewardLedger,
    GamificationStateTable,
    ExerciseAttempts,
    LearningEvidenceEvents,
    PlacementProfiles,
    DelayedTransferAssignments,
  ],
)
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  Future<bool> recordLearningEvidence(LearningEvidence evidence) =>
      attachedDatabase.transaction(() async {
        final duplicate =
            await (select(learningEvidenceEvents)..where(
              (row) => row.evidenceId.equals(evidence.evidenceId),
            )).getSingleOrNull();
        if (duplicate != null) return false;
        await into(learningEvidenceEvents).insert(
          LearningEvidenceEventsCompanion.insert(
            evidenceId: evidence.evidenceId,
            lessonId: evidence.lessonId,
            exerciseId: Value(evidence.exerciseId),
            skill: evidence.skill.name,
            phase: evidence.phase.name,
            correct: evidence.correct,
            novelTask: evidence.novelTask,
            supportsJson: Value(
              jsonEncode(evidence.supports.map((value) => value.name).toList()),
            ),
            conceptKeysJson: Value(jsonEncode(evidence.conceptKeys.toList())),
            responseLatencyMs: evidence.responseLatency.inMilliseconds,
            observedAt: evidence.observedAt,
          ),
        );
        return true;
      });

  Future<List<LearningEvidence>> getLearningEvidence() async {
    final rows =
        await (select(learningEvidenceEvents)
          ..orderBy([(row) => OrderingTerm.asc(row.observedAt)])).get();
    return rows
        .map(
          (row) => LearningEvidence(
            evidenceId: row.evidenceId,
            lessonId: row.lessonId,
            exerciseId: row.exerciseId,
            skill:
                LearningSkill.values.asNameMap()[row.skill] ??
                LearningSkill.grammar,
            phase:
                LearningPhase.values.asNameMap()[row.phase] ??
                LearningPhase.retrieve,
            correct: row.correct,
            novelTask: row.novelTask,
            supports:
                (jsonDecode(row.supportsJson) as List)
                    .whereType<String>()
                    .map((name) => SupportKind.values.asNameMap()[name])
                    .whereType<SupportKind>()
                    .toSet(),
            conceptKeys:
                (jsonDecode(row.conceptKeysJson) as List)
                    .whereType<String>()
                    .toSet(),
            responseLatency: Duration(milliseconds: row.responseLatencyMs),
            observedAt: row.observedAt,
          ),
        )
        .toList();
  }

  Future<void> savePlacement(
    PlacementResult result, {
    int? learnerOverrideUnit,
  }) => into(placementProfiles).insertOnConflictUpdate(
    PlacementProfilesCompanion.insert(
      key: const Value('primary'),
      provisionalUnit: result.provisionalUnit,
      learnerOverrideUnit: Value(learnerOverrideUnit),
      estimatesJson: jsonEncode({
        for (final entry in result.estimates.entries)
          entry.key.name: entry.value,
      }),
      sampleSize: result.sampleSize,
      updatedAt: DateTime.now(),
    ),
  );

  /// Move the unlock ceiling without touching anything else in the profile.
  ///
  /// A learner changing level in Settings is not retaking the placement test,
  /// so their skill estimates and sample size have to survive. Going through
  /// [savePlacement] would overwrite both with whatever the caller invented,
  /// quietly discarding a real placement result.
  ///
  /// Inserts a profile when none exists yet, which is the case for anyone who
  /// onboarded as a beginner.
  Future<void> setProvisionalUnit(int unitId) async {
    final existing = await select(placementProfiles).getSingleOrNull();
    if (existing == null) {
      await into(placementProfiles).insert(
        PlacementProfilesCompanion.insert(
          key: const Value('primary'),
          provisionalUnit: unitId,
          estimatesJson: jsonEncode(const <String, double>{}),
          sampleSize: 0,
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }
    await (update(placementProfiles)
      ..where((row) => row.key.equals(existing.key))).write(
      PlacementProfilesCompanion(
        provisionalUnit: Value(unitId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<DelayedTransferAssignment>> getDueTransfers(DateTime asOf) {
    return (select(delayedTransferAssignments)
          ..where(
            (row) =>
                row.status.equals('pending') &
                row.dueAt.isSmallerOrEqualValue(asOf),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.dueAt)]))
        .get();
  }

  Future<bool> completeTransfer({
    required String assignmentId,
    required LearningEvidence evidence,
  }) => attachedDatabase.transaction(() async {
    final assignment =
        await (select(delayedTransferAssignments)..where(
          (row) => row.assignmentId.equals(assignmentId),
        )).getSingleOrNull();
    if (assignment == null || assignment.status != 'pending') return false;
    if (!evidence.isDelayedTransfer ||
        evidence.lessonId != assignment.lessonId ||
        evidence.exerciseId == assignment.sourceExerciseId ||
        evidence.observedAt.isBefore(assignment.dueAt)) {
      throw ArgumentError(
        'Transfer evidence must be due and use a novel task for the source lesson',
      );
    }
    final inserted = await recordLearningEvidence(evidence);
    if (!inserted) return false;
    await _reestimatePlacementFrom(evidence);
    await (update(delayedTransferAssignments)
      ..where((row) => row.assignmentId.equals(assignmentId))).write(
      DelayedTransferAssignmentsCompanion(
        status: const Value('completed'),
        completedEvidenceId: Value(evidence.evidenceId),
        completedAt: Value(evidence.observedAt),
      ),
    );
    return true;
  });

  Future<void> _reestimatePlacementFrom(LearningEvidence evidence) async {
    final profile =
        await (select(placementProfiles)
          ..where((row) => row.key.equals('primary'))).getSingleOrNull();
    if (profile == null) return;

    final decoded = jsonDecode(profile.estimatesJson);
    if (decoded is! Map<String, dynamic>) return;
    final estimates = <String, double>{
      for (final entry in decoded.entries)
        if (entry.value is num) entry.key: (entry.value as num).toDouble(),
    };
    final key = evidence.skill.name;
    final current = estimates[key];
    if (current == null) return;
    final adjustment =
        evidence.correct && evidence.independent
            ? 0.05
            : evidence.correct
            ? -0.03
            : -0.12;
    estimates[key] = (current + adjustment).clamp(0.0, 1.0);
    final required =
        PlacementEngine.requiredSkills
            .map((skill) => estimates[skill.name])
            .whereType<double>()
            .toList();
    if (required.isEmpty) return;
    final conservative = required.reduce((a, b) => a < b ? a : b);
    final inferredUnit = switch (conservative) {
      < 0.35 => 1,
      < 0.5 => 6,
      < 0.65 => 12,
      < 0.78 => 18,
      _ => 24,
    };
    await (update(placementProfiles)
      ..where((row) => row.key.equals('primary'))).write(
      PlacementProfilesCompanion(
        provisionalUnit: Value(profile.learnerOverrideUnit ?? inferredUnit),
        estimatesJson: Value(jsonEncode(estimates)),
        updatedAt: Value(evidence.observedAt),
      ),
    );
  }

  // ── Lesson Progress ──

  /// Atomically records immutable attempt evidence and updates the aggregate.
  ///
  /// Returns false when [attemptId] was already committed. This makes delayed
  /// callbacks and explicit persistence retries safe.
  Future<bool> recordLessonCompletion({
    required String attemptId,
    required int lessonId,
    required int unitId,
    required double score,
    required int correctCount,
    required int incorrectCount,
    required int skippedCount,
    required DateTime startedAt,
    required int activityXp,
    required List<ExerciseAttemptEvidence> exerciseEvidence,
    String phase = 'initial',
  }) => attachedDatabase.transaction(() async {
    final duplicate =
        await (select(lessonAttempts)
          ..where((row) => row.attemptId.equals(attemptId))).getSingleOrNull();
    if (duplicate != null) return false;

    final now = DateTime.now();
    await into(lessonAttempts).insert(
      LessonAttemptsCompanion.insert(
        attemptId: attemptId,
        lessonId: lessonId,
        unitId: unitId,
        phase: phase,
        score: score,
        correctCount: correctCount,
        incorrectCount: incorrectCount,
        skippedCount: skippedCount,
        startedAt: startedAt,
        committedAt: now,
      ),
    );

    if (exerciseEvidence.isNotEmpty) {
      await batch((batch) {
        batch.insertAll(
          exerciseAttempts,
          exerciseEvidence
              .map(
                (evidence) => ExerciseAttemptsCompanion.insert(
                  presentationId: evidence.presentationId,
                  lessonAttemptId: attemptId,
                  exerciseId: evidence.exerciseId,
                  phase: evidence.phase.storageValue,
                  outcome: evidence.outcome.name,
                  answeredAt: evidence.answeredAt,
                ),
              )
              .toList(),
        );
      });
      final transferDue = now.add(const Duration(days: 7));
      final transferSources = exerciseEvidence.where(
        (evidence) =>
            evidence.phase == ExerciseEvidencePhase.initial &&
            evidence.outcome == ExerciseOutcome.incorrect,
      );
      for (final evidence in transferSources) {
        await into(delayedTransferAssignments).insert(
          DelayedTransferAssignmentsCompanion.insert(
            assignmentId: 'transfer:$attemptId:${evidence.exerciseId}',
            sourceAttemptId: attemptId,
            lessonId: lessonId,
            sourceExerciseId: evidence.exerciseId,
            dueAt: transferDue,
            createdAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    }

    await into(rewardLedger).insert(
      RewardLedgerCompanion.insert(
        rewardId: 'lesson:$attemptId',
        sourceId: attemptId,
        rewardType: 'lesson_completion',
        xp: activityXp,
        awardedAt: now,
      ),
    );

    final gamification =
        await (select(gamificationStateTable)
          ..where((row) => row.key.equals('primary'))).getSingleOrNull();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    final priorDailyXp =
        gamification?.dailyXpResetDate == today
            ? gamification?.dailyXp ?? 0
            : 0;
    final totalXp = (gamification?.totalXp ?? 0) + activityXp;
    final dailyXp = priorDailyXp + activityXp;
    final earnedBadges = gamification?.earnedBadges ?? '[]';

    await into(gamificationStateTable).insertOnConflictUpdate(
      GamificationStateTableCompanion.insert(
        key: 'primary',
        hearts: Value(gamification?.hearts ?? 5),
        maxHearts: Value(gamification?.maxHearts ?? 5),
        currentStreak: Value(gamification?.currentStreak ?? 0),
        longestStreak: Value(gamification?.longestStreak ?? 0),
        totalXp: Value(totalXp),
        dailyXp: Value(dailyXp),
        dailyGoalXp: Value(gamification?.dailyGoalXp ?? 50),
        gems: Value(gamification?.gems ?? 0),
        earnedBadges: Value(earnedBadges),
        lastHeartRefill: Value(gamification?.lastHeartRefill),
        streakFreezeAvailable: Value(
          gamification?.streakFreezeAvailable ?? true,
        ),
        lastOpenDate: Value(gamification?.lastOpenDate),
        dailyXpResetDate: Value(today),
        updatedAt: Value(now),
      ),
    );

    final existing =
        await (select(lessonProgress)
          ..where((l) => l.lessonId.equals(lessonId))).getSingleOrNull();

    final bestScore =
        existing == null
            ? score
            : (score > existing.bestScore ? score : existing.bestScore);
    final attempts = existing == null ? 1 : existing.attempts + 1;

    if (existing == null) {
      await into(lessonProgress).insert(
        LessonProgressCompanion.insert(
          lessonId: Value(lessonId),
          unitId: unitId,
          isCompleted: const Value(true),
          bestScore: Value(bestScore),
          attempts: Value(attempts),
          lastAttempted: Value(now),
        ),
      );
    } else {
      await (update(lessonProgress)
        ..where((l) => l.lessonId.equals(lessonId))).write(
        LessonProgressCompanion(
          isCompleted: const Value(true),
          bestScore: Value(bestScore),
          attempts: Value(attempts),
          lastAttempted: Value(now),
        ),
      );
    }

    await attachedDatabase.syncDao.enqueue(
      entity: 'lesson_progress',
      entityKey: lessonId.toString(),
      payload: {
        'lesson_id': lessonId,
        'unit_id': unitId,
        'is_completed': true,
        'best_score': bestScore,
        'attempts': attempts,
        'last_attempted': now.toUtc().toIso8601String(),
      },
    );
    await attachedDatabase.syncDao.enqueue(
      entity: 'gamification_state',
      entityKey: 'primary',
      payload: {
        'key': 'primary',
        'hearts': gamification?.hearts ?? 5,
        'max_hearts': gamification?.maxHearts ?? 5,
        'current_streak': gamification?.currentStreak ?? 0,
        'longest_streak': gamification?.longestStreak ?? 0,
        'total_xp': totalXp,
        'daily_xp': dailyXp,
        'daily_goal_xp': gamification?.dailyGoalXp ?? 50,
        'gems': gamification?.gems ?? 0,
        'earned_badges': jsonDecode(earnedBadges),
        'last_heart_refill':
            gamification?.lastHeartRefill?.toUtc().toIso8601String(),
        'streak_freeze_available': gamification?.streakFreezeAvailable ?? true,
        'last_open_date': gamification?.lastOpenDate,
        'daily_xp_reset_date': today,
      },
    );
    return true;
  });

  Future<List<LessonProgressData>> getCompletedLessons() {
    return (select(lessonProgress)
      ..where((l) => l.isCompleted.equals(true))).get();
  }

  Future<List<LessonProgressData>> getLessonsByUnit(int unitId) {
    return (select(lessonProgress)
      ..where((l) => l.unitId.equals(unitId))).get();
  }

  Stream<List<LessonProgressData>> watchCompletedLessons() {
    return (select(lessonProgress)
      ..where((l) => l.isCompleted.equals(true))).watch();
  }

  // ── Earned Badges ──

  Future<List<String>> getEarnedBadgeIds() async {
    final rows = await select(earnedBadges).get();
    return rows.map((b) => b.badgeId).toList();
  }

  Future<void> earnBadge(String badgeId) =>
      attachedDatabase.transaction(() async {
        final now = DateTime.now();
        await into(earnedBadges).insertOnConflictUpdate(
          EarnedBadgesCompanion.insert(badgeId: badgeId, earnedAt: Value(now)),
        );
        await attachedDatabase.syncDao.enqueue(
          entity: 'earned_badges',
          entityKey: badgeId,
          payload: {
            'badge_id': badgeId,
            'earned_at': now.toUtc().toIso8601String(),
          },
        );
      });

  // ── User Progress KV ──

  // ── Merge from backend (pull) ──
  //
  // These apply remote state WITHOUT re-enqueueing to the outbox, and use
  // monotonic/domain-aware merges rather than blind overwrite, so pulling can
  // never lose local progress regardless of ordering.

  Future<void> mergeLessonProgress({
    required int lessonId,
    required int unitId,
    required bool isCompleted,
    required double bestScore,
    required int attempts,
    DateTime? lastAttempted,
  }) async {
    final existing =
        await (select(lessonProgress)
          ..where((l) => l.lessonId.equals(lessonId))).getSingleOrNull();
    if (existing == null) {
      await into(lessonProgress).insert(
        LessonProgressCompanion.insert(
          lessonId: Value(lessonId),
          unitId: unitId,
          isCompleted: Value(isCompleted),
          bestScore: Value(bestScore),
          attempts: Value(attempts),
          lastAttempted: Value(lastAttempted),
        ),
      );
      return;
    }
    await (update(lessonProgress)
      ..where((l) => l.lessonId.equals(lessonId))).write(
      LessonProgressCompanion(
        isCompleted: Value(existing.isCompleted || isCompleted),
        bestScore: Value(
          bestScore > existing.bestScore ? bestScore : existing.bestScore,
        ),
        attempts: Value(
          attempts > existing.attempts ? attempts : existing.attempts,
        ),
        lastAttempted: Value(_latest(existing.lastAttempted, lastAttempted)),
      ),
    );
  }

  Future<void> mergeBadge(String badgeId, DateTime earnedAt) async {
    final existing =
        await (select(earnedBadges)
          ..where((b) => b.badgeId.equals(badgeId))).getSingleOrNull();
    if (existing != null) return; // union: a badge is never un-earned
    await into(earnedBadges).insert(
      EarnedBadgesCompanion.insert(badgeId: badgeId, earnedAt: Value(earnedAt)),
    );
  }

  /// Merge a KV value from the backend. Known monotonic keys are combined;
  /// anything else takes the remote value (it's newer than our pull cursor).
  Future<void> mergeUserProgress(String key, String remoteValue) async {
    final local = await getProgressValue(key);
    String merged;
    if (local == null) {
      merged = remoteValue;
    } else if (key == 'longest_streak' || key == 'streak') {
      final a = int.tryParse(local) ?? 0;
      final b = int.tryParse(remoteValue) ?? 0;
      merged = (a > b ? a : b).toString();
    } else if (key == 'exams_passed') {
      merged = jsonEncode(_unionJsonList(local, remoteValue));
    } else {
      merged = remoteValue;
    }
    // Direct write, bypassing the outbox hook.
    await into(userProgress).insertOnConflictUpdate(
      UserProgressCompanion.insert(key: key, value: merged),
    );
  }

  DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  List<String> _unionJsonList(String a, String b) {
    final set = <String>{};
    for (final s in [a, b]) {
      try {
        set.addAll((jsonDecode(s) as List<dynamic>).map((e) => e.toString()));
      } catch (_) {
        /* ignore malformed */
      }
    }
    return set.toList();
  }

  Future<String?> getProgressValue(String key) async {
    final row =
        await (select(userProgress)
          ..where((u) => u.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setProgressValue(
    String key,
    String value,
  ) => attachedDatabase.transaction(() async {
    await into(userProgress).insertOnConflictUpdate(
      UserProgressCompanion.insert(key: key, value: value),
    );
    await attachedDatabase.syncDao.enqueue(
      entity: 'user_progress',
      entityKey: key,
      // Server column is jsonb; value is stored as an app-defined string, so
      // wrap it to preserve it verbatim regardless of whether it's JSON.
      payload: {'key': key, 'value': _asJsonValue(value)},
    );
  });

  /// Best-effort: if [value] already parses as JSON keep its structure,
  /// otherwise store it as a JSON string.
  Object? _asJsonValue(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }
}
