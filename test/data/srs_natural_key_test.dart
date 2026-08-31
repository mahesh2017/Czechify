import 'dart:io';

import 'package:czechify/data/database/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('vocabulary SRS upsert is atomic on its natural key', () async {
    await database
        .into(database.flashcards)
        .insert(
          FlashcardsCompanion.insert(
            id: const Value(1),
            wordCz: 'pes',
            wordEn: 'dog',
          ),
        );

    await database.vocabularyDao.upsertSrsCard(
      SrsCardsCompanion.insert(
        cardType: 'vocabulary',
        flashcardId: const Value(1),
        reps: const Value(0),
        due: Value(DateTime.utc(2026, 7, 23)),
      ),
    );
    await database.vocabularyDao.upsertSrsCard(
      SrsCardsCompanion.insert(
        cardType: 'vocabulary',
        flashcardId: const Value(1),
        reps: const Value(4),
        due: Value(DateTime.utc(2026, 8, 1)),
      ),
    );

    final rows = await database.select(database.srsCards).get();
    expect(rows, hasLength(1));
    expect(rows.single.flashcardId, 1);
    expect(rows.single.reps, 4);
    expect(rows.single.due.toUtc(), DateTime.utc(2026, 8, 1));
  });

  test('grammar SRS upsert is atomic on its natural key', () async {
    Future<void> upsert(int reps) => database.vocabularyDao.upsertSrsCard(
      SrsCardsCompanion.insert(
        cardType: 'grammar',
        grammarPatternKey: const Value('accusative_direct_object'),
        reps: Value(reps),
      ),
    );

    await upsert(0);
    await upsert(2);

    final rows = await database.select(database.srsCards).get();
    expect(rows, hasLength(1));
    expect(rows.single.grammarPatternKey, 'accusative_direct_object');
    expect(rows.single.reps, 2);
  });

  test('new-card quota counts first committed review only', () async {
    await database
        .into(database.flashcards)
        .insert(
          FlashcardsCompanion.insert(
            id: const Value(1),
            wordCz: 'pes',
            wordEn: 'dog',
          ),
        );
    final cardId = await database
        .into(database.srsCards)
        .insert(
          SrsCardsCompanion.insert(
            cardType: 'vocabulary',
            flashcardId: const Value(1),
          ),
        );
    final reviewedAt = DateTime(2026, 7, 23, 10);
    final scheduled = SrsCardsCompanion(
      id: Value(cardId),
      reps: const Value(1),
      state: const Value('review'),
      lastReviewed: Value(reviewedAt),
    );

    expect(
      await database.vocabularyDao.commitSrsReview(
        reviewId: 'review-1',
        card: scheduled,
        rating: 'good',
        reviewedAt: reviewedAt,
        introducedNewCard: true,
      ),
      isTrue,
    );
    expect(
      await database.vocabularyDao.commitSrsReview(
        reviewId: 'review-1',
        card: scheduled,
        rating: 'good',
        reviewedAt: reviewedAt,
        introducedNewCard: true,
      ),
      isFalse,
    );
    await database.vocabularyDao.commitSrsReview(
      reviewId: 'review-2',
      card: scheduled,
      rating: 'again',
      reviewedAt: reviewedAt.add(const Duration(minutes: 5)),
      introducedNewCard: false,
    );

    expect(
      await database.vocabularyDao.introducedCardCountForDay(reviewedAt),
      1,
    );
    expect(
      await database.vocabularyDao.introducedCardCountForDay(
        reviewedAt.add(const Duration(days: 1)),
      ),
      0,
    );
    expect(await database.select(database.reviewAttempts).get(), hasLength(2));
    final rewards = await database.select(database.rewardLedger).get();
    expect(rewards, hasLength(2));
    expect(
      rewards.map((reward) => (reward.rewardId, reward.xp)),
      containsAll(<(String, int)>[
        ('review:review-1', 2),
        ('review:review-2', 0),
      ]),
    );
    final gamification =
        await database.select(database.gamificationStateTable).getSingle();
    expect(gamification.totalXp, 2);
    expect(gamification.dailyXp, 2);
    expect(gamification.dailyXpResetDate, '2026-07-23T00:00:00.000');
  });

  test(
    'review reward survives restart and redelivery stays idempotent',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp(
        'czechify-review-restart-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/review.sqlite');
      final reviewedAt = DateTime(2026, 7, 23, 10);
      var persistent = AppDatabase.forTesting(NativeDatabase(file));

      await persistent
          .into(persistent.flashcards)
          .insert(
            FlashcardsCompanion.insert(
              id: const Value(1),
              wordCz: 'pes',
              wordEn: 'dog',
            ),
          );
      final cardId = await persistent
          .into(persistent.srsCards)
          .insert(
            SrsCardsCompanion.insert(
              cardType: 'vocabulary',
              flashcardId: const Value(1),
            ),
          );
      final scheduled = SrsCardsCompanion(
        id: Value(cardId),
        reps: const Value(1),
        state: const Value('review'),
        lastReviewed: Value(reviewedAt),
      );
      expect(
        await persistent.vocabularyDao.commitSrsReview(
          reviewId: 'restart-review',
          card: scheduled,
          rating: 'easy',
          reviewedAt: reviewedAt,
          introducedNewCard: true,
        ),
        isTrue,
      );
      await persistent.close();

      persistent = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(persistent.close);
      expect(
        await persistent.vocabularyDao.commitSrsReview(
          reviewId: 'restart-review',
          card: scheduled,
          rating: 'easy',
          reviewedAt: reviewedAt,
          introducedNewCard: true,
        ),
        isFalse,
      );
      expect(
        await persistent.select(persistent.reviewAttempts).get(),
        hasLength(1),
      );
      final rewards = await persistent.select(persistent.rewardLedger).get();
      expect(rewards, hasLength(1));
      expect(rewards.single.xp, 3);
      expect((await persistent.gamificationDao.load())?.totalXp, 3);
    },
  );
}
