import 'package:flutter_test/flutter_test.dart';
import 'package:ceskina_pro/domain/entities/srs_card.dart';
import 'package:ceskina_pro/domain/engines/srs_scheduler.dart';

void main() {
  group('SrsScheduler', () {
    final scheduler = SrsScheduler();
    final now = DateTime(2026, 7, 16, 12, 0);

    SrsCard newCard() =>
        SrsCard(id: '1', cardType: CardType.vocabulary, due: now);

    test('Rating "again" resets reps to 0 and sets relearning state', () {
      final card = newCard().copyWith(reps: 3, stability: 10, difficulty: 2.5);
      final result = scheduler.schedule(card, Rating.again, now);

      expect(result.card.reps, 0);
      expect(result.card.state, CardState.relearning);
      expect(result.nextReviewDate, now.add(const Duration(days: 1)));
    });

    test('First review with "good" sets interval to 1 day', () {
      final card = newCard(); // reps = 0
      final result = scheduler.schedule(card, Rating.good, now);

      expect(result.card.reps, 1);
      expect(result.card.state, CardState.review);
      expect(result.nextReviewDate, now.add(const Duration(days: 1)));
    });

    test('First review with "easy" sets interval to 4 days', () {
      final card = newCard();
      final result = scheduler.schedule(card, Rating.easy, now);

      expect(result.card.reps, 1);
      expect(result.nextReviewDate, now.add(const Duration(days: 4)));
    });

    test('Second review with "good" sets interval to 6 days', () {
      final card = newCard().copyWith(reps: 1);
      final result = scheduler.schedule(card, Rating.good, now);

      expect(result.card.reps, 2);
      expect(result.nextReviewDate, now.add(const Duration(days: 6)));
    });

    test('Ease factor accumulates across reviews (not reset to 2.5)', () {
      // After 2 reviews, the card has some ease. A "hard" should decrease it
      // but not reset to 2.5.
      final card = newCard().copyWith(reps: 2, stability: 6, difficulty: 2.5);

      // Rate "hard" — ease should decrease from 2.5 by 0.15
      final result = scheduler.schedule(card, Rating.hard, now);
      expect(result.card.difficulty, closeTo(2.35, 0.01));

      // Rate "easy" next — ease should increase from 2.35 by 0.15
      final result2 = scheduler.schedule(result.card, Rating.easy, now);
      expect(result2.card.difficulty, closeTo(2.5, 0.01));
    });

    test('Ease factor is clamped to minimum 1.3', () {
      final card = newCard().copyWith(
        reps: 5,
        stability: 10,
        difficulty: 1.4, // close to minimum
      );

      // Multiple "again" ratings should not drop ease below 1.3
      final result = scheduler.schedule(card, Rating.again, now);
      expect(result.card.difficulty, greaterThanOrEqualTo(1.3));
    });

    test('Interval is clamped to max 365 days', () {
      final card = newCard().copyWith(
        reps: 10,
        stability: 200,
        difficulty: 2.5,
      );

      final result = scheduler.schedule(card, Rating.easy, now);
      expect(
        result.nextReviewDate.difference(now).inDays,
        lessThanOrEqualTo(365),
      );
    });

    test('getDueCards returns cards due on or before the reference date', () {
      final cards = [
        SrsCard(
          id: '1',
          cardType: CardType.vocabulary,
          due: now.subtract(const Duration(days: 1)),
        ),
        SrsCard(id: '2', cardType: CardType.vocabulary, due: now),
        SrsCard(
          id: '3',
          cardType: CardType.vocabulary,
          due: now.add(const Duration(days: 1)),
        ),
      ];

      final due = scheduler.getDueCards(cards, now);
      expect(due.length, 2);
      expect(due.map((c) => c.id).toList(), containsAll(['1', '2']));
    });

    test('previewIntervalDays matches the interval schedule() would apply', () {
      final card = newCard().copyWith(reps: 2, stability: 8, difficulty: 2.5);
      for (final rating in Rating.values) {
        final preview = scheduler.previewIntervalDays(card, rating, now);
        final scheduled = scheduler.schedule(card, rating, now).nextReviewDate;
        expect(preview, scheduled.difference(now).inDays);
      }
    });

    test('previewIntervalDays does not mutate the input card', () {
      final card = newCard().copyWith(reps: 2, stability: 8, difficulty: 2.5);
      scheduler.previewIntervalDays(card, Rating.easy, now);
      expect(card.reps, 2);
      expect(card.stability, 8);
    });
  });
}
