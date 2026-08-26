import 'dart:convert';

import 'package:ceskina_pro/data/database/database.dart';
import 'package:ceskina_pro/data/repositories/drift_vocabulary_repository.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 0D: user-created ("manual") cards must sync by a stable UUID, never
/// the local autoincrement id. Two devices each allocate manual ids from
/// MAX(id)+1 (>= 900001), so the numeric id collides across devices while the
/// words differ — poisoning each other's SRS state on sync. The stable
/// content_uid removes that collision.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String?> srsContentKey() async {
    final row =
        await (db.select(db.syncQueue)
          ..where((q) => q.entity.equals('srs_cards'))).getSingleOrNull();
    if (row == null) return null;
    return (jsonDecode(row.payload) as Map<String, dynamic>)['content_key']
        as String?;
  }

  Future<void> enqueueSrsFor(int flashcardId) async {
    final srs =
        await (db.select(db.srsCards)
          ..where((s) => s.flashcardId.equals(flashcardId))).getSingle();
    // updateSrsCard is the outbox-enqueuing path (as a review would trigger).
    await db.vocabularyDao.updateSrsCard(
      SrsCardsCompanion(id: Value(srs.id), reps: const Value(1)),
    );
  }

  test('manual card syncs by its UUID content_uid, not the local id', () async {
    final repo = DriftVocabularyRepository(db);
    expect(await repo.addManualCard(cz: 'strom', en: 'tree'), isTrue);

    final card = await db.select(db.flashcards).getSingle();
    expect(card.contentUid, isNotNull);
    expect(card.id, greaterThanOrEqualTo(900001)); // local, collision-prone id

    await enqueueSrsFor(card.id);

    // The sync key is the stable UUID, NOT the local numeric id.
    expect(await srsContentKey(), card.contentUid);
    expect(await srsContentKey(), isNot(card.id.toString()));
  });

  test(
    'creating a manual card enqueues its definition to custom_cards',
    () async {
      final repo = DriftVocabularyRepository(db);
      expect(
        await repo.addManualCard(cz: 'strom', en: 'tree', ipa: 'strom'),
        isTrue,
      );

      final card = await db.select(db.flashcards).getSingle();
      final defRow =
          await (db.select(db.syncQueue)
            ..where((q) => q.entity.equals('custom_cards'))).getSingle();
      final payload = jsonDecode(defRow.payload) as Map<String, dynamic>;
      expect(defRow.entityKey, card.contentUid);
      expect(payload['content_uid'], card.contentUid);
      expect(payload['word_cz'], 'strom');
      expect(payload['word_en'], 'tree');
    },
  );

  test(
    'a second device materializes the card, then attaches its SRS state',
    () async {
      // This test intentionally models two devices with two simultaneous
      // databases. Drift's warning protects production apps from accidental
      // duplicate instances, but this is the scenario under test.
      final previousWarningSetting =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () =>
            driftRuntimeOptions.dontWarnAboutMultipleDatabases =
                previousWarningSetting,
      );

      // Device A creates the card and reads what it would sync.
      final deviceA = db;
      final repo = DriftVocabularyRepository(deviceA);
      await repo.addManualCard(cz: 'strom', en: 'tree', ipa: 'strom');
      final aCard = await deviceA.select(deviceA.flashcards).getSingle();
      final uid = aCard.contentUid!;

      // Device B starts empty (no such flashcard).
      final deviceB = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(deviceB.close);
      expect(await deviceB.select(deviceB.flashcards).get(), isEmpty);

      // Pull order guarantees custom_cards merges before srs_cards.
      await deviceB.vocabularyDao.mergeCustomCard(
        contentUid: uid,
        wordCz: 'strom',
        wordEn: 'tree',
        ipa: 'strom',
      );
      await deviceB.vocabularyDao.mergeSrsCard(
        cardType: 'vocabulary',
        contentKey: uid, // UUID, not a numeric id
        stability: 1,
        difficulty: 2,
        due: DateTime.utc(2026, 7, 24),
        reps: 3,
        state: 'review',
        lastReviewed: DateTime.utc(2026, 7, 23),
      );

      final bCard = await deviceB.select(deviceB.flashcards).getSingle();
      expect(bCard.contentUid, uid);
      expect(bCard.wordCz, 'strom');

      final srs = await deviceB.select(deviceB.srsCards).getSingle();
      expect(srs.flashcardId, bCard.id); // attached to the materialized card
      expect(srs.reps, 3);
    },
  );

  test(
    'an SRS row whose custom definition is absent is safely ignored',
    () async {
      // No mergeCustomCard first — the referenced UUID has no local flashcard.
      await db.vocabularyDao.mergeSrsCard(
        cardType: 'vocabulary',
        contentKey: 'missing-uuid-1234',
        stability: 1,
        difficulty: 2,
        due: DateTime.utc(2026, 7, 24),
        reps: 3,
        state: 'review',
        lastReviewed: DateTime.utc(2026, 7, 23),
      );
      expect(
        await db.select(db.srsCards).get(),
        isEmpty,
      ); // dropped, not mis-attached
    },
  );

  test('managed (seeded) card still syncs by its deterministic id', () async {
    await db
        .into(db.flashcards)
        .insert(
          FlashcardsCompanion.insert(
            id: const Value(42),
            wordCz: 'kniha',
            wordEn: 'book',
          ),
        );
    await db.vocabularyDao.upsertSrsCard(
      SrsCardsCompanion.insert(
        cardType: 'vocabulary',
        flashcardId: const Value(42),
        reps: const Value(0),
        due: Value(DateTime.utc(2026, 7, 23)),
      ),
    );
    await enqueueSrsFor(42);

    expect(await srsContentKey(), '42');
  });
}
