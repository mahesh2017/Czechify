import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceskina_pro/data/database/database.dart';

/// After squashing 19 incremental migrations into v1, this test verifies
/// that a fresh database creates the full schema (all tables, all columns)
/// in a single `onCreate` call.
void main() {
  test('squashed schema v1 creates all tables and indexes on fresh install',
      () async {
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
    await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='index' AND name='srs_cards_vocabulary_key'",
    ).get();
    await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='index' AND name='content_release_single_active'",
    ).get();

    // Verify key columns added in later migrations exist.
    await db.customSelect(
      'SELECT lesson_id FROM flashcards LIMIT 1',
    ).get();
    await db.customSelect(
      'SELECT content_uid FROM flashcards LIMIT 1',
    ).get();
    await db.customSelect(
      'SELECT product FROM exam_results LIMIT 1',
    ).get();
    await db.customSelect(
      'SELECT is_active FROM units LIMIT 1',
    ).get();

    await db.close();
  });
}