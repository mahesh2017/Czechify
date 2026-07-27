import '../entities/lesson.dart';
import '../entities/unit.dart';

/// A unit the learner has just finished.
class UnitMilestone {
  const UnitMilestone({
    required this.unitId,
    required this.number,
    required this.title,
    this.nextTitle,
  });

  final int unitId;

  /// Position within its phase, counting from one. This is what the learner
  /// sees on the curriculum screen; the row id is an implementation detail
  /// they have never been shown.
  final int number;

  final String title;

  /// The unit this one just opened, or null at the end of a phase.
  final String? nextTitle;
}

/// Works out whether a committed lesson finished its unit.
///
/// Nothing in the app asked this question before. Units were only ever read
/// backwards — "which are unlocked" — so the moment a learner finished one
/// went by with no acknowledgement at all.
class UnitCompletionDetector {
  const UnitCompletionDetector();

  /// [completedBefore] is the completion set from before this attempt was
  /// recorded, and it is the whole reason this is not a one-line check:
  /// replaying the last lesson of a finished unit leaves every lesson
  /// complete exactly as finishing it for the first time does.
  UnitMilestone? evaluate({
    required Lesson lesson,
    required Unit unit,
    required List<Lesson> unitLessons,
    required List<Unit> phaseUnits,
    required Set<int> completedBefore,
    required Set<int> completedNow,
  }) {
    if (completedBefore.contains(lesson.id)) return null;
    if (unitLessons.isEmpty) return null;
    if (!unitLessons.every((l) => completedNow.contains(l.id))) return null;

    final ordered = [...phaseUnits]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final index = ordered.indexWhere((u) => u.id == unit.id);

    return UnitMilestone(
      unitId: unit.id,
      number: index >= 0 ? index + 1 : unit.orderIndex,
      title: unit.title,
      nextTitle:
          index >= 0 && index + 1 < ordered.length
              ? ordered[index + 1].title
              : null,
    );
  }
}
