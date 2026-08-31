import 'package:czechify/domain/engines/lesson_rating.dart';
import 'package:flutter_test/flutter_test.dart';

/// The completion screen used to show a bare percentage, which asks the
/// learner to work out for themselves whether they did well. These pin the
/// bands that answer it for them.
void main() {
  group('grade bands', () {
    test('everything right is perfect', () {
      expect(LessonRating.grade(1.0), LessonGrade.perfect);
    });

    test('one slip is still excellent', () {
      expect(LessonRating.grade(0.92), LessonGrade.great);
      expect(LessonRating.grade(0.8), LessonGrade.great);
    });

    test('over the bar is a pass', () {
      expect(LessonRating.grade(0.6), LessonGrade.good);
      expect(LessonRating.grade(0.79), LessonGrade.good);
    });

    test('under the bar asks for another run', () {
      expect(LessonRating.grade(0.59), LessonGrade.practice);
      expect(LessonRating.grade(0), LessonGrade.practice);
    });

    test('the bar matches the one the curriculum already uses', () {
      // CurriculumProgressTracker calls a unit learned at 0.6; a lesson that
      // counts as passed here and not there would be incoherent.
      expect(LessonRating.passing, 0.6);
    });
  });

  group('stars', () {
    test('they run one to three, never zero for a pass', () {
      expect(LessonRating.stars(LessonGrade.perfect), 3);
      expect(LessonRating.stars(LessonGrade.great), 2);
      expect(LessonRating.stars(LessonGrade.good), 1);
    });

    test('a lesson under the bar earns none', () {
      expect(LessonRating.stars(LessonGrade.practice), 0);
    });

    test('every passing grade is distinguishable at a glance', () {
      final passing = LessonGrade.values.where(LessonRating.passed);
      final counts = passing.map(LessonRating.stars).toSet();
      expect(counts, hasLength(passing.length));
    });
  });

  group('what it says', () {
    test('passing is celebrated in Czech first', () {
      // Even the congratulation teaches a word — the same pattern the rest
      // of the app uses.
      for (final grade in LessonGrade.values) {
        expect(LessonRating.title(grade), contains('!'));
      }
      expect(LessonRating.title(LessonGrade.perfect), contains('Perfektní'));
    });

    test('falling short is never called failure', () {
      // The learner already knows it went badly. The only job left is making
      // another attempt feel worth starting.
      final text =
          '${LessonRating.title(LessonGrade.practice)} '
                  '${LessonRating.subtitle(LessonGrade.practice)}'
              .toLowerCase();
      for (final word in ['fail', 'wrong', 'bad', 'poor']) {
        expect(text, isNot(contains(word)), reason: 'says "$word"');
      }
    });

    test('every grade has something to say', () {
      for (final grade in LessonGrade.values) {
        expect(LessonRating.title(grade), isNotEmpty);
        expect(LessonRating.subtitle(grade), isNotEmpty);
      }
    });
  });
}
