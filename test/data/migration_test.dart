import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:ceskina_pro/data/database/database.dart';

void main() {
  test('schema v1 → v18 migration preserves data and adds new schema', () async {
    final file = File(
      p.join(
        Directory.systemTemp.path,
        'ceskina_migration_test_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    // 1. Create a current database, then hand-downgrade it to the exact v1
    // shape: no lesson_id, sync_queue, or sync_state.
    var db = AppDatabase.forTesting(NativeDatabase(file));
    await db.customSelect('SELECT 1').get(); // force open + createAll
    await db.close();

    final rawDb = raw.sqlite3.open(file.path);
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN lesson_id');
    rawDb.execute('DROP TABLE sync_queue');
    rawDb.execute('DROP TABLE sync_state');
    rawDb.execute('DROP TABLE gamification_state_table');
    rawDb.execute('DROP TABLE lesson_attempts');
    rawDb.execute('DROP TABLE reward_ledger');
    rawDb.execute('DROP TABLE exercise_attempts');
    rawDb.execute('DROP TABLE review_attempts');
    rawDb.execute('DROP TABLE content_release_packs');
    rawDb.execute('DROP TABLE content_release_installations');
    rawDb.execute('DROP TABLE learning_evidence_events');
    rawDb.execute('DROP TABLE placement_profiles');
    rawDb.execute('DROP TABLE delayed_transfer_assignments');
    rawDb.execute('ALTER TABLE units DROP COLUMN is_active');
    rawDb.execute('ALTER TABLE lessons DROP COLUMN is_active');
    rawDb.execute('ALTER TABLE exercises DROP COLUMN is_active');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN is_active');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN lemma');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN sense_key');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN part_of_speech');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN morphology_json');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN register_label');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN pronunciation_source');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN content_uid');
    rawDb.execute('ALTER TABLE exam_results DROP COLUMN product');
    rawDb.execute('ALTER TABLE grammar_rules DROP COLUMN is_active');
    rawDb.execute('DROP INDEX srs_cards_vocabulary_key');
    rawDb.execute('DROP INDEX srs_cards_grammar_key');
    rawDb.execute('PRAGMA user_version = 1');
    // Seed a row the way a v1 install would have it.
    rawDb.execute(
      "INSERT INTO flashcards (id, word_cz, word_en) VALUES (1, 'pes', 'dog')",
    );
    final before =
        rawDb
            .select("SELECT name FROM pragma_table_info('flashcards')")
            .map((r) => r['name'])
            .toList();
    expect(before, isNot(contains('lesson_id')));
    final tablesBefore =
        rawDb
            .select("SELECT name FROM sqlite_master WHERE type = 'table'")
            .map((r) => r['name'])
            .toList();
    expect(tablesBefore, isNot(contains('sync_queue')));
    expect(tablesBefore, isNot(contains('sync_state')));
    expect(tablesBefore, isNot(contains('gamification_state_table')));
    expect(tablesBefore, isNot(contains('lesson_attempts')));
    expect(tablesBefore, isNot(contains('reward_ledger')));
    expect(tablesBefore, isNot(contains('exercise_attempts')));
    expect(tablesBefore, isNot(contains('review_attempts')));
    expect(tablesBefore, isNot(contains('content_release_installations')));
    expect(tablesBefore, isNot(contains('content_release_packs')));
    expect(tablesBefore, isNot(contains('learning_evidence_events')));
    expect(tablesBefore, isNot(contains('placement_profiles')));
    expect(tablesBefore, isNot(contains('delayed_transfer_assignments')));
    rawDb.close();

    // 2. Reopen through AppDatabase — the complete upgrade chain must add
    // every later schema object without touching existing rows.
    db = AppDatabase.forTesting(NativeDatabase(file));
    final cols =
        await db
            .customSelect("SELECT name FROM pragma_table_info('flashcards')")
            .get();
    expect(cols.map((r) => r.read<String>('name')), contains('lesson_id'));
    expect(
      cols.map((r) => r.read<String>('name')),
      containsAll([
        'lemma',
        'sense_key',
        'part_of_speech',
        'morphology_json',
        'register_label',
        'pronunciation_source',
        'content_uid',
      ]),
    );

    final row =
        await db
            .customSelect(
              'SELECT word_cz, lesson_id FROM flashcards WHERE id = 1',
            )
            .getSingle();
    expect(row.read<String>('word_cz'), 'pes');
    expect(row.readNullable<int>('lesson_id'), isNull);

    final tables =
        await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get();
    final tableNames = tables.map((r) => r.read<String>('name'));
    expect(
      tableNames,
      containsAll(<String>[
        'sync_queue',
        'sync_state',
        'gamification_state_table',
        'lesson_attempts',
        'reward_ledger',
        'exercise_attempts',
        'review_attempts',
        'content_release_installations',
        'content_release_packs',
        'learning_evidence_events',
        'placement_profiles',
        'delayed_transfer_assignments',
      ]),
    );

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 19);

    // v19 adds the consent audit log. A migration that silently skipped it
    // would leave an app that believes it is recording consent and is not.
    final consentTable =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name = 'consent_records'",
            )
            .get();
    expect(consentTable, hasLength(1));

    final queueColumns =
        await db
            .customSelect("SELECT name FROM pragma_table_info('sync_queue')")
            .get();
    expect(
      queueColumns.map((row) => row.read<String>('name')),
      containsAll(['next_attempt_at', 'dead_lettered_at', 'last_error']),
    );
    await db.close();
  });

  test('schema v4 → v15 adds retry metadata and newer schema', () async {
    final file = File(
      p.join(
        Directory.systemTemp.path,
        'ceskina_v4_migration_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    var db = AppDatabase.forTesting(NativeDatabase(file));
    await db.customSelect('SELECT 1').get();
    await db.close();

    final rawDb = raw.sqlite3.open(file.path);
    rawDb.execute('ALTER TABLE sync_queue DROP COLUMN next_attempt_at');
    rawDb.execute('ALTER TABLE sync_queue DROP COLUMN dead_lettered_at');
    rawDb.execute('ALTER TABLE sync_queue DROP COLUMN last_error');
    rawDb.execute('DROP TABLE gamification_state_table');
    rawDb.execute('DROP TABLE lesson_attempts');
    rawDb.execute('DROP TABLE reward_ledger');
    rawDb.execute('DROP TABLE exercise_attempts');
    rawDb.execute('DROP TABLE review_attempts');
    rawDb.execute('DROP TABLE content_release_packs');
    rawDb.execute('DROP TABLE content_release_installations');
    rawDb.execute('DROP TABLE learning_evidence_events');
    rawDb.execute('DROP TABLE placement_profiles');
    rawDb.execute('DROP TABLE delayed_transfer_assignments');
    rawDb.execute('ALTER TABLE units DROP COLUMN is_active');
    rawDb.execute('ALTER TABLE lessons DROP COLUMN is_active');
    rawDb.execute('ALTER TABLE exercises DROP COLUMN is_active');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN is_active');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN lemma');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN sense_key');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN part_of_speech');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN morphology_json');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN register_label');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN pronunciation_source');
    rawDb.execute('ALTER TABLE flashcards DROP COLUMN content_uid');
    rawDb.execute('ALTER TABLE exam_results DROP COLUMN product');
    rawDb.execute('ALTER TABLE grammar_rules DROP COLUMN is_active');
    rawDb.execute('DROP INDEX srs_cards_vocabulary_key');
    rawDb.execute('DROP INDEX srs_cards_grammar_key');
    rawDb.execute('PRAGMA user_version = 4');
    rawDb.close();

    db = AppDatabase.forTesting(NativeDatabase(file));
    final columns =
        await db
            .customSelect("SELECT name FROM pragma_table_info('sync_queue')")
            .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      containsAll(['next_attempt_at', 'dead_lettered_at', 'last_error']),
    );
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 19);

    // v6 should have created the gamification_state table.
    final gTables =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'gamification_state_table'",
            )
            .get();
    expect(gTables, isNotEmpty);
    final attemptTables =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'lesson_attempts'",
            )
            .get();
    expect(attemptTables, isNotEmpty);
    final rewardTables =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'reward_ledger'",
            )
            .get();
    expect(rewardTables, isNotEmpty);
    final exerciseAttemptTables =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'exercise_attempts'",
            )
            .get();
    expect(exerciseAttemptTables, isNotEmpty);
    final reviewAttemptTables =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'review_attempts'",
            )
            .get();
    expect(reviewAttemptTables, isNotEmpty);
    final releaseTables =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('content_release_installations', "
              "'content_release_packs')",
            )
            .get();
    expect(releaseTables, hasLength(2));
    final evidenceTables =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('learning_evidence_events', 'placement_profiles')",
            )
            .get();
    expect(evidenceTables, hasLength(2));
    final transferTables =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name = 'delayed_transfer_assignments'",
            )
            .get();
    expect(transferTables, hasLength(1));
    for (final table in [
      'units',
      'lessons',
      'exercises',
      'flashcards',
      'grammar_rules',
    ]) {
      final activeColumn =
          await db
              .customSelect(
                "SELECT name FROM pragma_table_info('$table') "
                "WHERE name = 'is_active'",
              )
              .get();
      expect(activeColumn, hasLength(1), reason: '$table is release-managed');
    }
    final indexes =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name IN ('srs_cards_vocabulary_key', 'srs_cards_grammar_key')",
            )
            .get();
    expect(indexes, hasLength(2));
    await db.close();
  });
}
