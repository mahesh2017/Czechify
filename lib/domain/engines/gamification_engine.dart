import '../entities/gamification_state.dart';

/// Result of heart processing on a wrong answer.
class HeartResult {
  final int hearts;
  final bool isGameOver;
  final bool canRefill;

  const HeartResult({
    required this.hearts,
    required this.isGameOver,
    required this.canRefill,
  });
}

/// Gamification engine — manages XP, hearts, streaks, and badges.
/// Pure state machine, no I/O.
class GamificationEngine {
  /// Calculate XP earned for an action.
  int calculateXp({
    required XpActionType actionType,
    double accuracy = 0.0,
    int reviewCount = 0,
    int streakDays = 0,
    int baseXp = 0,
  }) {
    return switch (actionType) {
      XpActionType.reviewSessionCompleted => reviewCount * 2,
      XpActionType.streakMilestone => streakDays * 5,
      XpActionType.badgeEarned => baseXp,
      XpActionType.mockExamCompleted => 50,
      XpActionType.pronunciationDrill when accuracy >= 0.8 => 10,
      XpActionType.pronunciationDrill => 5,
    };
  }

  /// Process a wrong answer: deduct hearts (never below 0), check for game over.
  HeartResult processWrongAnswer(GamificationState state) {
    final newHearts = (state.hearts - 1).clamp(0, state.maxHearts);
    return HeartResult(
      hearts: newHearts,
      isGameOver: newHearts <= 0,
      canRefill: newHearts <= 0,
    );
  }

  /// Check which badges should be unlocked based on progress.
  List<Badge> checkBadges(ProgressSnapshot progress) {
    final unlocked = <Badge>[];
    for (final badge in Badge.all) {
      if (!progress.earnedBadges.contains(badge.id) &&
          badge.criteria.isMet(progress)) {
        unlocked.add(badge);
      }
    }
    return unlocked;
  }

  /// The rank a lifetime XP total has reached.
  ///
  /// Lifetime, not weekly: nothing in the app tracks or resets a weekly total,
  /// and [Rank] explains why that is the intended design rather than an
  /// omission. This signature used to say `weeklyXp` while its only caller
  /// passed the lifetime figure.
  Rank rankFor(int lifetimeXp) {
    Rank? result;
    for (final rank in Rank.values) {
      if (lifetimeXp >= rank.xpThreshold) {
        result = rank;
      }
    }
    return result ?? Rank.bronze;
  }
}

/// Types of actions that earn XP.
enum XpActionType {
  // Lessons deliberately have no entry here. Their award is the sum of the
  // per-exercise `xp_reward` values the learner saw credited during the
  // lesson; a second rule here is what let the displayed and recorded totals
  // drift apart.
  reviewSessionCompleted,
  streakMilestone,
  badgeEarned,
  mockExamCompleted,
  pronunciationDrill,
}
