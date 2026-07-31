/// How well a lesson went, as the learner should experience it.
///
/// The completion screen used to show a bare percentage, which asks the
/// learner to work out for themselves whether they did well. A grade with
/// stars answers that before they finish reading.
enum LessonGrade {
  /// Every question right.
  perfect,

  /// Comfortably past the bar.
  great,

  /// Over the line.
  good,

  /// Under the bar — worth another attempt, and told so kindly.
  practice,
}

class LessonRating {
  const LessonRating._();

  /// The bar for counting a lesson as passed, matching the mastery
  /// threshold the curriculum already uses to call a unit learned.
  static const passing = 0.6;

  static const greatThreshold = 0.8;

  static LessonGrade grade(double accuracy) {
    if (accuracy >= 1.0) return LessonGrade.perfect;
    if (accuracy >= greatThreshold) return LessonGrade.great;
    if (accuracy >= passing) return LessonGrade.good;
    return LessonGrade.practice;
  }

  /// Stars fill in one at a time, each with its own note. Three is the whole
  /// scale on purpose: a five-star scale makes three feel like a failure.
  static int stars(LessonGrade grade) => switch (grade) {
    LessonGrade.perfect => 3,
    LessonGrade.great => 2,
    LessonGrade.good => 1,
    LessonGrade.practice => 0,
  };

  static bool passed(LessonGrade grade) => grade != LessonGrade.practice;

  /// Czech first, English after — the same pattern the rest of the app uses,
  /// so even the congratulations teaches a word.
  static String title(LessonGrade grade) => switch (grade) {
    LessonGrade.perfect => 'Perfektní! Perfect!',
    LessonGrade.great => 'Výborně! Excellent!',
    LessonGrade.good => 'Dobře! Well done!',
    LessonGrade.practice => 'Skoro! Almost there',
  };

  static String subtitle(LessonGrade grade) => switch (grade) {
    LessonGrade.perfect => 'Every single one right',
    LessonGrade.great => 'You have got this',
    LessonGrade.good => 'Lesson complete',
    // Never "you failed". The learner already knows it went badly; the app's
    // job here is to make another attempt feel worth starting.
    LessonGrade.practice => 'One more run will do it',
  };
}
