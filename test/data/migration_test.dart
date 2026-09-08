import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:czechify/data/database/database.dart';
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
      'learner_profiles',
      'reminder_preferences',
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
    final rows =
        await db
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
    await db.customSelect('SELECT key FROM learner_profiles LIMIT 1').get();
    await db.customSelect('SELECT key FROM reminder_preferences LIMIT 1').get();

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

    final indexes =
        await upgraded
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
    final directory = await Directory.systemTemp.createTemp('czechify-dedupe-');
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

    final cards =
        await upgraded.customSelect('SELECT id, reps FROM srs_cards').get();
    expect(cards, hasLength(1));
    expect(
      cards.single.read<int>('reps'),
      9,
      reason: 'the more-reviewed duplicate is the one a learner would miss',
    );

    final active =
        await upgraded
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

  group('schema v4 replaces the frozen timestamp defaults', () {
    // These columns were declared `withDefault(Constant(DateTime.now()))`.
    // Drift resolves a Dart constant while building `CREATE TABLE`, so the
    // schema was written with a literal — whenever the database happened to be
    // created on that device — and every later insert that omitted the column
    // reused it. Only `conversations` is created here: the upgrade step skips
    // tables a database does not have, which keeps this focused on the default
    // instead of reconstructing all of v3.
    const frozen = 1700000000;
    const createV3Conversations = '''
      CREATE TABLE conversations (
        id TEXT NOT NULL PRIMARY KEY,
        scenario TEXT NOT NULL,
        cefr_level TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT $frozen
      );
      PRAGMA user_version = 3;
    ''';

    test('a v3 install stops handing out the baked-in literal', () async {
      final directory = await Directory.systemTemp.createTemp(
        'czechify-frozen-default-',
      );
      final file = File('${directory.path}/v3.sqlite');
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute(createV3Conversations);
      legacy.close();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      final id = await db.conversationDao.createConversation('Shopping', 'A1');
      final row = (await db.conversationDao.getAllConversations()).single;

      expect(row.id, id);
      expect(
        row.createdAt.millisecondsSinceEpoch ~/ 1000,
        isNot(frozen),
        reason: 'the rebuilt table still carried the old literal default',
      );
      expect(
        row.createdAt.isAfter(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );

      await db.close();
      await directory.delete(recursive: true);
    });

    test('rows written before the upgrade survive the rebuild', () async {
      final directory = await Directory.systemTemp.createTemp(
        'czechify-frozen-default-rows-',
      );
      final file = File('${directory.path}/v3.sqlite');
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute(createV3Conversations);
      legacy.execute(
        'INSERT INTO conversations (id, scenario, cefr_level) '
        "VALUES ('conv_old', 'Casual Chat', 'A2')",
      );
      legacy.close();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      final row = (await db.conversationDao.getAllConversations()).single;

      expect(row.id, 'conv_old');
      expect(row.scenario, 'Casual Chat');
      expect(row.cefrLevel, 'A2');
      // Timestamps already written are wrong and there is nothing left to
      // recover them from. The rebuild must at least not lose or alter them.
      expect(row.createdAt.millisecondsSinceEpoch ~/ 1000, frozen);

      await db.close();
      await directory.delete(recursive: true);
    });
  });

  group('schema v5 makes the externally-scored exam columns nullable', () {
    test('v4 exam results accept an unassessed section afterwards', () async {
      // Schema v4: writing/speaking/total were NOT NULL DEFAULT 0, so a
      // section nobody scored was stored as a zero the learner appeared to
      // have earned.
      final directory = await Directory.systemTemp.createTemp(
        'czechify-exam-nullable-',
      );
      final file = File('${directory.path}/v4.sqlite');
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute('''
        CREATE TABLE exam_results (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          level TEXT NOT NULL,
          product TEXT NOT NULL DEFAULT 'permanent_residence',
          taken_at INTEGER NOT NULL DEFAULT 0,
          reading_score INTEGER NOT NULL DEFAULT 0,
          listening_score INTEGER NOT NULL DEFAULT 0,
          writing_score INTEGER NOT NULL DEFAULT 0,
          speaking_score INTEGER NOT NULL DEFAULT 0,
          total_score INTEGER NOT NULL DEFAULT 0,
          passed INTEGER NOT NULL DEFAULT 0,
          details TEXT
        );
        INSERT INTO exam_results (id, level, reading_score, listening_score,
          writing_score, speaking_score, total_score)
          VALUES (7, 'a2', 80, 70, 0, 0, 38);
        PRAGMA user_version = 4;
      ''');
      legacy.close();

      final db = AppDatabase.forTesting(NativeDatabase(file));

      // The existing row keeps its zeros — nothing recorded whether they were
      // scored or merely missing, and the migration must not invent that.
      final legacyRow =
          await db
              .customSelect('SELECT writing_score FROM exam_results WHERE id=7')
              .getSingle();
      expect(legacyRow.read<int?>('writing_score'), 0);

      // But a new attempt can now say a section was never assessed.
      await db.customStatement(
        'INSERT INTO exam_results (level, reading_score, listening_score) '
        "VALUES ('a2', 60, 60)",
      );
      final fresh =
          await db
              .customSelect(
                'SELECT writing_score, total_score FROM exam_results '
                'WHERE id != 7',
              )
              .getSingle();
      expect(fresh.read<int?>('writing_score'), isNull);
      expect(fresh.read<int?>('total_score'), isNull);

      await db.close();
      await directory.delete(recursive: true);
    });
  });

  group('schema v8 queues learning history written before it could sync', () {
    // `learning_evidence_events` and `delayed_transfer_assignments` started
    // syncing in v1.0.7, and only on write. Nothing ever looked at what was
    // already on the device, so the learners the feature was built for — the
    // ones with a history to carry — still lost it on a new device, while
    // anyone who installed afterwards was fine. The account screen said this
    // history transfers.
    Future<File> writeV7Database(String name) async {
      final directory = await Directory.systemTemp.createTemp(name);
      final file = File('${directory.path}/v7.sqlite');
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute('''
        CREATE TABLE learning_evidence_events (
          evidence_id TEXT NOT NULL PRIMARY KEY,
          lesson_id INTEGER NOT NULL,
          exercise_id INTEGER,
          skill TEXT NOT NULL,
          phase TEXT NOT NULL,
          correct INTEGER NOT NULL,
          novel_task INTEGER NOT NULL,
          supports_json TEXT NOT NULL DEFAULT '[]',
          concept_keys_json TEXT NOT NULL DEFAULT '[]',
          response_latency_ms INTEGER NOT NULL,
          observed_at INTEGER NOT NULL
        );
        CREATE TABLE delayed_transfer_assignments (
          assignment_id TEXT NOT NULL PRIMARY KEY,
          source_attempt_id TEXT NOT NULL,
          lesson_id INTEGER NOT NULL,
          source_exercise_id INTEGER NOT NULL,
          due_at INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          completed_evidence_id TEXT,
          created_at INTEGER NOT NULL,
          completed_at INTEGER
        );
        CREATE TABLE sync_queue (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          entity TEXT NOT NULL,
          entity_key TEXT NOT NULL,
          op TEXT NOT NULL DEFAULT 'upsert',
          payload TEXT NOT NULL,
          device_id TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          next_attempt_at INTEGER,
          last_error TEXT,
          dead_lettered_at INTEGER
        );
        INSERT INTO learning_evidence_events (
          evidence_id, lesson_id, exercise_id, skill, phase, correct,
          novel_task, supports_json, concept_keys_json, response_latency_ms,
          observed_at
        ) VALUES (
          'ev-old', 4, 11, 'vocabulary', 'retrieve', 1, 0,
          '["hint"]', '["byt"]', 1400, 1756000000
        );
        INSERT INTO delayed_transfer_assignments (
          assignment_id, source_attempt_id, lesson_id, source_exercise_id,
          due_at, status, created_at
        ) VALUES ('transfer:old:11', 'att-old', 4, 11, 1757000000,
          'pending', 1756000000);
        PRAGMA user_version = 7;
      ''');
      legacy.close();
      return file;
    }

    test('history already on the device is queued for upload', () async {
      final file = await writeV7Database('czechify-history-backfill-');
      final db = AppDatabase.forTesting(NativeDatabase(file));

      final queued = await db.select(db.syncQueue).get();
      final entities = queued.map((row) => row.entity).toSet();
      expect(entities, {
        'learning_evidence_events',
        'delayed_transfer_assignments',
      });
      expect(
        queued.map((row) => row.entityKey),
        containsAll(['ev-old', 'transfer:old:11']),
      );

      // The payload is what the backend receives, so the fields have to be
      // there and shaped like the ones the write path enqueues — JSON arrays,
      // not the strings they are stored as.
      final evidence =
          jsonDecode(
                queued
                    .firstWhere(
                      (row) => row.entity == 'learning_evidence_events',
                    )
                    .payload,
              )
              as Map<String, dynamic>;
      expect(evidence['evidence_id'], 'ev-old');
      expect(evidence['lesson_id'], 4);
      expect(evidence['correct'], isTrue);
      expect(evidence['supports'], ['hint']);
      expect(evidence['concept_keys'], ['byt']);
      expect(evidence['observed_at'], endsWith('Z'));

      await db.close();
      await file.parent.delete(recursive: true);
    });

    test('the rows themselves are untouched', () async {
      final file = await writeV7Database('czechify-history-backfill-rows-');
      final db = AppDatabase.forTesting(NativeDatabase(file));

      expect(await db.select(db.learningEvidenceEvents).get(), hasLength(1));
      final assignment =
          (await db.select(db.delayedTransferAssignments).get()).single;
      expect(assignment.assignmentId, 'transfer:old:11');
      expect(assignment.status, 'pending');

      await db.close();
      await file.parent.delete(recursive: true);
    });

    test('it runs once, not on every open', () async {
      final file = await writeV7Database('czechify-history-backfill-once-');
      final first = AppDatabase.forTesting(NativeDatabase(file));
      final afterUpgrade = (await first.select(first.syncQueue).get()).length;
      await first.close();

      final second = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await second.select(second.syncQueue).get()).length,
        afterUpgrade,
        reason: 'the migration is stamped, so reopening must queue nothing',
      );
      await second.close();
      await file.parent.delete(recursive: true);
    });

    test('a database predating either table still opens', () async {
      // A learner far enough behind may have neither table. A missing one
      // must not turn a schema change into a failure to launch.
      final directory = await Directory.systemTemp.createTemp(
        'czechify-history-backfill-absent-',
      );
      final file = File('${directory.path}/v7.sqlite');
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute('''
        CREATE TABLE sync_queue (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          entity TEXT NOT NULL,
          entity_key TEXT NOT NULL,
          op TEXT NOT NULL DEFAULT 'upsert',
          payload TEXT NOT NULL,
          device_id TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          next_attempt_at INTEGER,
          last_error TEXT,
          dead_lettered_at INTEGER
        );
        PRAGMA user_version = 7;
      ''');
      legacy.close();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      expect(await db.select(db.syncQueue).get(), isEmpty);

      await db.close();
      await directory.delete(recursive: true);
    });
  });
}
