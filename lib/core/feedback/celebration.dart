import 'sfx.dart';

/// Shared timing for the visual and sensory beats of earned celebrations.
///
/// Durations live here so the host, painters and completion screens cannot
/// silently drift into different interpretations of "impact".
abstract final class CelebrationTimeline {
  static const lessonReveal = Duration(milliseconds: 1700);
  static const lessonImpact = Duration(milliseconds: 510);

  static const unitReveal = Duration(milliseconds: 1400);
  static const unitImpact = Duration(milliseconds: 450);

  static const toastEntrance = Duration(milliseconds: 420);
  static const toastImpact = Duration(milliseconds: 120);

  static const starLeadAfterLessonImpact = Duration(milliseconds: 200);
  static const starStep = Duration(milliseconds: 380);

  static double progress(Duration moment, Duration total) =>
      moment.inMicroseconds / total.inMicroseconds;
}

/// A moment worth marking.
///
/// Sealed on purpose. Adding a celebration means the `switch` in [recipeFor]
/// stops compiling until its sound, haptic and timing are decided — so a new
/// achievement can never ship silently, which is exactly how the badge system
/// ended up awarding seven badges that nobody ever saw.
sealed class Celebration {
  const Celebration();

  /// Identity, used to drop duplicates.
  ///
  /// A widget rebuilding, a provider refreshing, or a completion committing
  /// twice would otherwise queue the same ceremony repeatedly and make the
  /// learner sit through it more than once.
  String get key;
}

/// A lesson finished. Fires 61 times over the course.
final class LessonCompleted extends Celebration {
  const LessonCompleted({
    required this.lessonId,
    required this.xp,
    required this.correct,
    required this.total,
  });

  final int lessonId;
  final int xp;
  final int correct;
  final int total;

  bool get isPerfect => total > 0 && correct == total;

  /// Kept as plain arithmetic so this stays free of any domain import; the
  /// grade bands themselves live in `LessonRating`.
  double get accuracy => total == 0 ? 0 : correct / total;

  @override
  String get key => 'lesson:$lessonId';
}

/// A unit finished. Fires 31 times — most units are only two lessons, so this
/// lands roughly every other lesson and cannot afford to be a long takeover.
/// It differs from a lesson by *character*, not by duration.
final class UnitCompleted extends Celebration {
  const UnitCompleted({
    required this.unitId,
    required this.unitNumber,
    required this.unitTitle,
    this.nextUnitTitle,
  });

  final int unitId;

  /// Position in the course, which is what the learner sees — not the row id.
  final int unitNumber;
  final String unitTitle;

  /// What this just opened up. Null at the end of a phase.
  final String? nextUnitTitle;

  /// Every fifth unit gets the biggest moment the app has. Six occurrences
  /// across the whole course is the right rarity for something that should
  /// feel like levelling up.
  bool get isMilestone => unitNumber % 5 == 0;

  @override
  String get key => 'unit:$unitId';
}

/// A badge was earned. Until now these were written to the database and never
/// shown, so the learner found out only by opening the Stats screen.
final class BadgeEarned extends Celebration {
  const BadgeEarned({
    required this.badgeId,
    required this.name,
    required this.icon,
    required this.xpReward,
  });

  final String badgeId;
  final String name;

  /// The badge's emoji, as declared in `Badge.all`.
  final String icon;
  final int xpReward;

  @override
  String get key => 'badge:$badgeId';
}

/// The daily streak advanced. Only marked at milestones — congratulating
/// someone for day 4 devalues day 7.
final class StreakExtended extends Celebration {
  const StreakExtended({required this.days});

  final int days;

  static const milestones = {3, 7, 14, 30, 50, 100, 365};

  static bool isMilestone(int days) => milestones.contains(days);

  @override
  String get key => 'streak:$days';
}

/// How a celebration sounds, feels, and how long it holds the screen.
class CelebrationRecipe {
  const CelebrationRecipe({
    required this.sound,
    required this.haptic,
    required this.visualImpactDelay,
    this.autoDismiss,
  });

  final Sfx sound;
  final Haptic haptic;

  /// Delay before the ceremony's main visual lands.
  ///
  /// Sound and haptics are scheduled against this moment by the host, rather
  /// than firing while the overlay is only beginning to enter.
  final Duration visualImpactDelay;

  /// How long before the next queued celebration takes over. Null means the
  /// learner dismisses it themselves — reserved for moments big enough that
  /// being hurried past them would undercut the point.
  final Duration? autoDismiss;
}

/// The whole feel of the app's rewards, as one table.
///
/// Tuning how a unit completion lands is a change here and nowhere else.
CelebrationRecipe recipeFor(Celebration celebration) => switch (celebration) {
  LessonCompleted(isPerfect: true) => const CelebrationRecipe(
    sound: Sfx.perfectLesson,
    haptic: Haptic.double,
    visualImpactDelay: CelebrationTimeline.lessonImpact,
    autoDismiss: Duration(milliseconds: 2600),
  ),
  LessonCompleted() => const CelebrationRecipe(
    sound: Sfx.lessonComplete,
    haptic: Haptic.medium,
    visualImpactDelay: CelebrationTimeline.lessonImpact,
    autoDismiss: Duration(milliseconds: 2200),
  ),
  UnitCompleted() => const CelebrationRecipe(
    sound: Sfx.unitComplete,
    haptic: Haptic.double,
    visualImpactDelay: CelebrationTimeline.unitImpact,
    // No auto-dismiss: this one is the payoff, and it names what was just
    // unlocked — sliding it away on a timer would waste both.
  ),
  BadgeEarned() => const CelebrationRecipe(
    sound: Sfx.badge,
    haptic: Haptic.light,
    visualImpactDelay: CelebrationTimeline.toastImpact,
    autoDismiss: Duration(milliseconds: 3400),
  ),
  StreakExtended() => const CelebrationRecipe(
    sound: Sfx.combo,
    haptic: Haptic.medium,
    visualImpactDelay: CelebrationTimeline.toastImpact,
    autoDismiss: Duration(milliseconds: 3000),
  ),
};
