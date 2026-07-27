import '../entities/srs_card.dart';

/// Result of scheduling a card review.
class SchedulingResult {
  final SrsCard card;
  final DateTime nextReviewDate;

  const SchedulingResult({required this.card, required this.nextReviewDate});
}

/// Spaced repetition scheduler using the SM-2 algorithm.
///
/// This is a simplified SM-2 implementation (ease factor, interval
/// multiplication). It is **not** FSRS — the Free Spaced Repetition Scheduler
/// uses a different parameter space (w-matrix, retrievability, stability).
///
/// The public API is designed so a future migration to real FSRS can replace
/// this class without touching callers. When that happens, a one-time data
/// migration will be needed to convert stored SM-2 state to FSRS parameters.
class SrsScheduler {
  // SM-2 parameters.
  static const double _initialEaseFactor = 2.5;
  static const double _minEaseFactor = 1.3;

  /// Calculate the next review date and update card state.
  SchedulingResult schedule(SrsCard card, Rating rating, DateTime now) {
    // SM-2 implementation.
    var newReps = card.reps + 1;
    // Use the card's existing difficulty (ease factor) instead of always resetting to 2.5
    var newEase = card.difficulty > 0 ? card.difficulty : _initialEaseFactor;
    var interval = 1;

    if (rating == Rating.again) {
      newReps = 0;
      interval = 1;
      newEase = (newEase - 0.2).clamp(_minEaseFactor, 3.0);
    } else if (card.reps == 0) {
      interval = switch (rating) {
        Rating.hard => 1,
        Rating.good => 1,
        Rating.easy => 4,
        Rating.again => 1,
      };
    } else if (card.reps == 1) {
      interval = switch (rating) {
        Rating.hard => 3,
        Rating.good => 6,
        Rating.easy => 8,
        Rating.again => 1,
      };
    } else {
      final easeAdjustment = switch (rating) {
        Rating.again => -0.2,
        Rating.hard => -0.15,
        Rating.good => 0.0,
        Rating.easy => 0.15,
      };
      // Accumulate ease from the card's stored value, not from the constant
      newEase = (newEase + easeAdjustment).clamp(_minEaseFactor, 3.0);
      interval = (card.stability * newEase).round();
      interval = interval.clamp(1, 365);
    }

    final newDifficulty = newEase;
    final newDue = now.add(Duration(days: interval));
    final newState = switch (rating) {
      Rating.again => CardState.relearning,
      Rating.hard => CardState.review,
      Rating.good => CardState.review,
      Rating.easy => CardState.review,
    };

    final updatedCard = card.copyWith(
      stability: interval.toDouble(),
      difficulty: newDifficulty,
      due: newDue,
      reps: newReps,
      state: newState,
      lastReview: now,
    );

    return SchedulingResult(card: updatedCard, nextReviewDate: newDue);
  }

  /// Preview the interval (in whole days) a given rating would schedule,
  /// without mutating the card. Used to show honest interval hints on the
  /// rating buttons instead of hardcoded values.
  int previewIntervalDays(SrsCard card, Rating rating, DateTime now) {
    final result = schedule(card, rating, now);
    return result.nextReviewDate.difference(now).inDays;
  }

  /// Get all cards due for review on or before [asOf].
  List<SrsCard> getDueCards(List<SrsCard> allCards, DateTime asOf) {
    return allCards
        .where((c) => c.due.isBefore(asOf) || c.due.isAtSameMomentAs(asOf))
        .toList();
  }
}
