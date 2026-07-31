import '../../domain/entities/lesson.dart';
import '../../domain/entities/unit.dart';
import '../../l10n/app_localizations.dart';

enum CurriculumPathState { completed, current, available, locked }

/// Presentation-only curriculum model. Layout metadata stays out of the
/// authoritative curriculum entities and JSON contracts.
class CurriculumPathItem {
  const CurriculumPathItem({
    required this.unit,
    required this.lessons,
    required this.state,
    required this.section,
    required this.payoff,
    required this.durationMinutes,
    this.recommendation,
  });

  final Unit unit;
  final List<Lesson> lessons;
  final CurriculumPathState state;
  final String section;
  final String payoff;
  final int durationMinutes;
  final String? recommendation;

  static String sectionFor(
    Unit unit,
    int indexInLevel,
    int levelCount,
    AppLocalizations l10n,
  ) {
    if (unit.isExamPrep || indexInLevel >= levelCount - 2) {
      return l10n.pathExamConsolidation(unit.phase.name.toUpperCase());
    }
    final midpoint = (levelCount / 2).ceil();
    if (unit.phase.name == 'a1') {
      return indexInLevel < midpoint
          ? l10n.pathA1Foundations
          : l10n.pathA1Everyday;
    }
    return indexInLevel < midpoint ? l10n.pathA2Grammar : l10n.pathA2RealLife;
  }

  static String payoffFor(Unit unit, AppLocalizations l10n) {
    final description = unit.description.trim();
    if (description.isEmpty) return l10n.pathFallbackPayoff;
    return description.endsWith('.') ? description : '$description.';
  }
}
