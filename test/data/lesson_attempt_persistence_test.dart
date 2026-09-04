import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:czechify/data/database/database.dart';
import 'package:czechify/domain/entities/exercise_attempt_evidence.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('replaying an attempt ID cannot increment completion twice', () async {
    final startedAt = DateTime.utc(2026, 7, 23, 8);

    Future<bool> commit() => database.progressDao.recordLessonCompletion(
      attemptId: 'attempt-1',
      lessonId: 101,
      unitId: 1,
      score: 0.75,
      correctCount: 3,
      incorrectCount: 1,
      skippedCount: 0,
      startedAt: startedAt,
      activityXp: 20,
      exerciseEvidence: const [],
    );

    expect(await commit(), isTrue);
    expect(await commit(), isFalse);

    final attempts = await database.select(database.lessonAttempts).get();
    final progress = await database.select(database.lessonProgress).get();
    final rewards = await database.select(database.rewardLedger).get();
    final gamification =
        await database.select(database.gamificationStateTable).getSingle();

    expect(attempts, hasLength(1));
    expect(attempts.single.attemptId, 'attempt-1');
    expect(attempts.single.startedAt.toUtc(), startedAt);
    expect(progress.single.attempts, 1);
    expect(progress.single.bestScore, 0.75);
    expect(rewards, hasLength(1));
    expect(rewards.single.rewardId, 'lesson:attempt-1');
    expect(rewards.single.xp, 20);
    expect(gamification.totalXp, 20);
    expect(gamification.dailyXp, 20);
  });

  test(
    'distinct attempts remain immutable and improve only best score',
    () async {
      final startedAt = DateTime.utc(2026, 7, 23, 8);

      await database.progressDao.recordLessonCompletion(
        attemptId: 'attempt-low',
        lessonId: 101,
        unitId: 1,
        score: 0.5,
        correctCount: 2,
        incorrectCount: 2,
        skippedCount: 0,
        startedAt: startedAt,
        activityXp: 10,
        exerciseEvidence: [
          ExerciseAttemptEvidence(
            presentationId: 'presentation-initial',
            exerciseId: 1001,
            phase: ExerciseEvidencePhase.initial,
            outcome: ExerciseOutcome.incorrect,
            answeredAt: startedAt.add(const Duration(minutes: 1)),
          ),
          ExerciseAttemptEvidence(
            presentationId: 'presentation-repair',
            exerciseId: 1001,
            phase: ExerciseEvidencePhase.immediateRepair,
            outcome: ExerciseOutcome.correct,
            answeredAt: startedAt.add(const Duration(minutes: 2)),
          ),
        ],
      );
      await database.progressDao.recordLessonCompletion(
        attemptId: 'attempt-high',
        lessonId: 101,
        unitId: 1,
        score: 1,
        correctCount: 4,
        incorrectCount: 0,
        skippedCount: 0,
        startedAt: startedAt.add(const Duration(minutes: 5)),
        activityXp: 20,
        exerciseEvidence: const [],
        phase: 'delayed_transfer',
      );

      final attempts = await database.select(database.lessonAttempts).get();
      final progress = await database.select(database.lessonProgress).get();
      final rewards = await database.select(database.rewardLedger).get();
      final gamification =
          await database.select(database.gamificationStateTable).getSingle();
      final exerciseAttempts =
          await database.select(database.exerciseAttempts).get();
      final transfers =
          await database.select(database.delayedTransferAssignments).get();

      expect(attempts, hasLength(2));
      expect(
        attempts.map((row) => row.phase),
        containsAll(['initial', 'delayed_transfer']),
      );
      expect(progress.single.attempts, 2);
      expect(progress.single.bestScore, 1);
      expect(rewards, hasLength(2));
      expect(gamification.totalXp, 30);
      expect(exerciseAttempts, hasLength(2));
      expect(
        exerciseAttempts.map((row) => row.phase),
        containsAll(['initial', 'immediate_repair']),
      );
      expect(transfers, hasLength(1));
      expect(transfers.single.sourceExerciseId, 1001);
      expect(transfers.single.status, 'pending');
    },
  );
}
