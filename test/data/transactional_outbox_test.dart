import 'package:czechify/data/database/database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() => database.close());

  Future<void> rejectOutboxWrites() => database.customStatement('''
    CREATE TRIGGER reject_sync_enqueue
    BEFORE INSERT ON sync_queue
    BEGIN
      SELECT RAISE(ABORT, 'simulated outbox failure');
    END
  ''');

  test('lesson progress rolls back when its outbox write fails', () async {
    await rejectOutboxWrites();

    await expectLater(
      database.progressDao.recordLessonCompletion(
        attemptId: 'attempt-outbox-failure',
        lessonId: 101,
        unitId: 1,
        score: 0.8,
        correctCount: 4,
        incorrectCount: 1,
        skippedCount: 0,
        startedAt: DateTime.utc(2026, 7, 23),
        activityXp: 20,
        exerciseEvidence: const [],
      ),
      throwsA(anything),
    );

    final rows = await database.select(database.lessonProgress).get();
    expect(rows, isEmpty);
    expect(await database.select(database.lessonAttempts).get(), isEmpty);
    expect(await database.select(database.rewardLedger).get(), isEmpty);
    expect(await database.select(database.exerciseAttempts).get(), isEmpty);
    expect(
      await database.select(database.gamificationStateTable).get(),
      isEmpty,
    );
  });

  test('badge and KV progress roll back when outbox writes fail', () async {
    await rejectOutboxWrites();

    await expectLater(
      database.progressDao.earnBadge('first'),
      throwsA(anything),
    );
    await expectLater(
      database.progressDao.setProgressValue('streak', '4'),
      throwsA(anything),
    );

    expect(await database.select(database.earnedBadges).get(), isEmpty);
    expect(await database.select(database.userProgress).get(), isEmpty);
  });

  test('SRS state rolls back when its outbox write fails', () async {
    await database
        .into(database.flashcards)
        .insert(
          FlashcardsCompanion.insert(
            id: const Value(1),
            wordCz: 'pes',
            wordEn: 'dog',
          ),
        );
    final id = await database
        .into(database.srsCards)
        .insert(
          SrsCardsCompanion.insert(
            cardType: 'vocabulary',
            flashcardId: const Value(1),
            stability: const Value(1),
            difficulty: const Value(2),
            due: Value(DateTime.utc(2026, 1, 1)),
            reps: const Value(1),
            state: const Value('learning'),
          ),
        );
    await rejectOutboxWrites();

    await expectLater(
      database.vocabularyDao.updateSrsCard(
        SrsCardsCompanion(
          id: Value(id),
          stability: const Value(9),
          reps: const Value(2),
          lastReviewed: Value(DateTime.utc(2026, 7, 20)),
        ),
      ),
      throwsA(anything),
    );

    final card =
        await (database.select(database.srsCards)
          ..where((row) => row.id.equals(id))).getSingle();
    expect(card.stability, 1);
    expect(card.reps, 1);
    expect(card.lastReviewed, isNull);
  });

  test('gamification state rolls back when its outbox write fails', () async {
    await rejectOutboxWrites();

    await expectLater(
      database.gamificationDao.save(
        hearts: 4,
        maxHearts: 5,
        currentStreak: 2,
        longestStreak: 3,
        totalXp: 120,
        dailyXp: 20,
        dailyGoalXp: 50,
        gems: 4,
        earnedBadgesJson: '["first"]',
        streakFreezeAvailable: true,
      ),
      throwsA(anything),
    );

    expect(
      await database.select(database.gamificationStateTable).get(),
      isEmpty,
    );
  });
}
