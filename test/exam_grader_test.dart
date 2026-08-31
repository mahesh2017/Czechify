import 'package:flutter_test/flutter_test.dart';
import 'package:czechify/domain/engines/exam_grader.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/repositories/exam_repository.dart';

MockExam _cceFormatExam() {
  return const MockExam(
    level: ExamLevel.a1,
    blueprint: ExamBlueprint(
      product: ExamProduct.permanentResidence,
      version: '2026-04-11',
      effectiveDate: '2026-04-11',
      scoringRule: ExamScoringRule.rawPointsWrittenSpeakingGate,
    ),
    totalTimeMinutes: 120,
    sections: [
      MockExamSection(
        type: ExamSectionType.reading,
        timeLimitMinutes: 40,
        questions: [
          {'prompt': 'r1', 'options': [], 'correct_answer': 0, 'points': 5},
          {'prompt': 'r2', 'options': [], 'correct_answer': 1, 'points': 5},
          {'prompt': 'r3', 'options': [], 'correct_answer': 2, 'points': 5},
          {'prompt': 'r4', 'options': [], 'correct_answer': 3, 'points': 5},
          {'prompt': 'r5', 'options': [], 'correct_answer': 4, 'points': 5},
        ],
        maxScore: 25,
      ),
      MockExamSection(
        type: ExamSectionType.listening,
        timeLimitMinutes: 40,
        questions: [
          {'prompt': 'l1', 'options': [], 'correct_answer': 4, 'points': 5},
          {'prompt': 'l2', 'options': [], 'correct_answer': 3, 'points': 5},
          {'prompt': 'l3', 'options': [], 'correct_answer': 2, 'points': 5},
          {'prompt': 'l4', 'options': [], 'correct_answer': 1, 'points': 5},
          {'prompt': 'l5', 'options': [], 'correct_answer': 0, 'points': 5},
        ],
        maxScore: 25,
      ),
      MockExamSection(
        type: ExamSectionType.writing,
        timeLimitMinutes: 25,
        questions: [
          {'prompt': 'w1', 'min_words': 30, 'points': 20},
        ],
        maxScore: 20,
      ),
      MockExamSection(
        type: ExamSectionType.speaking,
        timeLimitMinutes: 15,
        questions: [
          {'prompt': 's1', 'target_text': 'Ahoj', 'points': 40},
        ],
        maxScore: 40,
      ),
    ],
  );
}

