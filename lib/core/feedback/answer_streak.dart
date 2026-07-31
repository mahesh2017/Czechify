/// When a run of correct answers is worth calling out.
///
/// A lesson is around thirteen exercises, so these are picked to land at most
/// two or three times in one sitting. Marking every fourth answer would turn
/// the reward into wallpaper, which is the failure mode this whole layer
/// exists to avoid.
class AnswerStreak {
  const AnswerStreak._();

  static const milestones = {3, 5, 10, 15, 20, 30};

  static bool isMilestone(int streak) => milestones.contains(streak);

  /// Shown on the combo chip. Czech, because a phrase the learner sees a few
  /// times a lesson and can decode from the number beside it is free
  /// vocabulary — the app should teach even while it congratulates.
  static String label(int streak) => '$streak v řadě!';
}
