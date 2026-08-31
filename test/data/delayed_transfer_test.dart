import 'package:czechify/data/database/database.dart';
import 'package:czechify/domain/entities/exercise_attempt_evidence.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/domain/entities/learning_evidence.dart';
import 'package:czechify/domain/engines/placement_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transfer completion requires a different delayed novel task', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final startedAt = DateTime.utc(2026, 7, 23);
    await database.progressDao.savePlacement(
      const PlacementResult(
        estimates: {
          LearningSkill.reading: 0.45,
          LearningSkill.listening: 0.6,
          LearningSkill.writing: 0.6,
        },
        provisionalUnit: 6,
        sampleSize: 9,
      ),
    );
    await database.progressDao.recordLessonCompletion(
      attemptId: 'attempt-transfer',
      lessonId: 101,
      unitId: 1,
      score: 0,
      correctCount: 0,
      incorrectCount: 1,
      skippedCount: 0,
      startedAt: startedAt,
      activityXp: 0,
      exerciseEvidence: [
        ExerciseAttemptEvidence(
          presentationId: 'initial-error',
          exerciseId: 1001,
          phase: ExerciseEvidencePhase.initial,
          outcome: ExerciseOutcome.incorrect,
          answeredAt: startedAt,
        ),
      ],
    );
    final assignment =
        (await database.select(database.delayedTransferAssignments).get())
            .single;

    LearningEvidence evidence(int exerciseId) => LearningEvidence(
      evidenceId: 'transfer-evidence-$exerciseId',
      lessonId: 101,
      exerciseId: exerciseId,
      skill: LearningSkill.reading,
      phase: LearningPhase.delayedTransfer,
      correct: true,
      novelTask: true,
      responseLatency: const Duration(seconds: 12),
      observedAt: assignment.dueAt,
    );

    expect(
      () => database.progressDao.completeTransfer(
        assignmentId: assignment.assignmentId,
        evidence: evidence(1001),
      ),
      throwsArgumentError,
    );
    expect(
      await database.progressDao.completeTransfer(
        assignmentId: assignment.assignmentId,
        evidence: evidence(1002),
      ),
      isTrue,
    );
    expect(
      await database.progressDao.completeTransfer(
        assignmentId: assignment.assignmentId,
        evidence: evidence(1003),
      ),
      isFalse,
    );
    expect(
      await database.progressDao.getDueTransfers(
        assignment.dueAt.add(const Duration(days: 1)),
      ),
      isEmpty,
    );
    final profile =
        (await database.select(database.placementProfiles).get()).single;
    expect(profile.provisionalUnit, 12);
    expect(profile.estimatesJson, contains('"reading":0.5'));
  });
}