void main() {
  group('ExamGrader', () {
    final grader = ExamGrader();

    test(
      'sections are graded independently (regression: shared answer map)',
      () {
        final exam = _cceFormatExam();
        // Reading answered perfectly; listening answered with reading's
        // answers — must NOT be counted as listening being correct.
        final scores = grader.grade(
          exam: exam,
          answers: {
            0: {0: 0, 1: 1, 2: 2, 3: 3, 4: 4}, // reading: all correct
            1: {
              0: 0,
              1: 1,
              2: 2,
              3: 3,
              4: 4,
            }, // listening: all wrong (correct are 4,3,2,1,0)
          },
        );

        expect(scores.reading, 100);
        expect(scores.readingPoints, 25);
        // Listening: user answered 0,1,2,3,4 but correct is 4,3,2,1,0
        // Only question 2 (correct=2, user=2) matches → 5 points → 20%
        expect(scores.listeningPoints, 5);
        expect(scores.listening, 20);
      },
    );

    test('unanswered questions never count as correct (null == null)', () {
      final exam = _cceFormatExam();
      final scores = grader.grade(exam: exam, answers: {});

      expect(scores.reading, 0);
      expect(scores.listening, 0);
      expect(scores.writing, 0);
      expect(scores.speaking, 0);
      expect(scores.total, 0);
      expect(scores.passed, isFalse);
    });

    test('writing and speaking use externally provided scores', () {
      final exam = _cceFormatExam();
      final scores = grader.grade(
        exam: exam,
        answers: {
          0: {0: 0, 1: 1, 2: 2, 3: 3, 4: 4},
          1: {0: 4, 1: 3, 2: 2, 3: 1, 4: 0},
        },
        writingScore: 80,
        speakingScore: 60,
      );

      expect(scores.writing, 80);
      expect(scores.speaking, 60);
      // Writing: 80% of 20 = 16 points; Speaking: 60% of 40 = 24 points
      expect(scores.writingPoints, 16);
      expect(scores.speakingPoints, 24);
      // Total points: 25 + 16 + 25 + 24 = 90 out of 110
      expect(scores.totalPoints, 90);
      expect(scores.totalMax, 110);
    });

    test('external scores are clamped to 0-100', () {
      final exam = _cceFormatExam();
      final scores = grader.grade(
        exam: exam,
        answers: {},
        writingScore: 250,
        speakingScore: -10,
      );

      expect(scores.writing, 100);
      expect(scores.speaking, 0);
    });

    test('missing productive-task evaluation can never produce a pass', () {
      final scores = grader.grade(
        exam: _cceFormatExam(),
        answers: {
          0: {0: 1},
          2: {0: 0},
        },
        writingScore: null,
        speakingScore: null,
      );

      expect(scores.fullyScored, isFalse);
      expect(scores.passed, isFalse);
    });

    test('partial credit returns raw points', () {
      final exam = _cceFormatExam();
      final scores = grader.grade(
        exam: exam,
        answers: {
          0: {0: 0}, // 1 of 5 reading correct = 5 points
        },
      );

      expect(scores.readingPoints, 5);
      expect(scores.reading, 20); // 5/25 = 20%
    });

    test('dual pass threshold: written AND speaking must both be >= 60%', () {
      final exam = _cceFormatExam();

      // Perfect reading + listening, 60% writing, 60% speaking → pass
      final passing = grader.grade(
        exam: exam,
        answers: {
          0: {0: 0, 1: 1, 2: 2, 3: 3, 4: 4},
          1: {0: 4, 1: 3, 2: 2, 3: 1, 4: 0},
        },
        writingScore: 60,
        speakingScore: 60,
      );
      // Written: 25 + 12 + 25 = 62 out of 70 = 88% → pass
      // Speaking: 24 out of 40 = 60% → pass
      expect(passing.passed, isTrue);

      // Perfect reading + listening, 60% writing, 50% speaking → fail
      final failingSpeaking = grader.grade(
        exam: exam,
        answers: {
          0: {0: 0, 1: 1, 2: 2, 3: 3, 4: 4},
          1: {0: 4, 1: 3, 2: 2, 3: 1, 4: 0},
        },
        writingScore: 60,
        speakingScore: 50,
      );
      // Speaking: 50% of 40 = 20 points → 50% → fail
      expect(failingSpeaking.passed, isFalse);
    });

    test('fail if written parts below 60% even with perfect speaking', () {
      final exam = _cceFormatExam();
      final scores = grader.grade(
        exam: exam,
        answers: {
          0: {0: 0}, // 1/5 reading correct = 5 points
          1: {0: 0}, // 1/5 listening correct = 5 points
        },
        writingScore: 10, // 10% of 20 = 2 points
        speakingScore: 100, // perfect speaking
      );
      // Written: 5 + 2 + 5 = 12 out of 70 = 17% → fail
      // Speaking: 40 out of 40 = 100% → pass
      // But overall: fail because written < 60%
      expect(scores.passed, isFalse);
    });

    test('raw points and max points are tracked correctly', () {
      final exam = _cceFormatExam();
      final scores = grader.grade(
        exam: exam,
        answers: {
          0: {0: 0, 1: 1, 2: 2, 3: 3, 4: 4}, // 25/25 reading
          1: {0: 4, 1: 3, 2: 2, 3: 1, 4: 0}, // 25/25 listening
        },
        writingScore: 100, // 20/20 writing
        speakingScore: 100, // 40/40 speaking
      );

      expect(scores.readingPoints, 25);
      expect(scores.readingMax, 25);
      expect(scores.listeningPoints, 25);
      expect(scores.listeningMax, 25);
      expect(scores.writingPoints, 20);
      expect(scores.writingMax, 20);
      expect(scores.speakingPoints, 40);
      expect(scores.speakingMax, 40);
      expect(scores.totalPoints, 110);
      expect(scores.totalMax, 110);
      expect(scores.total, 100);
      expect(scores.passed, isTrue);
    });
  });
}
