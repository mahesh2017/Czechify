import 'dart:async';

import 'package:czechify/domain/entities/flashcard.dart';
import 'package:czechify/domain/entities/srs_card.dart';
import 'package:czechify/domain/repositories/vocabulary_repository.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/review_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rating waits for commit and repeated taps are ignored', () async {
    final repository = _ControlledVocabularyRepository();
    final container = ProviderContainer(
      overrides: [
        vocabularyRepositoryProvider.overrideWithValue(repository),
        reviewSessionProvider.overrideWith(_TestReviewNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(reviewSessionProvider.notifier);

    final pending = notifier.rateCard(Rating.again);
    await Future<void>.delayed(Duration.zero);

    var state = container.read(reviewSessionProvider);
    expect(state.isCommitting, isTrue);
    expect(state.currentIndex, 0);
    expect(repository.updateCalls, 1);

    await notifier.rateCard(Rating.easy);
    expect(repository.updateCalls, 1);

    repository.complete();
    await pending;

    state = container.read(reviewSessionProvider);
    expect(state.isCommitting, isFalse);
    expect(state.currentIndex, 1);
    expect(state.dueCards, hasLength(2));
    expect(state.dueCards.last.srs.state, CardState.relearning);
    expect(state.dueCards.last.srs.lastReview, isNotNull);
  });

  test('failed persistence keeps the current card retryable', () async {
    final repository = _ControlledVocabularyRepository(shouldFail: true);
    final container = ProviderContainer(
      overrides: [
        vocabularyRepositoryProvider.overrideWithValue(repository),
        reviewSessionProvider.overrideWith(_TestReviewNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(reviewSessionProvider.notifier).rateCard(Rating.good);

    final state = container.read(reviewSessionProvider);
    expect(state.currentIndex, 0);
    expect(state.reviewedCount, 0);
    expect(state.isFlipped, isTrue);
    expect(state.isCommitting, isFalse);
    expect(state.commitError, isNotNull);
  });
}

class _TestReviewNotifier extends ReviewSessionNotifier {
  @override
  ReviewSessionState build() => ReviewSessionState(
    isLoading: false,
    isFlipped: true,
    dueCards: [
      SessionCard(
        ReviewCard(
          flashcard: const Flashcard(id: 1, wordCz: 'pes', wordEn: 'dog'),
          srs: SrsCard(
            id: '10',
            cardType: CardType.vocabulary,
            due: DateTime.utc(2026, 7, 23),
            reps: 3,
            state: CardState.review,
            stability: 6,
            difficulty: 2.5,
          ),
        ),
        CardDirection.czToEn,
      ),
    ],
  );
}

class _ControlledVocabularyRepository implements VocabularyRepository {
  final bool shouldFail;
  final Completer<SrsCard> _completion = Completer<SrsCard>();
  SrsCard? _pendingCard;
  int updateCalls = 0;

  _ControlledVocabularyRepository({this.shouldFail = false});

  void complete() => _completion.complete(_pendingCard);

  @override
  Future<SrsCard> updateCard(
    SrsCard card,
    Rating rating,
    DateTime reviewedAt, {
    required String reviewId,
    required bool introducedNewCard,
  }) {
    updateCalls++;
    _pendingCard = card;
    if (shouldFail) return Future.error(StateError('write failed'));
    return _completion.future;
  }

  @override
  Future<bool> addManualCard({
    required String cz,
    required String en,
    String? ipa,
  }) => throw UnimplementedError();

  @override
  Future<List<ReviewCard>> getDueCards({DateTime? asOf}) =>
      throw UnimplementedError();

  @override
  Future<int> getDueCount({DateTime? asOf}) => throw UnimplementedError();

  @override
  Future<int> introducedCardCountForDay(DateTime day) =>
      throw UnimplementedError();

  @override
  Future<List<Flashcard>> getCardsForLesson(int lessonId) =>
      throw UnimplementedError();

  @override
  Future<List<Flashcard>> getCardsForUnit(int unitId) =>
      throw UnimplementedError();

  @override
  Future<List<Flashcard>> searchCards(String query) =>
      throw UnimplementedError();
}
