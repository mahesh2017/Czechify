import '../entities/lesson.dart';
import '../entities/enums.dart';
import '../entities/unit.dart';

/// A placement waives earlier-unit prerequisites in exactly one phase.
class CurriculumPlacement {
  final Phase phase;
  final int throughUnitId;

  const CurriculumPlacement({required this.phase, required this.throughUnitId});
}

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
    Iterable<CurriculumPlacement> placements = const [],
    // Compatibility for existing scalar placement rows. New callers should
    // supply phase-specific placements. Preserve the already-open span when
    // reading old profiles until their durable migration has shipped.
    int? provisionalThroughUnitId,
    bool unlockAll = false,
  }) {
    final units = [...orderedUnits]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final unlockedUnits = <int>{};
    final unlockedLessons = <int>{};
    final prerequisites = <int, Set<int>>{};
    final earlierLessonsByPhase = <Phase, Set<int>>{};
    final provisionalOrders = <Phase, int>{};
    for (final placement in placements) {
      final matching = units.where(
        (unit) =>
            unit.id == placement.throughUnitId && unit.phase == placement.phase,
      );
      if (matching.isEmpty) continue;
      final order = matching.first.orderIndex;
      final previous = provisionalOrders[placement.phase];
      if (previous == null || order > previous) {
        provisionalOrders[placement.phase] = order;
      }
    }
    if (provisionalThroughUnitId != null) {
      final legacyTargets = units.where(
        (u) => u.id == provisionalThroughUnitId,
      );
      if (legacyTargets.isNotEmpty) {
        final legacyOrder = legacyTargets.first.orderIndex;
        for (final unit in units.where((u) => u.orderIndex <= legacyOrder)) {
          final previous = provisionalOrders[unit.phase];
          if (previous == null || unit.orderIndex > previous) {
            provisionalOrders[unit.phase] = unit.orderIndex;
          }
        }
      }
    }

    for (final unit in units) {
      final earlierRequiredLessons = earlierLessonsByPhase.putIfAbsent(
        unit.phase,
        () => <int>{},
      );
      final lessons = [...(lessonsByUnit[unit.id] ?? const <Lesson>[])]
        ..sort((a, b) => a.orderInUnit.compareTo(b.orderInUnit));
      final provisionalOrder = provisionalOrders[unit.phase];
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
