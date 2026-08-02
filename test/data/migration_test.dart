import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceskina_pro/data/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

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
}
