import 'practice_evidence.dart';
import 'concept_error_evidence.dart';

/// Gamification state.
class GamificationState {
  final int hearts;
  final int maxHearts;
  final int currentStreak;
  final int longestStreak;
  final int totalXp;
  final int dailyXp;
  final int dailyGoalXp;
  final int gems;
  final Set<String> earnedBadges;
  final DateTime? lastHeartRefill;
  final bool streakFreezeAvailable;

  const GamificationState({
    this.hearts = 5,
    this.maxHearts = 5,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalXp = 0,
    this.dailyXp = 0,
    this.dailyGoalXp = 50,
    this.gems = 0,
    this.earnedBadges = const {},
    this.lastHeartRefill,
    this.streakFreezeAvailable = true,
  });

  GamificationState copyWith({
    int? hearts,
    int? maxHearts,
    int? currentStreak,
    int? longestStreak,
    int? totalXp,
    int? dailyXp,
    int? dailyGoalXp,
    int? gems,
    Set<String>? earnedBadges,
    DateTime? lastHeartRefill,
    bool? streakFreezeAvailable,
  }) {
    return GamificationState(
      hearts: hearts ?? this.hearts,
      maxHearts: maxHearts ?? this.maxHearts,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalXp: totalXp ?? this.totalXp,
      dailyXp: dailyXp ?? this.dailyXp,
      dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
      gems: gems ?? this.gems,
      earnedBadges: earnedBadges ?? this.earnedBadges,
      lastHeartRefill: lastHeartRefill ?? this.lastHeartRefill,
      streakFreezeAvailable:
          streakFreezeAvailable ?? this.streakFreezeAvailable,
    );
  }

  bool get isGameOver => hearts <= 0;
  bool get dailyGoalMet => dailyXp >= dailyGoalXp;
}

/// Badge definition.
class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int xpReward;
  final BadgeCriteria criteria;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.xpReward,
    required this.criteria,
  });

  static const List<Badge> all = [
    Badge(
      id: 'case_nominative',
      name: 'First Case',
      description: 'Complete Unit 3 with 80%+',
      icon: '🏆',
      xpReward: 10,
      criteria: BadgeCriteria(unitId: 3, minAccuracy: 0.8),
    ),
    Badge(
      id: 'case_accusative',
      name: 'Object Master',
      description: 'Complete Unit 6 with 80%+',
      icon: '🎯',
      xpReward: 15,
      criteria: BadgeCriteria(unitId: 6, minAccuracy: 0.8),
    ),
    Badge(
      id: 'verb_byt',
      name: 'To Be Master',
      description: 'Perfect conjugation of být',
      icon: '⭐',
      xpReward: 10,
      criteria: BadgeCriteria(customKey: 'byt_conjugation', minValue: 1.0),
    ),
    // Units 7 to 28 awarded nothing at all — the longest stretch of the
    // course, and the one where people give up. These sit roughly every
    // fourth unit so there is always a next thing within reach.
    Badge(
      id: 'unit_09',
      name: 'Past Tense',
      description: 'Complete Unit 9 with 80%+',
      icon: '⏳',
      xpReward: 20,
      criteria: BadgeCriteria(unitId: 9, minAccuracy: 0.8),
    ),
    Badge(
      id: 'unit_12',
      name: 'Halfway There',
      description: 'Complete Unit 12 with 80%+',
      icon: '🧭',
      xpReward: 25,
      criteria: BadgeCriteria(unitId: 12, minAccuracy: 0.8),
    ),
    Badge(
      id: 'unit_16',
      name: 'Getting Fluent',
      description: 'Complete Unit 16 with 80%+',
      icon: '💬',
      xpReward: 30,
      criteria: BadgeCriteria(unitId: 16, minAccuracy: 0.8),
    ),
    Badge(
      id: 'unit_20',
      name: 'Twenty Down',
      description: 'Complete Unit 20 with 80%+',
      icon: '🗿',
      xpReward: 35,
      criteria: BadgeCriteria(unitId: 20, minAccuracy: 0.8),
    ),
    Badge(
      id: 'unit_24',
      name: 'Home Straight',
      description: 'Complete Unit 24 with 80%+',
      icon: '🚩',
      xpReward: 40,
      criteria: BadgeCriteria(unitId: 24, minAccuracy: 0.8),
    ),
    Badge(
      id: 'unit_28',
      name: 'A1 Finisher',
      description: 'Complete Unit 28 with 80%+',
      icon: '🏅',
      xpReward: 60,
      criteria: BadgeCriteria(unitId: 28, minAccuracy: 0.8),
    ),
    // Short streaks matter most: almost everyone who quits does so in the
    // first fortnight, long before a 30-day badge is reachable.
    Badge(
      id: 'streak_3',
      name: 'Getting Started',
      description: '3-day streak',
      icon: '🌱',
      xpReward: 10,
      criteria: BadgeCriteria(minStreak: 3),
    ),
    Badge(
      id: 'streak_7',
      name: 'Week Warrior',
      description: '7-day streak',
      icon: '🔥',
      xpReward: 20,
      criteria: BadgeCriteria(minStreak: 7),
    ),
    Badge(
      id: 'streak_14',
      name: 'Fortnight',
      description: '14-day streak',
      icon: '🔥',
      xpReward: 30,
      criteria: BadgeCriteria(minStreak: 14),
    ),
    Badge(
      id: 'streak_30',
      name: 'Monthly Master',
      description: '30-day streak',
      icon: '🔥',
      xpReward: 50,
      criteria: BadgeCriteria(minStreak: 30),
    ),
    Badge(
      id: 'streak_100',
      name: 'Hundred Days',
      description: '100-day streak',
      icon: '💎',
      xpReward: 150,
      criteria: BadgeCriteria(minStreak: 100),
    ),
    Badge(
      id: 'mock_a1_pass',
      name: 'A1 Practice Milestone',
      description: 'Meet the target in an A1 practice set',
      icon: '🎓',
      xpReward: 50,
      criteria: BadgeCriteria(examPassed: 'a1'),
    ),
    Badge(
      id: 'mock_a2_pass',
      name: 'A2 Practice Milestone',
      description: 'Meet the target in an A2 practice set',
      icon: '🎓',
      xpReward: 100,
      criteria: BadgeCriteria(examPassed: 'a2'),
    ),
  ];
}

