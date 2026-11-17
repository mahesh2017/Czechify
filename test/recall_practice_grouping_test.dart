import 'package:czechify/data/database/database.dart';
import 'package:czechify/domain/entities/exercise_attempt_evidence.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/domain/entities/learning_evidence.dart';
import 'package:czechify/presentation/screens/lesson/delayed_transfer_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Home's "Recall practice" showed one row per missed question, each reading
/// "Lesson 100 · try it again", so two misses in one lesson looked like the
/// same row twice; and missing a question again in a later attempt queued it
/// a second time.
void main() {
  late AppDatabase database;
  final startedAt = DateTime.utc(2026, 11, 10);

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> attempt(String id, List<int> missed) =>
      database.progressDao.recordLessonCompletion(
        attemptId: id,
        lessonId: 100,
        unitId: 1,
        score: 0.5,
        correctCount: 1,
        incorrectCount: missed.length,
        skippedCount: 0,
        startedAt: startedAt,
        activityXp: 10,
        exerciseEvidence: [
          for (final exercise in missed)
            ExerciseAttemptEvidence(
              presentationId: '$id-$exercise',
              exerciseId: exercise,
              phase: ExerciseEvidencePhase.initial,
              outcome: ExerciseOutcome.incorrect,
              answeredAt: startedAt,
            ),
        ],
      );

  Future<List<DelayedTransferAssignment>> pending() =>
      (database.select(database.delayedTransferAssignments)
            ..where((row) => row.status.equals('pending')))
          .get();

  test('missing a question again does not queue it twice', () async {
    await attempt('first', [1104, 1105]);
    await attempt('second', [1104]);

    final open = await pending();
    expect(open.map((row) => row.sourceExerciseId).toList()..sort(), [
      1104,
      1105,
    ]);
  });

  test('answering a question closes every copy of it', () async {
    // Copies can exist from before de-duplication, or arrive by sync.
    await attempt('first', [1104]);
    await database.into(database.delayedTransferAssignments).insert(
      DelayedTransferAssignmentsCompanion.insert(
        assignmentId: 'transfer:synced:1104',
        sourceAttemptId: 'synced',
        lessonId: 100,
        sourceExerciseId: 1104,
        dueAt: startedAt.add(const Duration(days: 7)),
        createdAt: startedAt,
      ),
    );
    final first = (await pending()).first;

    final done = await database.progressDao.completeTransfer(
      assignmentId: first.assignmentId,
      evidence: LearningEvidence(
        evidenceId: 'transfer-answer',
        lessonId: 100,
        exerciseId: 1107,
        skill: LearningSkill.reading,
        phase: LearningPhase.delayedTransfer,
        correct: true,
        novelTask: true,
        responseLatency: const Duration(seconds: 9),
        observedAt: first.dueAt,
      ),
    );

    expect(done, isTrue);
    expect(await pending(), isEmpty);
  });

  test('Home shows one row per lesson, with its title and a count', () async {
    await attempt('first', [1104, 1105]);
    // Recall items fall due a week after the lesson is saved.
    final due = await database.progressDao.getDueTransfers(
      DateTime.now().add(const Duration(days: 8)),
    );

    final groups = groupDueTransfers(
      due,
      titles: const {100: 'Hear Czech in Useful Words'},
    );

    expect(groups, hasLength(1));
    expect(groups.single.title, 'Hear Czech in Useful Words');
    expect(groups.single.questionCount, 2);
    expect(
      due.map((row) => row.assignmentId),
      contains(groups.single.next.assignmentId),
    );
  });

  test('copies of one question count once', () {
    DelayedTransferAssignment item(String id, int exercise, int day) =>
        DelayedTransferAssignment(
          assignmentId: id,
          sourceAttemptId: 'a',
          lessonId: 100,
          sourceExerciseId: exercise,
          dueAt: DateTime.utc(2026, 11, day),
          status: 'pending',
          createdAt: DateTime.utc(2026, 11, 1),
        );
    final groups = groupDueTransfers([
      item('late', 1104, 12),
      item('early', 1104, 10),
    ]);
    expect(groups.single.questionCount, 1);
    expect(groups.single.next.assignmentId, 'early');
    expect(groups.single.title, isNull);
  });
}
