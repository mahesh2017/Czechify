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
import 'daos/curriculum_dao.dart';
import 'daos/vocabulary_dao.dart';
import 'daos/conversation_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/sync_dao.dart';
import 'daos/gamification_dao.dart';

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
  ],
  daos: [
    CurriculumDao,
    VocabularyDao,
    ConversationDao,
    ProgressDao,
    SyncDao,
    GamificationDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing — inject an in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  /// Version 2 adds explicit lesson outcomes and recycling metadata.
  int get schemaVersion => 2;

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
  };

  /// Removes learner-created state before an account switch or after account
  /// deletion. Bundled curriculum/grammar/vocabulary remain available offline.
  Future<void> clearLearnerData() => transaction(clearLearnerDataRows);

  /// Clears learner-owned rows in the caller's current transaction.
  ///
  /// Account switching uses this inside a larger transaction so a failed
  /// remote install restores the previous account's complete local state.
  Future<void> clearLearnerDataRows() async {
    await delete(chatMessages).go();
    await delete(conversations).go();
    await delete(examResults).go();
    await delete(consentRecords).go();
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
      if (from < 2) {
        await m.addColumn(lessons, lessons.canDo);
        await m.addColumn(lessons, lessons.newLanguageJson);
        await m.addColumn(lessons, lessons.recyclesJson);
        await m.addColumn(lessons, lessons.exitTask);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