/// Criteria for unlocking a badge.
class BadgeCriteria {
  final int? unitId;
  final double? minAccuracy;
  final int? minStreak;
  final String? examPassed;
  final String? customKey;
  final double? minValue;

  const BadgeCriteria({
    this.unitId,
    this.minAccuracy,
    this.minStreak,
    this.examPassed,
    this.customKey,
    this.minValue,
  });

  bool isMet(ProgressSnapshot progress) {
    if (unitId != null && minAccuracy != null) {
      final unitScore = progress.unitScores[unitId];
      if (unitScore == null || unitScore < minAccuracy!) return false;
    }
    if (minStreak != null) {
      if (progress.longestStreak < minStreak!) return false;
    }
    if (examPassed != null) {
      if (!progress.examsPassed.contains(examPassed)) return false;
    }
    // Custom key badges require a matching progress value
    if (customKey != null) {
      final value = progress.customValues[customKey];
      if (value == null) return false;
      if (minValue != null && value < minValue!) return false;
    }
    // If only customKey/minValue is set and no other criteria matched, it's not met
    // unless the custom value is present
    if (customKey == null &&
        unitId == null &&
        minStreak == null &&
        examPassed == null) {
      return false; // No criteria = not met (safety)
    }
    return true;
  }
}

/// A snapshot of learner progress for badge evaluation.
class ProgressSnapshot {
  final Map<int, double> unitScores;
  final Map<int, int> completedLessonsByUnit;
  final Map<int, int> totalLessonsByUnit;
  final DateTime? evidenceUpdatedAt;
  final Map<String, PracticeEvidence> componentEvidence;
  final Map<String, ConceptErrorEvidence> conceptErrors;
  final int longestStreak;
  final Set<String> examsPassed;
  final Set<String> earnedBadges;
  final double a1CompletionRate;
  final double a2CompletionRate;
  final Map<String, double> customValues;

  const ProgressSnapshot({
    this.unitScores = const {},
    this.completedLessonsByUnit = const {},
    this.totalLessonsByUnit = const {},
    this.evidenceUpdatedAt,
    this.componentEvidence = const {},
    this.conceptErrors = const {},
    this.longestStreak = 0,
    this.examsPassed = const {},
    this.earnedBadges = const {},
    this.a1CompletionRate = 0.0,
    this.a2CompletionRate = 0.0,
    this.customValues = const {},
  });
}

/// League tiers.
/// Progression tiers, read against lifetime [GamificationState.totalXp].
///
/// A rank, not a league, and deliberately so. A league is a cohort you are
/// ranked within and promoted or relegated from each week; this app has no
/// leaderboard and shows the learner no one else, so the weekly reset the old
/// name implied would have dropped everyone to bronze each Monday for no
/// competitive payoff. What this is — and the app's only progression ladder,
/// there being no level system anywhere — is a rank that climbs with lifetime
/// XP and never falls.
///
/// Thresholds were scaled with the lesson award when it became the sum of the
/// per-exercise XP shown to the learner (a median lesson pays 125), so the
/// climb takes the number of lessons it always did.
enum Rank {
  bronze(0),
  silver(600),
  gold(1800),
  platinum(3600),
  diamond(6000);

  const Rank(this.xpThreshold);

  /// Lifetime XP at which this rank is reached.
  final int xpThreshold;
}
