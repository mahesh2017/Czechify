import '../entities/lesson.dart';
import '../entities/unit.dart';

/// A curriculum access graph derived only from declared curriculum order and
/// committed lesson completion. Engagement rewards such as XP are not inputs.
class CurriculumAccess {
  final Set<int> unlockedUnitIds;
  final Set<int> unlockedLessonIds;
  final Map<int, Set<int>> lessonPrerequisites;

  const CurriculumAccess({
    required this.unlockedUnitIds,
    required this.unlockedLessonIds,
    required this.lessonPrerequisites,
  });
}

class CurriculumAccessPolicy {
  const CurriculumAccessPolicy();

  CurriculumAccess evaluate({
    required List<Unit> orderedUnits,
    required Map<int, List<Lesson>> lessonsByUnit,
    required Set<int> completedLessonIds,
    int? provisionalThroughUnitId,
    bool unlockAll = false,
  }) {
    final units = [...orderedUnits]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final unlockedUnits = <int>{};
    final unlockedLessons = <int>{};
    final prerequisites = <int, Set<int>>{};
    final earlierRequiredLessons = <int>{};
    int? provisionalOrder;
    if (provisionalThroughUnitId != null) {
      for (final unit in units) {
        if (unit.id == provisionalThroughUnitId) {
          provisionalOrder = unit.orderIndex;
          break;
        }
      }
    }

    for (final unit in units) {
      final lessons = [...(lessonsByUnit[unit.id] ?? const <Lesson>[])]
        ..sort((a, b) => a.orderInUnit.compareTo(b.orderInUnit));
      final provisionallyUnlocked =
          provisionalOrder != null && unit.orderIndex <= provisionalOrder;
      final unitUnlocked =
          unlockAll ||
          provisionallyUnlocked ||
          earlierRequiredLessons.every(completedLessonIds.contains);
      if (unitUnlocked) unlockedUnits.add(unit.id);

      final earlierInUnit = <int>{};
      for (final lesson in lessons) {
        final required = {
          if (!provisionallyUnlocked) ...earlierRequiredLessons,
          ...earlierInUnit,
        };
        prerequisites[lesson.id] = Set.unmodifiable(required);
        if (unlockAll || required.every(completedLessonIds.contains)) {
          unlockedLessons.add(lesson.id);
        }
        earlierInUnit.add(lesson.id);
      }
      earlierRequiredLessons.addAll(lessons.map((lesson) => lesson.id));
    }

    return CurriculumAccess(
      unlockedUnitIds: Set.unmodifiable(unlockedUnits),
      unlockedLessonIds: Set.unmodifiable(unlockedLessons),
      lessonPrerequisites: Map.unmodifiable(prerequisites),
    );
  }
}
