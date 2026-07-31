import 'package:flutter_test/flutter_test.dart';
import 'package:ceskina_pro/domain/entities/flashcard.dart';
import 'package:ceskina_pro/domain/entities/srs_card.dart';
import 'package:ceskina_pro/domain/repositories/vocabulary_repository.dart';
import 'package:ceskina_pro/presentation/providers/review_providers.dart';

void main() {
  final now = DateTime(2026, 7, 18);

  ReviewCard newCard(int id, {int? unitId, int? lessonId}) => ReviewCard(
    flashcard: Flashcard(
      id: id,
      wordCz: 'cz$id',
      wordEn: 'en$id',
      unitId: unitId,
      lessonId: lessonId,
    ),
    srs: SrsCard(id: '$id', cardType: CardType.vocabulary, due: now),
  );

  ReviewCard reviewCard(int id, {int? unitId}) => ReviewCard(
    flashcard: Flashcard(
      id: id,
      wordCz: 'cz$id',
      wordEn: 'en$id',
      unitId: unitId,
    ),
    srs: SrsCard(
      id: '$id',
      cardType: CardType.vocabulary,
      due: now,
      reps: 3,
      state: CardState.review,
    ),
  );

  group('planReviewSession', () {
    test('new cards for locked units are excluded', () {
      final plan = planReviewSession(
        allDue: [newCard(1, unitId: 1), newCard(2, unitId: 99)],
        unlockedUnits: {1},
        introducedToday: 0,
      );
      expect(plan.newCount, 1);
      expect(plan.cards.single.flashcard.id, 1);
    });

    test('cards with no unit are always introducible', () {
      final plan = planReviewSession(
        allDue: [newCard(1)],
        unlockedUnits: const {},
        introducedToday: 0,
      );
      expect(plan.newCount, 1);
    });

    test('lesson-gated word waits until its lesson is completed', () {
      final cards = [newCard(1, unitId: 1, lessonId: 101)];
      // Unit unlocked but lesson not yet completed → not introducible.
      final locked = planReviewSession(
        allDue: cards,
        unlockedUnits: {1},
        introducedToday: 0,
      );
      expect(locked.newCount, 0);

      // Lesson completed → introducible.
      final unlocked = planReviewSession(
        allDue: cards,
        unlockedUnits: {1},
        completedLessons: {101},
        introducedToday: 0,
      );
      expect(unlocked.newCount, 1);
    });

    test('daily new-card budget is respected', () {
      final cards = List.generate(30, (i) => newCard(i, unitId: 1));
      final plan = planReviewSession(
        allDue: cards,
        unlockedUnits: {1},
        introducedToday: kDailyNewCardLimit - 3,
      );
      expect(plan.newCount, 3);
    });

    test('already-introduced today caps new cards to zero', () {
      final plan = planReviewSession(
        allDue: [newCard(1, unitId: 1)],
        unlockedUnits: {1},
        introducedToday: kDailyNewCardLimit,
      );
      expect(plan.newCount, 0);
      expect(plan.cards, isEmpty);
    });

    test('review cards always show and come before new cards', () {
      final plan = planReviewSession(
        allDue: [newCard(1, unitId: 1), reviewCard(2, unitId: 1)],
        unlockedUnits: {1},
        introducedToday: 0,
      );
      expect(plan.cards.first.flashcard.id, 2); // review first
      expect(plan.cards.length, 2);
    });

    test('total session is capped', () {
      final reviews = List.generate(40, (i) => reviewCard(i, unitId: 1));
      final plan = planReviewSession(
        allDue: reviews,
        unlockedUnits: {1},
        introducedToday: 0,
      );
      expect(plan.cards.length, kMaxSessionCards);
    });

    test('new cards are always shown Czech-first (recognition)', () {
      final plan = planReviewSession(
        allDue: [newCard(1, unitId: 1)],
        unlockedUnits: {1},
        introducedToday: 0,
      );
      expect(plan.cards.single.direction, CardDirection.czToEn);
    });

    test('mature cards mix in production and audio directions', () {
      final reviews = List.generate(9, (i) => reviewCard(i, unitId: 1));
      final plan = planReviewSession(
        allDue: reviews,
        unlockedUnits: {1},
        introducedToday: 0,
      );
      final directions = plan.cards.map((c) => c.direction).toSet();
      expect(directions, containsAll(CardDirection.values));
    });
  });
}
