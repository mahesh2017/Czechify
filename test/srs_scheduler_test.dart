import 'package:flutter_test/flutter_test.dart';
import 'package:ceskina_pro/domain/entities/srs_card.dart';
import 'package:ceskina_pro/domain/engines/srs_scheduler.dart';

/// The scheduler's own ease floor; the ordering sweep starts here.
const _minEase = 1.3;

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
      expect(result.nextReviewDate, now.add(SrsScheduler.relearningStep));
    });

    test('a failed card comes back today, not tomorrow', () {
      // Whole-day intervals gave Again a floor of the next calendar day. The
      // review screen requeues it in-session, but that queue dies with the
      // session: closing the app on a word you just blanked on used to put it
      // out of reach until tomorrow.
      final card = newCard().copyWith(reps: 3, stability: 10, difficulty: 2.5);
      final result = scheduler.schedule(card, Rating.again, now);

      expect(result.nextReviewDate.difference(now), lessThan(const Duration(hours: 1)));
      expect(result.nextReviewDate.isAfter(now), isTrue);
    });

    test('a lapse does not collapse the interval it rebuilds from', () {
      // The trap in scheduling minutes: stability doubles as "the interval to
      // multiply next time". Recording ten minutes there would leave the next
      // success scheduling the card 0.02 days out.
      final lapsed =
          scheduler
              .schedule(
                newCard().copyWith(reps: 3, stability: 30, difficulty: 2.5),
                Rating.again,
                now,
              )
              .card;

      expect(lapsed.stability, 1.0, reason: 'a day, not ten minutes');

      // Answering it correctly puts it back on the normal ladder.
      final recovered = scheduler.schedule(lapsed, Rating.good, now);
      expect(recovered.nextReviewDate, now.add(const Duration(days: 1)));
    });

    test('a relearning card is not due until its step has elapsed', () {
      final lapsed =
          scheduler
              .schedule(
                newCard().copyWith(reps: 3, stability: 10, difficulty: 2.5),
                Rating.again,
                now,
              )
              .card;

      expect(
        scheduler.getDueCards([lapsed], now),
        isEmpty,
        reason: 'it would otherwise be handed straight back',
      );
      expect(
        scheduler.getDueCards([lapsed], now.add(SrsScheduler.relearningStep)),
        hasLength(1),
      );
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

    test('early reviews record ease instead of discarding it', () {
      // Ease used to move only from the third review onwards, so how a word
      // felt when the learner first met it — their clearest signal about it —
      // was thrown away.
      final easy = scheduler.schedule(newCard(), Rating.easy, now).card;
      final hard = scheduler.schedule(newCard(), Rating.hard, now).card;

      expect(easy.difficulty, greaterThan(hard.difficulty));
      expect(easy.difficulty, closeTo(2.65, 0.01));
      expect(hard.difficulty, closeTo(2.35, 0.01));
    });

    test('early ease separates the schedules once multiplying begins', () {
      // Both cards are put on an identical interval history, so the ONLY thing
      // that can differ is the ease recorded at the first review. Under the old
      // behaviour both arrived here at 2.5 and were scheduled identically from
      // then on, however differently the learner had answered.
      final easy = scheduler
          .schedule(newCard(), Rating.easy, now)
          .card
          .copyWith(reps: 2, stability: 6);
      final hard = scheduler
          .schedule(newCard(), Rating.hard, now)
          .card
          .copyWith(reps: 2, stability: 6);

      final easyNext = scheduler.schedule(easy, Rating.good, now);
      final hardNext = scheduler.schedule(hard, Rating.good, now);

      expect(
        easyNext.nextReviewDate.isAfter(hardNext.nextReviewDate),
        isTrue,
        reason: 'the confidently-known word should come back later',
      );
    });

    test('fixed learning steps survive the ease change', () {
      // Ease must not start multiplying before the card has been seen twice,
      // or one confident first answer schedules a brand-new word weeks out.
      expect(
        scheduler.schedule(newCard(), Rating.easy, now).card.stability,
        4,
      );
      expect(
        scheduler
            .schedule(newCard().copyWith(reps: 1), Rating.good, now)
            .card
            .stability,
        6,
      );
    });

    test('the four buttons schedule four different things', () {
      // Hard used to be Good with 0.15 less ease: a 30-day card came back in
      // 70 days instead of 75. Four buttons, two outcomes.
      final card = newCard().copyWith(reps: 3, stability: 30, difficulty: 2.5);

      final days = {
        for (final rating in Rating.values)
          rating: scheduler.previewIntervalDays(card, rating, now),
      };

      // Again is measured in minutes now, so it rounds to zero days rather
      // than the one day it used to floor at.
      expect(
        scheduler.previewInterval(card, Rating.again, now),
        SrsScheduler.relearningStep,
      );
      expect(days[Rating.again], 0);
      expect(days[Rating.hard], 36, reason: 'a cautious step, not a leap');
      expect(days[Rating.good], 75);
      expect(days[Rating.easy], 103);
      expect(days.values.toSet(), hasLength(4));
    });

    test('hard stays short of good, and easy beyond it, at any ease', () {
      // The ordering has to survive the whole legal ease range, including the
      // 1.3 floor where hard's fixed 1.2 multiplier comes closest to good's.
      for (var ease = _minEase; ease <= 3.0; ease += 0.1) {
        for (final stability in const [1.0, 6.0, 30.0, 200.0]) {
          final card = newCard().copyWith(
            reps: 3,
            stability: stability,
            difficulty: ease,
          );
          final hard = scheduler.previewIntervalDays(card, Rating.hard, now);
          final good = scheduler.previewIntervalDays(card, Rating.good, now);
          final easy = scheduler.previewIntervalDays(card, Rating.easy, now);

          final at = 'ease $ease, stability $stability';
          expect(hard, lessThanOrEqualTo(good), reason: 'hard <= good at $at');
          expect(good, lessThanOrEqualTo(easy), reason: 'good <= easy at $at');
        }
      }
    });

    test('a struggled card grows slowly instead of doubling', () {
      // Repeated Hard should keep a shaky word close, not walk it out to a
      // month because the multiplier barely moved.
      var card = newCard().copyWith(reps: 3, stability: 10, difficulty: 2.5);
      for (var i = 0; i < 3; i++) {
        card = scheduler.schedule(card, Rating.hard, now).card;
      }

      expect(
        card.stability,
        lessThan(20),
        reason: 'three struggles should not have doubled the interval',
      );
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
