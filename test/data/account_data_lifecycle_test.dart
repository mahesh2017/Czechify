import 'package:ceskina_pro/data/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('exports learner data and excludes bundled curriculum', () async {
    await db.customStatement(
      '''INSERT INTO units (id,title,description,phase,order_index,grammar_tags,is_exam_prep)
         VALUES (1,'Unit','Description','a1',1,'',0)''',
    );
    await db.customStatement(
      '''INSERT INTO lessons (id,unit_id,order_in_unit,title,description,duration_minutes,lesson_type,is_review)
         VALUES (1,1,1,'Lesson','Description',10,'introduction',0)''',
    );
    await db.customStatement(
      "INSERT INTO flashcards (id,word_cz,word_en) VALUES (1,'ahoj','hello')",
    );
    await db.customStatement(
      "INSERT INTO flashcards (id,word_cz,word_en) VALUES (900001,'vlastní','custom')",
    );
    await db.customStatement(
      '''INSERT INTO lesson_progress (lesson_id,unit_id,is_completed,best_score,attempts)
         VALUES (1,1,1,90,1)''',
    );
    await db.customStatement(
      "INSERT INTO earned_badges (badge_id) VALUES ('first_lesson')",
    );
    await db.customStatement(
      "INSERT INTO user_progress (key,value) VALUES ('streak','4')",
    );
    await db.customStatement(
      'INSERT INTO gamification_state_table '
      '(key, hearts, total_xp) VALUES (\'primary\', 4, 120)',
    );

    final export = await db.exportLearnerData();

    expect(export['format_version'], 1);
    expect((export['lesson_progress'] as List), hasLength(1));
    expect(export['lesson_attempts'], isA<List>());
    expect(export['reward_ledger'], isA<List>());
    expect(export['exercise_attempts'], isA<List>());
    expect(export['review_attempts'], isA<List>());
    expect((export['earned_badges'] as List), hasLength(1));
    expect((export['user_progress'] as List), hasLength(1));
    expect((export['gamification_state'] as List), hasLength(1));
    expect((export['custom_flashcards'] as List), hasLength(1));
    expect(export.containsKey('units'), isFalse);
    expect(export.containsKey('lessons'), isFalse);
  });

  test('clears learner data while preserving bundled content', () async {
    await db.customStatement(
      '''INSERT INTO units (id,title,description,phase,order_index,grammar_tags,is_exam_prep)
         VALUES (1,'Unit','Description','a1',1,'',0)''',
    );
    await db.customStatement(
      "INSERT INTO flashcards (id,word_cz,word_en) VALUES (1,'ahoj','hello')",
    );
    await db.customStatement(
      "INSERT INTO flashcards (id,word_cz,word_en) VALUES (900001,'vlastní','custom')",
    );
    await db.customStatement(
      "INSERT INTO user_progress (key,value) VALUES ('streak','4')",
    );
    await db.customStatement(
      "INSERT INTO earned_badges (badge_id) VALUES ('first_lesson')",
    );
    await db.customStatement(
      'INSERT INTO gamification_state_table '
      '(key, hearts, total_xp) VALUES (\'primary\', 4, 120)',
    );

    await db.clearLearnerData();

    expect(await db.select(db.userProgress).get(), isEmpty);
    expect(await db.select(db.lessonAttempts).get(), isEmpty);
    expect(await db.select(db.rewardLedger).get(), isEmpty);
    expect(await db.select(db.exerciseAttempts).get(), isEmpty);
    expect(await db.select(db.reviewAttempts).get(), isEmpty);
    expect(await db.select(db.earnedBadges).get(), isEmpty);
    expect(await db.select(db.gamificationStateTable).get(), isEmpty);
    final cards = await db.select(db.flashcards).get();
    expect(cards.map((card) => card.id), [1]);
    final resetReviews = await db.select(db.srsCards).get();
    expect(resetReviews, hasLength(1));
    expect(resetReviews.single.flashcardId, 1);
    expect(resetReviews.single.state, 'newCard');
    expect(resetReviews.single.reps, 0);
    expect(await db.select(db.units).get(), hasLength(1));
  });

  group('consent audit log', () {
    Future<void> recordConsent() => db.customStatement(
      'INSERT INTO consent_records '
      '(purpose, notice_version, policy_version, granted, decided_at) '
      "VALUES ('voice_cloud_processing', '1', '1', 1, '2026-08-01T10:00:00Z')",
    );

    test('survives an account switch', () async {
      // Switching accounts is not an erasure request. The decision recorded
      // here really was made, and it is the evidence a controller has to be
      // able to produce — wiping it left nothing to produce.
      await recordConsent();

      await db.transaction(
        () => db.clearLearnerDataRows(preserveConsentLog: true),
      );

      final records = await db.select(db.consentRecords).get();
      expect(records, hasLength(1));
      expect(records.single.purpose, 'voice_cloud_processing');
      expect(records.single.granted, isTrue);
    });

    test('is erased with the account', () async {
      // Deletion is the opposite case: the record is the learner's, and
      // erasing their account erases it too.
      await recordConsent();

      await db.clearLearnerData();

      expect(await db.select(db.consentRecords).get(), isEmpty);
    });
  });
}
