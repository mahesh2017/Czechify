import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceskina_pro/data/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Opens the real [AppDatabase] one schema version ahead, so `onUpgrade` runs
/// against a database this build otherwise considers current. That is the only
/// way to exercise the version-independent part of the migration without
/// inventing a fake schema that could drift from the real one.
class _NextVersionDatabase extends AppDatabase {
  _NextVersionDatabase(super.e) : super.forTesting();

  @override
  int get schemaVersion => super.schemaVersion + 1;
}

/// Verify both a fresh install and an upgrade from the previously shipped
/// schema. Lesson metadata must reach existing learners, not just reinstalls.
void main() {
  test('current schema creates all tables and indexes on fresh install', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    // Force open + onCreate.
    await db.customSelect('SELECT 1').get();

    // Verify every table exists by querying it.
    final tables = [
      'flashcards',
      'srs_cards',
      'sync_queue',
      'sync_state',
      'gamification_state_table',
      'lesson_attempts',
      'reward_ledger',
      'exercise_attempts',
      'review_attempts',
      'content_release_packs',
      'content_release_installations',
      'learning_evidence_events',
      'placement_profiles',
      'delayed_transfer_assignments',
      'consent_records',
      'units',
      'lessons',
      'exercises',
      'grammar_rules',
      'lesson_progress',
      'earned_badges',
      'user_progress',
      'exam_results',
      'conversations',
      'chat_messages',
    ];

    for (final table in tables) {
      // A SELECT that succeeds means the table exists.
      await db.customSelect('SELECT COUNT(*) AS c FROM $table').get();
    }

    // Verify the indexes exist.
    await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='srs_cards_vocabulary_key'",
        )
        .get();
    await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='content_release_single_active'",
        )
        .get();

    // Verify key columns added in later migrations exist.
    await db.customSelect('SELECT lesson_id FROM flashcards LIMIT 1').get();
    await db.customSelect('SELECT content_uid FROM flashcards LIMIT 1').get();
    await db.customSelect('SELECT product FROM exam_results LIMIT 1').get();
    await db.customSelect('SELECT is_active FROM units LIMIT 1').get();
    await db
        .customSelect(
          'SELECT can_do, new_language_json, recycles_json, exit_task '
          'FROM lessons LIMIT 1',
        )
        .get();

    await db.close();
  });

  test('schema v1 upgrades lesson outcome columns without data loss', () async {
    final directory = await Directory.systemTemp.createTemp(
      'czechify-schema-upgrade-',
    );
    final file = File('${directory.path}/v1.sqlite');
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE lessons (
        id INTEGER NOT NULL PRIMARY KEY,
        unit_id INTEGER NOT NULL,
        order_in_unit INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL DEFAULT 10,
        lesson_type TEXT NOT NULL DEFAULT 'introduction',
        is_review INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      );
      INSERT INTO lessons (
        id, unit_id, order_in_unit, title, description
      ) VALUES (101, 1, 0, 'Legacy lesson', 'Keep me');
      PRAGMA user_version = 1;
    ''');
    legacy.close();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    final rows = await db
        .customSelect(
          'SELECT title, description, can_do, new_language_json, '
          'recycles_json, exit_task FROM lessons WHERE id = 101',
        )
        .get();

    expect(rows.single.read<String>('title'), 'Legacy lesson');
    expect(rows.single.read<String>('description'), 'Keep me');
    expect(rows.single.read<String>('can_do'), '');
    expect(rows.single.read<String>('new_language_json'), '[]');
    expect(rows.single.read<String>('recycles_json'), '[]');
    expect(rows.single.read<String>('exit_task'), '');

    await db.close();
    await directory.delete(recursive: true);
  });

  test('upgrade installs the uniqueness indexes onCreate always had', () async {
    final directory = await Directory.systemTemp.createTemp(
      'czechify-index-backfill-',
    );
    final file = File('${directory.path}/db.sqlite');

    // A database that was created fresh, then upgraded by a build whose
    // onUpgrade never created these indexes — the state every existing
    // install is actually in.
    final created = AppDatabase.forTesting(NativeDatabase(file));
    await created.customSelect('SELECT 1').get();
    await created.customStatement('DROP INDEX srs_cards_vocabulary_key');
    await created.customStatement('DROP INDEX srs_cards_grammar_key');
    await created.customStatement('DROP INDEX content_release_single_active');
    await created.customStatement('DROP INDEX content_release_single_previous');
    await created.close();

    final upgraded = _NextVersionDatabase(NativeDatabase(file));
    await upgraded.customSelect('SELECT 1').get();

    final indexes = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND "
          "(name LIKE 'srs_cards_%' OR name LIKE 'content_release_single%')",
        )
        .get();
    expect(
      indexes.map((row) => row.read<String>('name')),
      containsAll(<String>[
        'srs_cards_vocabulary_key',
        'srs_cards_grammar_key',
        'content_release_single_active',
        'content_release_single_previous',
      ]),
    );

    await upgraded.close();
    await directory.delete(recursive: true);
  });

  test('upgrade collapses duplicates the missing indexes allowed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'czechify-dedupe-',
    );
    final file = File('${directory.path}/db.sqlite');

    final created = AppDatabase.forTesting(NativeDatabase(file));
    await created.customSelect('SELECT 1').get();
    await created.customStatement('DROP INDEX srs_cards_vocabulary_key');
    await created.customStatement('DROP INDEX content_release_single_active');
    await created.customStatement('DROP INDEX content_release_single_previous');
    await created.customStatement(
      "INSERT INTO flashcards (id, word_cz, word_en) VALUES (1, 'pes', 'dog')",
    );
    // Two SRS rows for one flashcard — impossible with the index, routine
    // without it. The better-reviewed row is the one worth keeping.
    await created.customStatement(
      'INSERT INTO srs_cards (id, card_type, flashcard_id, reps) '
      "VALUES (1, 'vocabulary', 1, 2), (2, 'vocabulary', 1, 9)",
    );
    await created.customStatement(
      'INSERT INTO content_release_installations '
      '(release_id, version, content_checksum, is_active, is_previous, '
      'installed_at) VALUES '
      "('old', 1, 'aaa', 1, 0, 1000), ('new', 2, 'bbb', 1, 0, 2000)",
    );
    await created.close();

    final upgraded = _NextVersionDatabase(NativeDatabase(file));

    final cards = await upgraded
        .customSelect('SELECT id, reps FROM srs_cards')
        .get();
    expect(cards, hasLength(1));
    expect(
      cards.single.read<int>('reps'),
      9,
      reason: 'the more-reviewed duplicate is the one a learner would miss',
    );

    final active = await upgraded
        .customSelect(
          'SELECT release_id FROM content_release_installations '
          'WHERE is_active = 1',
        )
        .get();
    expect(active, hasLength(1));
    expect(active.single.read<String>('release_id'), 'new');

    await upgraded.close();
    await directory.delete(recursive: true);
  });

  test('opening a database from a newer build fails loudly', () async {
    final directory = await Directory.systemTemp.createTemp(
      'czechify-downgrade-',
    );
    final file = File('${directory.path}/db.sqlite');

    // Stamped by a build one version ahead of this one.
    final newer = _NextVersionDatabase(NativeDatabase(file));
    await newer.customSelect('SELECT 1').get();
    await newer.close();

    // The current build must refuse it rather than restamp a schema it does
    // not understand and fail later on an unrelated query.
    final current = AppDatabase.forTesting(NativeDatabase(file));
    await expectLater(
      current.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );

    await current.close().catchError((_) {});
    await directory.delete(recursive: true);
  });
}
