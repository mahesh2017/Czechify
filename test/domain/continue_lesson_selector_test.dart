import 'package:czechify/domain/engines/continue_lesson_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const selector = ContinueLessonSelector();

  // Three A1 lessons, then three A2 lessons.
  const course = [
    ContinueLessonCandidate(lessonId: 1, isPreferredLevel: false),
    ContinueLessonCandidate(lessonId: 2, isPreferredLevel: false),
    ContinueLessonCandidate(lessonId: 3, isPreferredLevel: false),
    ContinueLessonCandidate(lessonId: 16),
    ContinueLessonCandidate(lessonId: 17),
    ContinueLessonCandidate(lessonId: 18),
  ];
  const everything = {1, 2, 3, 16, 17, 18};

  test('nothing finished starts at the chosen level', () {
    expect(
      selector.select(
        lessons: course,
        unlockedLessonIds: everything,
        completedAt: const {},
      ),
      16,
    );
  });

  test('nothing finished and the chosen level locked starts anywhere', () {
    expect(
      selector.select(
        lessons: course,
        unlockedLessonIds: const {1},
        completedAt: const {},
      ),
      1,
    );
  });

  test('continues with the lesson after the last one finished', () {
    expect(
      selector.select(
        lessons: course,
        unlockedLessonIds: everything,
        completedAt: {1: DateTime(2026, 9, 1), 2: DateTime(2026, 9, 2)},
      ),
      3,
    );
  });

  test('the most recent finish decides, not the furthest one', () {
    // An A2 starter who went back and did A1 lesson 1 yesterday continues
    // with A1 lesson 2.
    expect(
      selector.select(
        lessons: course,
        unlockedLessonIds: everything,
        completedAt: {
          16: DateTime(2026, 9, 1),
          17: DateTime(2026, 9, 2),
          1: DateTime(2026, 9, 3),
        },
      ),
      2,
    );
  });

  test('a replayed earlier lesson walks on past what is already done', () {
    expect(
      selector.select(
        lessons: course,
        unlockedLessonIds: everything,
        completedAt: {
          1: DateTime(2026, 9, 5),
          2: DateTime(2026, 9, 2),
          3: DateTime(2026, 9, 3),
        },
      ),
      16,
    );
  });

  test('a locked next lesson is skipped', () {
    expect(
      selector.select(
        lessons: course,
        unlockedLessonIds: const {1, 2, 17},
        completedAt: {1: DateTime(2026, 9, 1), 2: DateTime(2026, 9, 2)},
      ),
      17,
    );
  });

  test('when everything after is finished, the earliest gap is next', () {
    expect(
      selector.select(
        lessons: course,
        unlockedLessonIds: everything,
        completedAt: {
          1: DateTime(2026, 9, 1),
          3: DateTime(2026, 9, 2),
          16: DateTime(2026, 9, 3),
          17: DateTime(2026, 9, 4),
          18: DateTime(2026, 9, 5),
        },
      ),
      2,
    );
  });

  test('without recorded times the furthest finished lesson counts', () {
    expect(
      selector.select(
        lessons: course,
        unlockedLessonIds: everything,
        completedAt: const {1: null, 2: null},
      ),
      3,
    );
  });

  test('a finished course has nothing to continue', () {
    expect(
      selector.select(
        lessons: course,
        unlockedLessonIds: everything,
        completedAt: {
          for (final lesson in course) lesson.lessonId: DateTime(2026, 9, 1),
        },
      ),
      isNull,
    );
  });
}
