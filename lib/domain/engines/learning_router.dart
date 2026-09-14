import '../entities/learning_evidence.dart';

class LearningCandidate {
  final int lessonId;
  final int order;
  final bool completed;
  final bool isPreferredLevel;
  final Set<LearningSkill> skills;
  final Set<String> conceptKeys;

  const LearningCandidate({
    required this.lessonId,
    required this.order,
    required this.completed,
    this.isPreferredLevel = true,
    required this.skills,
    this.conceptKeys = const {},
  });
}

/// Why the router chose a lesson, so a screen can word it in the learner's
/// language instead of showing [LearningRoute.reason].
enum LearningRouteKind {
  delayedTransferRepair,
  independentRepair,
  supportRepair,
  maintain,
  newWork;

  /// The learner's own answers say this lesson needs another look.
  bool get isRepair =>
      this == delayedTransferRepair ||
      this == independentRepair ||
      this == supportRepair;
}

class LearningRoute {
  final int lessonId;
  final double priority;
  final String reason;
  final LearningRouteKind kind;

  const LearningRoute({
    required this.lessonId,
    required this.priority,
    required this.reason,
    this.kind = LearningRouteKind.newWork,
  });
}

/// Chooses next work from observable need. XP and streaks are intentionally
/// absent. Delayed novel-task failures outrank same-session performance.
class LearningRouter {
  const LearningRouter();

  LearningRoute? select({
    required List<LearningCandidate> candidates,
    required Set<int> accessibleLessonIds,
    required List<LearningEvidence> evidence,
  }) {
    // Only unfinished work at the preferred level holds the learner there.
    // Counting finished lessons stranded an A1 starter on completed A1 work
    // once A2 opened, because the starting level never changes.
    final hasPreferredLevel = candidates.any(
      (candidate) =>
          candidate.isPreferredLevel &&
          !candidate.completed &&
          accessibleLessonIds.contains(candidate.lessonId),
    );
    LearningRoute? best;
    for (final candidate in candidates) {
      if (!accessibleLessonIds.contains(candidate.lessonId)) continue;
      final relevant =
          evidence
              .where(
                (item) =>
                    item.lessonId == candidate.lessonId ||
                    item.conceptKeys.any(candidate.conceptKeys.contains),
              )
              .toList();
      // Placement chooses new work; evidence can still recommend revisiting
      // an earlier level. Merely unlocking A1 must not restart an A2 learner.
      if (hasPreferredLevel &&
          !candidate.isPreferredLevel &&
          relevant.isEmpty) {
        continue;
      }
      // Only the most recent attempt at each exercise counts, because these
      // scores are meant to describe what the learner is weak at *now*.
      //
      // Evidence is append-only, so counting the whole history made a mistake
      // permanent: two wrong answers in lesson 1 scored it above an untouched
      // lesson 2 for ever, and passing lesson 1 again could not undo it — a
      // later success adds a row but removes nothing. Home's "continue
      // learning" then pointed at the same finished lesson every time, which
      // is where this was noticed.
      final current = <Object, LearningEvidence>{};
      for (final item in relevant) {
        // Exercise-level where we have it; whole-lesson evidence groups under
        // the lesson so one stale row cannot outvote a later one.
        final key = item.exerciseId ?? 'lesson:${item.lessonId}';
        final held = current[key];
        if (held == null || item.observedAt.isAfter(held.observedAt)) {
          current[key] = item;
        }
      }
      final latest = current.values;
      final delayed = latest.where((item) => item.isDelayedTransfer).toList();
      final independent = latest.where((item) => item.independent).toList();
      final supportCount = latest.where((item) => !item.independent).length;
      final failures = independent.where((item) => !item.correct).length;
      final delayedFailures = delayed.where((item) => !item.correct).length;

      var priority = candidate.completed ? 0.0 : 12.0;
      priority += delayedFailures * 100;
      priority += failures * 12;
      priority += supportCount * 5;
      if (relevant.isEmpty) priority += 6;
      priority -= candidate.order / 1000;

      final kind =
          delayedFailures > 0
              ? LearningRouteKind.delayedTransferRepair
              : failures > 0
              ? LearningRouteKind.independentRepair
              : supportCount > 0
              ? LearningRouteKind.supportRepair
              : candidate.completed
              ? LearningRouteKind.maintain
              : LearningRouteKind.newWork;
      final reason = switch (kind) {
        LearningRouteKind.delayedTransferRepair =>
          'Delayed transfer needs repair',
        LearningRouteKind.independentRepair =>
          'Independent practice needs reinforcement',
        LearningRouteKind.supportRepair => 'Reduce support dependence',
        LearningRouteKind.maintain => 'Maintain retained performance',
        LearningRouteKind.newWork => 'Continue with new accessible work',
      };
      if (best == null || priority > best.priority) {
        best = LearningRoute(
          lessonId: candidate.lessonId,
          priority: priority,
          reason: reason,
          kind: kind,
        );
      }
    }
    return best;
  }
}
