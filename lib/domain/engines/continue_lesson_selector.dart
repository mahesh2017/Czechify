/// A lesson in the course, as [ContinueLessonSelector] needs to see it.
class ContinueLessonCandidate {
  final int lessonId;

  /// Whether the lesson belongs to the level the learner chose to start at.
  final bool isPreferredLevel;

  const ContinueLessonCandidate({
    required this.lessonId,
    this.isPreferredLevel = true,
  });
}

/// Picks the lesson that continues from where the learner last finished.
///
/// This is the course read in order — the lesson after the most recently
/// completed one — rather than the evidence-weighted recommendation Home
/// makes, which can send a learner back to repair earlier work. Daily Arrival
/// greets the learner with this so that "continue" means continue.
class ContinueLessonSelector {
  const ContinueLessonSelector();

  /// [lessons] is the whole course in teaching order. [completedAt] holds
  /// every finished lesson with when it was last finished; a null time counts
  /// as older than any recorded one.
  ///
  /// Returns null only when no unlocked lesson is left unfinished.
  int? select({
    required List<ContinueLessonCandidate> lessons,
    required Set<int> unlockedLessonIds,
    required Map<int, DateTime?> completedAt,
  }) {
    int? firstOpen(Iterable<ContinueLessonCandidate> from) {
      for (final lesson in from) {
        if (unlockedLessonIds.contains(lesson.lessonId) &&
            !completedAt.containsKey(lesson.lessonId)) {
          return lesson.lessonId;
        }
      }
      return null;
    }

    // The most recently finished lesson. Equal times — including two with
    // none recorded — go to the one further along the course.
    var lastIndex = -1;
    DateTime? lastAt;
    for (var i = 0; i < lessons.length; i++) {
      final id = lessons[i].lessonId;
      if (!completedAt.containsKey(id)) continue;
      final at = completedAt[id];
      final newer =
          lastIndex == -1 ||
          (at == null ? lastAt == null : lastAt == null || !at.isBefore(lastAt));
      if (newer) {
        lastIndex = i;
        lastAt = at;
      }
    }

    if (lastIndex == -1) {
      // Nothing finished yet: start at the level chosen in onboarding.
      return firstOpen(lessons.where((lesson) => lesson.isPreferredLevel)) ??
          firstOpen(lessons);
    }
    // Lessons after it may already be done (a replayed earlier lesson is the
    // most recent), so walk on to the first one that is not. If everything
    // after it is finished, pick up the earliest gap.
    return firstOpen(lessons.skip(lastIndex + 1)) ?? firstOpen(lessons);
  }
}
