import 'package:flutter_test/flutter_test.dart';
import 'package:czechify/domain/engines/curriculum_tracker.dart';
import 'package:czechify/domain/entities/enums.dart';

void main() {
  group('CurriculumProgressTracker.phaseCompletion', () {
    final tracker = CurriculumProgressTracker();

    test('denominator is ALL phase units, not just attempted ones', () {
      // 1 of 10 A1 units mastered — must be 10%, not 100%.
      final completion = tracker.phaseCompletion(
        unitScores: {1: 0.9},
        phaseUnitIds: {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
      );
      expect(completion, closeTo(0.1, 0.0001));
    });

    test('units from another phase never count (regression)', () {
      // Units 11-13 are A2; their scores must not inflate A1 completion.
      final completion = tracker.phaseCompletion(
        unitScores: {11: 0.9, 12: 0.9, 13: 0.9},
        phaseUnitIds: {1, 2, 3},
      );
      expect(completion, 0.0);
    });

    test('never exceeds 1.0', () {
      final completion = tracker.phaseCompletion(
        unitScores: {1: 0.9, 2: 0.9, 3: 0.9},
        phaseUnitIds: {1, 2, 3},
      );
      expect(completion, 1.0);
    });

    test('scores below mastery threshold do not count', () {
      final completion = tracker.phaseCompletion(
        unitScores: {1: 0.5, 2: 0.61},
        phaseUnitIds: {1, 2},
      );
      expect(completion, 0.5);
    });

    test('empty phase returns 0', () {
      expect(tracker.phaseCompletion(unitScores: {}, phaseUnitIds: {}), 0.0);
    });
  });

  group('CurriculumProgressTracker.estimateLevel', () {
    final tracker = CurriculumProgressTracker();

    test('pre-A1 by default', () {
      expect(
        tracker.estimateLevel(
          a1Completion: 0.0,
          a2Completion: 0.0,
          examsPassed: {},
        ),
        CEFRLevel.preA1,
      );
    });

    test('A1 requires >80% completion AND a passed exam', () {
      expect(
        tracker.estimateLevel(
          a1Completion: 0.9,
          a2Completion: 0.0,
          examsPassed: {},
        ),
        CEFRLevel.preA1,
      );
      expect(
        tracker.estimateLevel(
          a1Completion: 0.9,
          a2Completion: 0.0,
          examsPassed: {'a1'},
        ),
        CEFRLevel.a1,
      );
    });

    test('A2 outranks A1', () {
      expect(
        tracker.estimateLevel(
          a1Completion: 0.9,
          a2Completion: 0.9,
          examsPassed: {'a1', 'a2'},
        ),
        CEFRLevel.a2,
      );
    });
  });

  group('CurriculumProgressTracker.phaseLessonCoverage', () {
    final tracker = CurriculumProgressTracker();

    test('counts completed lessons against every required phase lesson', () {
      final coverage = tracker.phaseLessonCoverage(
        completedLessonsByUnit: {1: 1, 2: 2, 99: 10},
        totalLessonsByUnit: {1: 2, 2: 3, 99: 10},
        phaseUnitIds: {1, 2},
      );
      expect(coverage, 0.6);
    });

    test('empty phase has no coverage', () {
      expect(
        tracker.phaseLessonCoverage(
          completedLessonsByUnit: const {},
          totalLessonsByUnit: const {},
          phaseUnitIds: const {},
        ),
        0,
      );
    });
  });
}
