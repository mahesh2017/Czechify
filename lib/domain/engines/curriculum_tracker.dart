import '../entities/enums.dart';

/// Tracks curriculum progress and determines CEFR level.
class CurriculumProgressTracker {
  /// A unit counts as "mastered" at this average lesson score.
  ///
  /// The average is over *every* lesson in the unit, not just the attempted
  /// ones — DriftProgressRepository divides the score sum by the unit's total
  /// lesson count. So acing one lesson of four scores 0.24, not 0.95, and a
  /// unit cannot be mastered by cherry-picking the easy lesson in it. Reaching
  /// 0.6 means finishing essentially the whole unit at a passing standard.
  static const masteryThreshold = 0.6;

  /// Determine if a lesson is unlocked (previous lesson completed).
  bool isLessonUnlocked({
    required int lessonOrder,
    required Set<int> completedLessonIds,
    required Map<int, int> lessonIdByOrder,
  }) {
    if (lessonOrder == 0) return true;
    final prevId = lessonIdByOrder[lessonOrder - 1];
    if (prevId == null) return true;
    return completedLessonIds.contains(prevId);
  }

  /// Calculate unit completion percentage.
  double unitCompletion({
    required int unitId,
    required Map<int, Set<int>> completedLessonsByUnit,
    required int totalLessonsInUnit,
  }) {
    if (totalLessonsInUnit == 0) return 0.0;
    final completed = completedLessonsByUnit[unitId]?.length ?? 0;
    return completed / totalLessonsInUnit;
  }

  /// Completion rate for one phase: the fraction of that phase's units
  /// (ALL of them, not just attempted ones) mastered at [masteryThreshold].
  double phaseCompletion({
    required Map<int, double> unitScores,
    required Set<int> phaseUnitIds,
  }) {
    if (phaseUnitIds.isEmpty) return 0.0;
    final mastered =
        phaseUnitIds
            .where((id) => (unitScores[id] ?? 0.0) >= masteryThreshold)
            .length;
    return mastered / phaseUnitIds.length;
  }

  /// Fraction of required lessons completed across the whole phase.
  double phaseLessonCoverage({
    required Map<int, int> completedLessonsByUnit,
    required Map<int, int> totalLessonsByUnit,
    required Set<int> phaseUnitIds,
  }) {
    final required = phaseUnitIds.fold<int>(
      0,
      (sum, id) => sum + (totalLessonsByUnit[id] ?? 0),
    );
    if (required == 0) return 0;
    final completed = phaseUnitIds.fold<int>(
      0,
      (sum, id) => sum + (completedLessonsByUnit[id] ?? 0),
    );
    return (completed / required).clamp(0.0, 1.0);
  }

  /// Determine CEFR level estimate from phase completion + passed exams.
  CEFRLevel estimateLevel({
    required double a1Completion,
    required double a2Completion,
    required Set<String> examsPassed,
  }) {
    if (a2Completion > 0.8 && examsPassed.contains('a2')) {
      return CEFRLevel.a2;
    }
    if (a1Completion > 0.8 && examsPassed.contains('a1')) {
      return CEFRLevel.a1;
    }
    return CEFRLevel.preA1;
  }
}
