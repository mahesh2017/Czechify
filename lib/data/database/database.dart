import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'tables/units.dart';
import 'tables/lessons.dart';
import 'tables/exercises.dart';
import 'tables/flashcards.dart';
import 'tables/srs_cards.dart';
import 'tables/conversations.dart';
import 'tables/chat_messages.dart';
import 'tables/grammar_rules.dart';
import 'tables/exam_results.dart';
import 'tables/user_progress.dart';
import 'tables/earned_badges.dart';
import 'tables/consent_records.dart';
import 'tables/lesson_progress.dart';
import 'tables/sync_queue.dart';
import 'tables/gamification_state.dart';
import 'tables/lesson_attempts.dart';
import 'tables/reward_ledger.dart';
import 'tables/exercise_attempts.dart';
import 'tables/review_attempts.dart';
import 'tables/content_release_installations.dart';
import 'tables/content_release_packs.dart';
import 'tables/learning_evidence_events.dart';
import 'tables/placement_profiles.dart';
import 'tables/delayed_transfer_assignments.dart';
import 'tables/learner_profiles.dart';
import 'daos/curriculum_dao.dart';
import 'daos/vocabulary_dao.dart';
import 'daos/conversation_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/sync_dao.dart';
import 'daos/gamification_dao.dart';
import 'daos/profile_dao.dart';

part 'database.g.dart';

