import '../entities/learning_evidence.dart';

class LearningCandidate {
  final int lessonId;
  final int order;
  final bool completed;
  final Set<LearningSkill> skills;
  final Set<String> conceptKeys;

  const LearningCandidate({
    required this.lessonId,
    required this.order,
    required this.completed,
    required this.skills,
    this.conceptKeys = const {},
  });
}

class LearningRoute {
  final int lessonId;
  final double priority;
  final String reason;

  const LearningRoute({
    required this.lessonId,
    required this.priority,
    required this.reason,
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

      final reason =
          delayedFailures > 0
              ? 'Delayed transfer needs repair'
              : failures > 0
              ? 'Independent practice needs reinforcement'
              : supportCount > 0
              ? 'Reduce support dependence'
              : candidate.completed
              ? 'Maintain retained performance'
              : 'Continue with new accessible work';
      if (best == null || priority > best.priority) {
        best = LearningRoute(
          lessonId: candidate.lessonId,
          priority: priority,
          reason: reason,
        );
      }
    }
    return best;
  }
}
