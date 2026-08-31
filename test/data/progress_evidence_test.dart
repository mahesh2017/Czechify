import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/repositories/drift_progress_repository.dart';
import 'package:czechify/domain/entities/practice_evidence.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unit evidence uses every required lesson as its denominator', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.units)
        .insert(
          UnitsCompanion.insert(
            id: const Value(1),
            title: 'Basics',
            description: 'Basics',
            phase: 'a1',
            orderIndex: 1,
          ),
        );
    for (final lessonId in [101, 102]) {
      await database
          .into(database.lessons)
          .insert(
            LessonsCompanion.insert(
              id: Value(lessonId),
              unitId: 1,
              orderInUnit: lessonId - 101,
              title: 'Lesson $lessonId',
              description: 'Practice',
            ),
          );
    }
    await database
        .into(database.grammarRules)
        .insert(
          GrammarRulesCompanion.insert(
            id: 'GR-TEST',
            ruleName: 'Accusative forms',
            pattern: 'verb + accusative',
            explanation: 'Direct objects use the accusative.',
            caseAffected: const Value('accusative'),
            unitId: const Value(1),
          ),
        );
    await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: const Value(1001),
            lessonId: 101,
            type: 'fill_blank',
            prompt: 'Complete the sentence',
            data: '{}',
            grammarRuleId: const Value('GR-TEST'),
          ),
        );
    final attemptedAt = DateTime.utc(2026, 7, 23, 12);
    await database
        .into(database.lessonProgress)
        .insert(
          LessonProgressCompanion.insert(
            lessonId: const Value(101),
            unitId: 1,
            isCompleted: const Value(true),
            bestScore: const Value(1),
            attempts: const Value(1),
            lastAttempted: Value(attemptedAt),
          ),
        );
    await database
        .into(database.exerciseAttempts)
        .insert(
          ExerciseAttemptsCompanion.insert(
            presentationId: 'initial-1',
            lessonAttemptId: 'lesson-attempt-1',
            exerciseId: 1001,
            phase: 'initial',
            outcome: 'incorrect',
            answeredAt: attemptedAt.subtract(const Duration(minutes: 2)),
          ),
        );
    await database
        .into(database.exerciseAttempts)
        .insert(
          ExerciseAttemptsCompanion.insert(
            presentationId: 'repair-1',
            lessonAttemptId: 'lesson-attempt-1',
            exerciseId: 1001,
            phase: 'immediate_repair',
            outcome: 'correct',
            answeredAt: attemptedAt.subtract(const Duration(minutes: 1)),
          ),
        );

    final snapshot = await DriftProgressRepository(database).getSnapshot();

    expect(snapshot.unitScores[1], 0.5);
    expect(snapshot.completedLessonsByUnit[1], 1);
    expect(snapshot.totalLessonsByUnit[1], 2);
    expect(snapshot.evidenceUpdatedAt?.toUtc(), attemptedAt);
    final grammar = snapshot.componentEvidence['skill:grammar']!;
    expect(grammar.initialAttempts, 1);
    expect(grammar.firstPassAccuracy, 0);
    expect(grammar.repairAttempts, 1);
    expect(grammar.repairAccuracy, 1);
    expect(grammar.evidenceDepth, EvidenceDepth.limited);
    expect(
      snapshot.componentEvidence['grammar:GR-TEST']?.label,
      'Accusative forms',
    );
    final concept = snapshot.conceptErrors['case:accusative']!;
    expect(concept.initialErrors, 1);
    expect(concept.repairedErrors, 1);
    expect(concept.unresolvedErrors, 0);
  });
}
