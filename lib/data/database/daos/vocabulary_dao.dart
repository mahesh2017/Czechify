import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/flashcards.dart';
import '../tables/srs_cards.dart';
import '../tables/review_attempts.dart';
import '../tables/reward_ledger.dart';
import '../tables/gamification_state.dart';

part 'vocabulary_dao.g.dart';

/// Data access object for vocabulary + SRS card queries.
@DriftAccessor(
  tables: [
    Flashcards,
    SrsCards,
    ReviewAttempts,
    RewardLedger,
    GamificationStateTable,
  ],
)
class VocabularyDao extends DatabaseAccessor<AppDatabase>
    with _$VocabularyDaoMixin {
  VocabularyDao(super.db);

  // ── Flashcards ──

  Future<List<Flashcard>> getAllFlashcards() =>
      (select(flashcards)..where((f) => f.isActive.equals(true))).get();

  Future<List<Flashcard>> getFlashcardsByUnit(int unitId) {
    return (select(flashcards)
      ..where((f) => f.unitId.equals(unitId) & f.isActive.equals(true))).get();
  }

  Future<List<Flashcard>> getFlashcardsByLesson(int lessonId) {
    return (select(flashcards)..where(
      (f) => f.lessonId.equals(lessonId) & f.isActive.equals(true),
    )).get();
  }

  Future<List<Flashcard>> getFlashcardsByIds(List<int> ids) {
    if (ids.isEmpty) return Future.value([]);
    return (select(flashcards)
      ..where((f) => f.id.isIn(ids) & f.isActive.equals(true))).get();
  }

  Future<List<Flashcard>> searchFlashcards(String query) {
    return (select(flashcards)..where(
      (f) =>
          (f.wordCz.like('%$query%') | f.wordEn.like('%$query%')) &
          f.isActive.equals(true),
    )).get();
  }

  /// Upsert (update-in-place on conflict) so vocabulary edits in app
  /// updates propagate without breaking the FK from srs_cards.
  Future<void> insertFlashcards(List<FlashcardsCompanion> cardList) =>
      batch((b) => b.insertAllOnConflictUpdate(flashcards, cardList));

  /// Next free flashcard id — user-added cards (e.g. from chat) get ids
  /// above the seeded content so they never collide with content updates.
  Future<int> nextFlashcardId() async {
    final r =
        await customSelect(
          'SELECT COALESCE(MAX(id), 0) AS m FROM flashcards',
        ).getSingle();
    // Keep manual cards well clear of the seeded id range.
    final maxId = r.read<int>('m');
    return (maxId < 900000 ? 900000 : maxId) + 1;
  }

  Future<Flashcard?> findByWordCz(String wordCz) async {
    final rows =
        await (select(flashcards)..where(
          (f) =>
              f.wordCz.lower().equals(wordCz.toLowerCase()) &
              f.isActive.equals(true),
        )).get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Flashcards that don't have an SRS card yet (new content).
  Future<List<int>> flashcardIdsWithoutSrsCards() async {
    final rows =
        await customSelect(
          'SELECT f.id AS id FROM flashcards f '
          'LEFT JOIN srs_cards s ON s.flashcard_id = f.id '
          'WHERE s.id IS NULL AND f.is_active = 1',
        ).get();
    return rows.map((r) => r.read<int>('id')).toList();
  }

  // ── SRS Cards ──

  Future<List<SrsCard>> getDueCards(DateTime asOf) {
    return (select(srsCards)
          ..where((s) => s.due.isSmallerOrEqualValue(asOf))
          ..orderBy([(s) => OrderingTerm.asc(s.due)]))
        .get();
  }

  Future<int> getDueCount(DateTime asOf) async {
    final result =
        await customSelect(
          'SELECT COUNT(*) AS c FROM srs_cards s '
          'JOIN flashcards f ON f.id = s.flashcard_id '
          'WHERE s.due <= ? AND f.is_active = 1',
          variables: [Variable.withDateTime(asOf)],
        ).getSingle();
    return result.read<int>('c');
  }

  /// Atomic upsert by the card's domain identity, never its local row ID.
  Future<void> upsertSrsCard(SrsCardsCompanion card) =>
      attachedDatabase.transaction(() async {
        final cardType = card.cardType.value;
        final flashcardId =
            card.flashcardId.present ? card.flashcardId.value : null;
        final grammarKey =
            card.grammarPatternKey.present
                ? card.grammarPatternKey.value
                : null;

        final existing =
            await (select(srsCards)..where(
              (row) =>
                  cardType == 'grammar'
                      ? (row.cardType.equals('grammar') &
                          row.grammarPatternKey.equals(grammarKey ?? ''))
                      : (row.cardType.equals('vocabulary') &
                          row.flashcardId.equals(flashcardId ?? -1)),
            )).getSingleOrNull();

        if (existing == null) {
          await into(srsCards).insert(card);
          return;
        }
        await (update(srsCards)..where(
          (row) => row.id.equals(existing.id),
        )).write(card.copyWith(id: Value(existing.id)));
      });

  Future<int> srsCardCount() async {
    final result =
        await customSelect('SELECT COUNT(*) AS c FROM srs_cards').getSingle();
    return result.read<int>('c');
  }

  Future<void> updateSrsCard(SrsCardsCompanion card) =>
      attachedDatabase.transaction(() async {
        final id = card.id.value;
        await (update(srsCards)..where((s) => s.id.equals(id))).write(card);
        await _enqueueSrsCard(id);
      });

  /// Commits one idempotent rating together with its scheduled card state.
  Future<bool> commitSrsReview({
    required String reviewId,
    required SrsCardsCompanion card,
    required String rating,
    required DateTime reviewedAt,
    required bool introducedNewCard,
  }) => attachedDatabase.transaction(() async {
    final duplicate =
        await (select(reviewAttempts)
          ..where((row) => row.reviewId.equals(reviewId))).getSingleOrNull();
    if (duplicate != null) return false;

    final id = card.id.value;
    final changed = await (update(srsCards)
      ..where((row) => row.id.equals(id))).write(card);
    if (changed != 1) {
      throw StateError('SRS card $id no longer exists');
    }
    await into(reviewAttempts).insert(
      ReviewAttemptsCompanion.insert(
        reviewId: reviewId,
        srsCardId: id,
        rating: rating,
        reviewedAt: reviewedAt,
        introducedNewCard: Value(introducedNewCard),
      ),
    );

    // The immutable review and its reward are one commit. A retry with the
    // same review id returns above, so delayed taps or redelivery cannot
    // award XP twice.
    final activityXp = switch (rating) {
      'hard' => 1,
      'good' => 2,
      'easy' => 3,
      _ => 0,
    };
    await into(rewardLedger).insert(
      RewardLedgerCompanion.insert(
        rewardId: 'review:$reviewId',
        sourceId: reviewId,
        rewardType: 'review_rating',
        xp: activityXp,
        awardedAt: reviewedAt,
      ),
    );

    final gamification =
        await (select(gamificationStateTable)
          ..where((row) => row.key.equals('primary'))).getSingleOrNull();
    final day =
        DateTime(
          reviewedAt.year,
          reviewedAt.month,
          reviewedAt.day,
        ).toIso8601String();
    final priorDailyXp =
        gamification?.dailyXpResetDate == day ? gamification?.dailyXp ?? 0 : 0;
    await into(gamificationStateTable).insertOnConflictUpdate(
      GamificationStateTableCompanion.insert(
        key: 'primary',
        hearts: Value(gamification?.hearts ?? 5),
        maxHearts: Value(gamification?.maxHearts ?? 5),
        currentStreak: Value(gamification?.currentStreak ?? 0),
        longestStreak: Value(gamification?.longestStreak ?? 0),
        totalXp: Value((gamification?.totalXp ?? 0) + activityXp),
        dailyXp: Value(priorDailyXp + activityXp),
        dailyGoalXp: Value(gamification?.dailyGoalXp ?? 50),
        gems: Value(gamification?.gems ?? 0),
        earnedBadges: Value(gamification?.earnedBadges ?? '[]'),
        lastHeartRefill: Value(gamification?.lastHeartRefill),
        streakFreezeAvailable: Value(
          gamification?.streakFreezeAvailable ?? true,
        ),
        lastOpenDate: Value(gamification?.lastOpenDate),
        dailyXpResetDate: Value(day),
        updatedAt: Value(reviewedAt),
      ),
    );
    await _enqueueSrsCard(id);
    return true;
  });

  Future<int> introducedCardCountForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final count = reviewAttempts.reviewId.count();
    final query =
        selectOnly(reviewAttempts)
          ..addColumns([count])
          ..where(
            reviewAttempts.introducedNewCard.equals(true) &
                reviewAttempts.reviewedAt.isBiggerOrEqualValue(start) &
                reviewAttempts.reviewedAt.isSmallerThanValue(end),
          );
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Append the current SRS state of card [id] to the sync outbox, keyed by
  /// content (flashcard id or grammar pattern key) so it stays stable across
  /// devices — never the local autoincrement id.
  Future<void> _enqueueSrsCard(int id) async {
    final row =
        await (select(srsCards)
          ..where((s) => s.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final contentKey =
        row.cardType == 'grammar'
            ? row.grammarPatternKey
            : await _vocabularyContentKey(row.flashcardId);
    if (contentKey == null) return; // malformed card; nothing stable to key on
    await attachedDatabase.syncDao.enqueue(
      entity: 'srs_cards',
      entityKey: '${row.cardType}:$contentKey',
      payload: {
        'card_type': row.cardType,
        'content_key': contentKey,
        'stability': row.stability,
        'difficulty': row.difficulty,
        'due': row.due.toUtc().toIso8601String(),
        'reps': row.reps,
        'state': row.state,
        'last_reviewed': row.lastReviewed?.toUtc().toIso8601String(),
      },
    );
  }

  /// Stable cross-device content key for a vocabulary SRS card. Manual cards
  /// carry a UUID [Flashcards.contentUid] that is identical on every device;
  /// managed/seeded cards have none and use their deterministic seeded id.
  /// Never the local autoincrement id for a manual card — that collides across
  /// devices (each allocates from MAX(id)+1).
  Future<String?> _vocabularyContentKey(int? flashcardId) async {
    if (flashcardId == null) return null;
    final card =
        await (select(flashcards)
          ..where((f) => f.id.equals(flashcardId))).getSingleOrNull();
    if (card == null) return null;
    return card.contentUid ?? flashcardId.toString();
  }

  /// Merge remote SRS state for one card (pull). Keyed by content, not local
  /// id. Newer [lastReviewed] wins; a card missing locally is created. Writes
  /// directly, bypassing the outbox hook so pulls don't echo back.
  Future<void> mergeSrsCard({
    required String cardType,
    required String contentKey,
    required double stability,
    required double difficulty,
    required DateTime due,
    required int reps,
    required String state,
    DateTime? lastReviewed,
  }) async {
    final isGrammar = cardType == 'grammar';
    int? flashcardId;
    if (!isGrammar) {
      // A numeric key is a managed/seeded card (deterministic id on every
      // device). A non-numeric key is a manual card's stable content_uid,
      // resolved to whatever local flashcard row holds that UUID. If the
      // definition has not been materialized yet (custom_cards merges first,
      // but be defensive), skip rather than mis-attach.
      flashcardId = int.tryParse(contentKey);
      if (flashcardId == null) {
        final card =
            await (select(
              flashcards,
            )..where((f) => f.contentUid.equals(contentKey))).getSingleOrNull();
        if (card == null) return;
        flashcardId = card.id;
      }
    }

    final existing =
        await (select(srsCards)..where(
          (s) =>
              isGrammar
                  ? (s.cardType.equals('grammar') &
                      s.grammarPatternKey.equals(contentKey))
                  : (s.flashcardId.equals(flashcardId!)),
        )).getSingleOrNull();

    if (existing == null) {
      await into(srsCards).insert(
        SrsCardsCompanion.insert(
          cardType: cardType,
          flashcardId: Value(flashcardId),
          grammarPatternKey: Value(isGrammar ? contentKey : null),
          stability: Value(stability),
          difficulty: Value(difficulty),
          due: Value(due),
          reps: Value(reps),
          state: Value(state),
          lastReviewed: Value(lastReviewed),
        ),
      );
      return;
    }

    // Newer review wins. A null local lastReviewed is treated as oldest.
    final localTime = existing.lastReviewed;
    final remoteWins =
        localTime == null ||
        (lastReviewed != null && lastReviewed.isAfter(localTime));
    if (!remoteWins) return;

    await (update(srsCards)..where((s) => s.id.equals(existing.id))).write(
      SrsCardsCompanion(
        stability: Value(stability),
        difficulty: Value(difficulty),
        due: Value(due),
        reps: Value(reps),
        state: Value(state),
        lastReviewed: Value(lastReviewed),
      ),
    );
  }

  /// Append a manual card's definition to the sync outbox, keyed by its stable
  /// [Flashcards.contentUid]. Enqueued at creation so it precedes (FIFO) any
  /// later SRS review row that references it — the definition therefore syncs
  /// before the dependent scheduling row.
  Future<void> enqueueCustomCard(int flashcardId) async {
    final card =
        await (select(flashcards)
          ..where((f) => f.id.equals(flashcardId))).getSingleOrNull();
    if (card?.contentUid == null) return; // not a manual card
    await attachedDatabase.syncDao.enqueue(
      entity: 'custom_cards',
      entityKey: card!.contentUid!,
      payload: {
        'content_uid': card.contentUid,
        'word_cz': card.wordCz,
        'word_en': card.wordEn,
        'ipa': card.ipa,
      },
    );
  }

  /// Merge a remote manual-card definition (pull). Materializes a local
  /// flashcard keyed by [contentUid] if absent so the matching SRS row can
  /// attach; otherwise updates the word fields. Writes directly, bypassing the
  /// outbox so pulls do not echo back.
  Future<void> mergeCustomCard({
    required String contentUid,
    required String wordCz,
    required String wordEn,
    String? ipa,
  }) async {
    final existing =
        await (select(flashcards)
          ..where((f) => f.contentUid.equals(contentUid))).getSingleOrNull();
    if (existing != null) {
      await (update(flashcards)..where((f) => f.id.equals(existing.id))).write(
        FlashcardsCompanion(
          wordCz: Value(wordCz),
          wordEn: Value(wordEn),
          ipa: Value(ipa),
        ),
      );
      return;
    }
    final id = await nextFlashcardId();
    await into(flashcards).insert(
      FlashcardsCompanion.insert(
        id: Value(id),
        wordCz: wordCz,
        wordEn: wordEn,
        ipa: Value(ipa),
        contentUid: Value(contentUid),
      ),
    );
  }

  // ── Seed helpers ──

  Future<bool> isVocabularySeeded() async {
    final result =
        await customSelect('SELECT COUNT(*) AS c FROM flashcards').getSingle();
    return result.read<int>('c') > 0;
  }
}