/// Main Drift database for Czechify.
@DriftDatabase(
  tables: [
    Units,
    Lessons,
    Exercises,
    Flashcards,
    SrsCards,
    Conversations,
    ChatMessages,
    GrammarRules,
    ExamResults,
    UserProgress,
    EarnedBadges,
    ConsentRecords,
    LessonProgress,
    SyncQueue,
    SyncState,
    GamificationStateTable,
    LessonAttempts,
    RewardLedger,
    ExerciseAttempts,
    ReviewAttempts,
    ContentReleaseInstallations,
    ContentReleasePacks,
    LearningEvidenceEvents,
    PlacementProfiles,
    DelayedTransferAssignments,
    LearnerProfiles,
    ReminderPreferences,
  ],
  daos: [
    CurriculumDao,
    VocabularyDao,
    ConversationDao,
    ProgressDao,
    SyncDao,
    GamificationDao,
    ProfileDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing — inject an in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  /// Version 3 adds portable learner profiles and reminder intent.
  int get schemaVersion => 3;

  /// Portable snapshot of learner-created state. Bundled curriculum rows are
  /// intentionally excluded because they are app content, not user data.
  Future<Map<String, dynamic>> exportLearnerData() async => {
    'format_version': 1,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
    'lesson_progress':
        (await select(lessonProgress).get())
            .map((row) => row.toJson())
            .toList(),
    'lesson_attempts':
        (await select(lessonAttempts).get())
            .map((row) => row.toJson())
            .toList(),
    'reward_ledger':
        (await select(rewardLedger).get()).map((row) => row.toJson()).toList(),
    'exercise_attempts':
        (await select(exerciseAttempts).get())
            .map((row) => row.toJson())
            .toList(),
    'review_attempts':
        (await select(reviewAttempts).get())
            .map((row) => row.toJson())
            .toList(),
    'learning_evidence':
        (await select(learningEvidenceEvents).get())
            .map((row) => row.toJson())
            .toList(),
    'placement_profiles':
        (await select(placementProfiles).get())
            .map((row) => row.toJson())
            .toList(),
    'delayed_transfer_assignments':
        (await select(delayedTransferAssignments).get())
            .map((row) => row.toJson())
            .toList(),
    'earned_badges':
        (await select(earnedBadges).get()).map((row) => row.toJson()).toList(),
    'user_progress':
        (await select(userProgress).get()).map((row) => row.toJson()).toList(),
    'srs_cards':
        (await select(srsCards).get()).map((row) => row.toJson()).toList(),
    'exam_results':
        (await select(examResults).get()).map((row) => row.toJson()).toList(),
    'consent_records':
        (await select(consentRecords).get())
            .map((row) => row.toJson())
            .toList(),
    'conversations':
        (await select(conversations).get()).map((row) => row.toJson()).toList(),
    'chat_messages':
        (await select(chatMessages).get()).map((row) => row.toJson()).toList(),
    'custom_flashcards':
        (await (select(flashcards)
              ..where((row) => row.id.isBiggerThanValue(900000))).get())
            .map((row) => row.toJson())
            .toList(),
    'gamification_state':
        (await select(gamificationStateTable).get())
            .map((row) => row.toJson())
            .toList(),
    'learner_profiles':
        (await select(learnerProfiles).get())
            .map((row) => row.toJson())
            .toList(),
    'reminder_preferences':
        (await select(reminderPreferences).get())
            .map((row) => row.toJson())
            .toList(),
  };

  /// Removes learner-created state before an account switch or after account
  /// deletion. Bundled curriculum/grammar/vocabulary remain available offline.
  Future<void> clearLearnerData() => transaction(clearLearnerDataRows);

  /// Clears learner-owned rows in the caller's current transaction.
  ///
  /// Account switching uses this inside a larger transaction so a failed
  /// remote install restores the previous account's complete local state.
  ///
  /// [preserveConsentLog] keeps the consent audit trail. Switching accounts is
  /// not an erasure request — the decisions recorded on this device were still
  /// really made, and [ConsentRepository] exists specifically so that history
  /// survives ("nothing is ever updated or deleted"). Wiping it on a switch
  /// destroyed the only evidence that consent was ever given, which is the one
  /// thing GDPR Art. 7(1) asks a controller to be able to produce. Account
  /// *deletion* is different and still clears it: that is erasure, and the
  /// record is the learner's to remove.
  Future<void> clearLearnerDataRows({bool preserveConsentLog = false}) async {
    await delete(chatMessages).go();
    await delete(conversations).go();
    await delete(examResults).go();
    if (!preserveConsentLog) await delete(consentRecords).go();
    await delete(lessonAttempts).go();
    await delete(rewardLedger).go();
    await delete(exerciseAttempts).go();
    await delete(reviewAttempts).go();
    await delete(learningEvidenceEvents).go();
    await delete(placementProfiles).go();
    await delete(delayedTransferAssignments).go();
    await delete(lessonProgress).go();
    await delete(earnedBadges).go();
    await delete(userProgress).go();
    await delete(srsCards).go();
    await (delete(flashcards)
      ..where((row) => row.id.isBiggerThanValue(900000))).go();
    await delete(syncQueue).go();
    await delete(syncState).go();
    await delete(gamificationStateTable).go();
    await delete(reminderPreferences).go();
    await delete(learnerProfiles).go();

    // Reset bundled vocabulary to usable new-card state immediately. Waiting
    // for a future app restart/seeder pass would leave the review deck empty
    // after account deletion or switching.
    final bundledIds =
        await (select(flashcards)..where(
          (row) =>
              row.id.isSmallerOrEqualValue(900000) & row.isActive.equals(true),
        )).map((row) => row.id).get();
    if (bundledIds.isNotEmpty) {
      final now = DateTime.now();
      await batch((batch) {
        batch.insertAll(
          srsCards,
          bundledIds
              .map(
                (id) => SrsCardsCompanion.insert(
                  cardType: 'vocabulary',
                  flashcardId: Value(id),
                  due: Value(now),
                ),
              )
              .toList(),
        );
      });
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSrsNaturalKeyIndexes();
      await _createContentReleaseStateIndexes();
    },
    onUpgrade: (m, from, to) async {
      // Drift treats any version change as an "upgrade" — a database stamped
      // with a HIGHER version than [schemaVersion] lands here too, skips every
      // `from <` guard below, and is then silently restamped with the lower
      // number while keeping its old shape. Queries would fail later against
      // columns this build does not know about, with nothing pointing back to
      // the cause. Fail loudly at the point of damage instead.
      if (from > to) {
        throw StateError(
          'Database was created by a newer build (schema v$from) than this '
          'one (v$to). Downgrading is not supported; reinstall the app.',
        );
      }
      if (from < 2) {
        await m.addColumn(lessons, lessons.canDo);
        await m.addColumn(lessons, lessons.newLanguageJson);
        await m.addColumn(lessons, lessons.recyclesJson);
        await m.addColumn(lessons, lessons.exitTask);
      }
      if (from < 3) {
        await m.createTable(learnerProfiles);
        await m.createTable(reminderPreferences);
      }
      // Not guarded by a version check. These indexes were only ever created
      // in [onCreate], so every upgraded install has been running without the
      // uniqueness they enforce — duplicate SRS cards and more than one active
      // content release were both representable.
      await _backfillUniquenessConstraints();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Adds the natural-key uniqueness that [onCreate] has always installed but
  /// [onUpgrade] never did, to a database that may already violate it.
  ///
  /// Order matters: `CREATE UNIQUE INDEX` fails outright against existing
  /// duplicates, and a failure here runs at startup — it would brick the app
  /// far more thoroughly than the missing constraint ever did. So each set of
  /// duplicates is resolved first, keeping the row a learner would miss most.
  Future<void> _backfillUniquenessConstraints() async {
    // Each table is checked rather than assumed. Drift does not create tables
    // introduced after the stored version during an upgrade, so a sufficiently
    // old database can reach here without them — and a missing table must not
    // turn a hardening step into a failure to launch.
    if (await _hasTable('srs_cards')) {
      await _deduplicateSrsCards();
      await _createSrsNaturalKeyIndexes();
    }
    if (await _hasTable('content_release_installations')) {
      await _demoteDuplicateContentReleases();
      await _createContentReleaseStateIndexes();
    }
  }

  Future<bool> _hasTable(String name) async {
    final rows =
        await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable<String>(name)],
        ).get();
    return rows.isNotEmpty;
  }

  Future<void> _deduplicateSrsCards() async {
    // Keep the most-reviewed duplicate; a tie means equal progress, so either
    // row is an honest choice. `SELECT id, MAX(reps) … GROUP BY` is SQLite's
    // documented bare-column rule: `id` comes from the row holding the max.
    await customStatement('''
      DELETE FROM srs_cards
      WHERE card_type = 'vocabulary'
        AND flashcard_id IS NOT NULL
        AND id NOT IN (
          SELECT id FROM (
            SELECT id, MAX(reps) FROM srs_cards
            WHERE card_type = 'vocabulary' AND flashcard_id IS NOT NULL
            GROUP BY flashcard_id
          )
        )
    ''');
    await customStatement('''
      DELETE FROM srs_cards
      WHERE card_type = 'grammar'
        AND grammar_pattern_key IS NOT NULL
        AND id NOT IN (
          SELECT id FROM (
            SELECT id, MAX(reps) FROM srs_cards
            WHERE card_type = 'grammar' AND grammar_pattern_key IS NOT NULL
            GROUP BY grammar_pattern_key
          )
        )
    ''');
  }

  /// Keeps the most recently installed release in each role and demotes the
  /// rest — the newest install is what the app would have been serving.
  Future<void> _demoteDuplicateContentReleases() async {
    for (final flag in const ['is_active', 'is_previous']) {
      await customStatement('''
        UPDATE content_release_installations SET $flag = 0
        WHERE $flag = 1
          AND release_id NOT IN (
            SELECT release_id FROM (
              SELECT release_id, MAX(installed_at)
              FROM content_release_installations
              WHERE $flag = 1
            )
          )
      ''');
    }
  }

  Future<void> _createSrsNaturalKeyIndexes() async {
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS srs_cards_vocabulary_key
      ON srs_cards(flashcard_id)
      WHERE card_type = 'vocabulary' AND flashcard_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS srs_cards_grammar_key
      ON srs_cards(grammar_pattern_key)
      WHERE card_type = 'grammar' AND grammar_pattern_key IS NOT NULL
    ''');
  }

  Future<void> _createContentReleaseStateIndexes() async {
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS content_release_single_active
      ON content_release_installations(is_active)
      WHERE is_active = 1
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS content_release_single_previous
      ON content_release_installations(is_previous)
      WHERE is_previous = 1
    ''');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'czechify.db'));
    return NativeDatabase.createInBackground(file);
  });
}
