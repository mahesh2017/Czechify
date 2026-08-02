/// The learner situation that should lead the daily welcome.
enum DailyArrivalKind {
  firstStep,
  keepStreak,
  reviewsReady,
  welcomeBack,
  goalComplete,
  courseComplete,
}

/// Everything the arrival screen needs, reduced to an immutable UI model.
///
/// Keeping this independent of Flutter and persistence makes the motivational
/// rules deterministic and straightforward to test.
class DailyArrivalState {
  const DailyArrivalState({
    required this.kind,
    required this.learnerName,
    required this.streak,
    required this.dailyXp,
    required this.dailyGoalXp,
    required this.dueReviews,
    this.lessonId,
    this.lessonTitle,
    this.unitTitle,
  });

  final DailyArrivalKind kind;
  final String learnerName;
  final int streak;
  final int dailyXp;
  final int dailyGoalXp;
  final int dueReviews;
  final int? lessonId;
  final String? lessonTitle;
  final String? unitTitle;

  bool get hasLesson => lessonId != null;
  double get goalProgress =>
      dailyGoalXp <= 0 ? 0 : (dailyXp / dailyGoalXp).clamp(0, 1).toDouble();
}

/// Selects one useful, encouraging message instead of showing every metric.
class DailyArrivalEngine {
  const DailyArrivalEngine();

  DailyArrivalState select({
    required String learnerName,
    required int streak,
    required int totalXp,
    required int dailyXp,
    required int dailyGoalXp,
    required int dueReviews,
    required int daysSinceActivity,
    int? lessonId,
    String? lessonTitle,
    String? unitTitle,
  }) {
    final kind = switch ((
      dailyXp >= dailyGoalXp && dailyGoalXp > 0,
      daysSinceActivity >= 2 && totalXp > 0,
      dueReviews > 0,
      streak > 0,
      lessonId != null,
    )) {
      (true, _, _, _, _) => DailyArrivalKind.goalComplete,
      (_, true, _, _, _) => DailyArrivalKind.welcomeBack,
      (_, _, true, _, _) => DailyArrivalKind.reviewsReady,
      (_, _, _, true, _) => DailyArrivalKind.keepStreak,
      (_, _, _, _, true) => DailyArrivalKind.firstStep,
      _ => DailyArrivalKind.courseComplete,
    };

    return DailyArrivalState(
      kind: kind,
      learnerName: learnerName.trim(),
      streak: streak,
      dailyXp: dailyXp,
      dailyGoalXp: dailyGoalXp,
      dueReviews: dueReviews,
      lessonId: lessonId,
      lessonTitle: lessonTitle,
      unitTitle: unitTitle,
    );
  }
}

/// Calendar-day frequency rules for the richer welcome.
class DailyArrivalSchedule {
  const DailyArrivalSchedule._();

  static String dayKey(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  static bool shouldShow({
    required String? lastShownDay,
    required DateTime now,
  }) => lastShownDay != dayKey(now);
}
