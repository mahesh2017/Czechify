import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import '../database/database.dart' as db;
import '../content/curriculum_pack_source.dart';

/// Synchronizes the Supabase curriculum snapshot into the local Drift database.
class ContentSeeder {
  final db.AppDatabase _db;
  final CurriculumPackSource _source;
  final _log = Logger('ContentSeeder');

  /// Unit ids present in the remote unit packs — used to validate
  /// unit references in other content so one dangling reference
  /// (e.g. vocabulary for a unit that isn't written yet) can't
  /// FK-fail and roll back the whole content sync.
  final Set<int> _validUnitIds = {};

  /// Lesson ids present in the remote lesson packs — used to validate the
  /// per-word `lesson_id` gating reference the same way unit ids are checked.
  final Set<int> _validLessonIds = {};

  int? _validatedUnitId(Object? raw, String what) {
    if (raw == null) return null;
    final id = (raw as num).toInt();
    if (_validUnitIds.contains(id)) return id;
    _log.warning('$what references missing unit $id — keeping it unlinked.');
    return null;
  }

  int? _validatedLessonId(Object? raw, String what) {
    if (raw == null) return null;
    final id = (raw as num).toInt();
    if (_validLessonIds.contains(id)) return id;
    _log.warning('$what references missing lesson $id — keeping it unlinked.');
    return null;
  }

  ContentSeeder(this._db, this._source);

  /// Whether the local database contains the complete minimum course shape.
  /// This validates more than a marker flag, so interrupted/partial installs
  /// are repaired on the next launch.
  Future<bool> hasUsableLocalContent() async {
    final row =
        await _db.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM units
          WHERE id BETWEEN 1 AND 31 AND is_active = 1) AS unit_count,
        (SELECT COUNT(*) FROM lessons WHERE is_active = 1) AS lesson_count,
        (SELECT COUNT(*) FROM exercises WHERE is_active = 1) AS exercise_count,
        (SELECT COUNT(*) FROM flashcards WHERE is_active = 1) AS flashcard_count
    ''').getSingle();
    return row.read<int>('unit_count') == 31 &&
        row.read<int>('lesson_count') >= _lessonFilePaths.length &&
        row.read<int>('exercise_count') > 0 &&
        row.read<int>('flashcard_count') > 0;
  }

  /// Ensure first launch works without a network connection.
  Future<void> ensureBundledContent() async {
    if (await hasUsableLocalContent()) return;
    await _source.loadBundled(requiredPackPaths);
    await _installCurrentSnapshot('bundled');
  }

  /// Apply a complete remote snapshot. Call this after backend initialization;
  /// failures are intentionally handled by the background caller.
  Future<void> refreshFromRemote() async {
    await _source.refreshRemote(requiredPackPaths);
    await installVerifiedRelease();
  }

  /// Install the release currently held by [CurriculumPackSource]. Exposed for
  /// controlled recovery and integration tests; the source verifies it first.
  Future<void> installVerifiedRelease() async {
    try {
      await _installCurrentSnapshot('verified release');
    } catch (_) {
      await _restoreActiveSource();
      rethrow;
    }
  }

  /// Reinstall the immediately previous verified release without a network
  /// request. Returns false when no rollback target is retained.
  Future<bool> rollbackToPreviousRelease() async {
    final previous =
        await (_db.select(_db.contentReleaseInstallations)
          ..where((row) => row.isPrevious.equals(true))).getSingleOrNull();
    if (previous == null) return false;
    await _loadStoredRelease(previous);
    await _installCurrentSnapshot('rollback');
    return true;
  }

  Future<void> _restoreActiveSource() async {
    final active =
        await (_db.select(_db.contentReleaseInstallations)
          ..where((row) => row.isActive.equals(true))).getSingleOrNull();
    if (active != null) await _loadStoredRelease(active);
  }

  Future<void> _loadStoredRelease(db.ContentReleaseInstallation stored) async {
    final rows =
        await (_db.select(_db.contentReleasePacks)
          ..where((row) => row.releaseId.equals(stored.releaseId))).get();
    final packs = <String, VerifiedContentPack>{
      for (final row in rows)
        row.packKey: (
          version: row.packVersion,
          checksum: row.checksum,
          content: jsonDecode(row.content),
        ),
    };
    _source.loadCachedRelease(
      release: ContentRelease(
        releaseId: stored.releaseId,
        version: stored.version,
        contentChecksum: stored.contentChecksum,
        packRefs:
            rows
                .map(
                  (row) => PackRef(
                    packKey: row.packKey,
                    version: row.packVersion,
                    checksum: row.checksum,
                  ),
                )
                .toList(),
        notes: stored.notes,
      ),
      requiredPackKeys: requiredPackPaths,
      packs: packs,
    );
  }

  /// Install the selected source snapshot as one database commit. All packs
  /// have already been loaded and validated before this transaction starts.
  Future<void> _installCurrentSnapshot(String sourceName) async {
    _log.info('Installing $sourceName curriculum snapshot...');
    _validUnitIds.clear();
    _validLessonIds.clear();
    await Future<void>.delayed(Duration.zero);
    await _db.transaction(() async {
      await _retireManagedContent();
      await _seedUnits();
      await _seedGrammarRules();
      await _seedLessons();
      await _seedVocabulary();
      await _createMissingSrsCards();
      await _recordInstalledRelease();
    });
    _log.info('$sourceName curriculum snapshot installed.');
  }

  Future<void> _retireManagedContent() async {
    await _db
        .update(_db.exercises)
        .write(const db.ExercisesCompanion(isActive: Value(false)));
    await _db
        .update(_db.lessons)
        .write(const db.LessonsCompanion(isActive: Value(false)));
    await _db
        .update(_db.grammarRules)
        .write(const db.GrammarRulesCompanion(isActive: Value(false)));
    await (_db.update(_db.flashcards)..where(
      (row) => row.id.isSmallerOrEqualValue(900000),
    )).write(const db.FlashcardsCompanion(isActive: Value(false)));
    await _db
        .update(_db.units)
        .write(const db.UnitsCompanion(isActive: Value(false)));
  }

  Future<void> _recordInstalledRelease() async {
    final release = _source.currentRelease;
    if (release == null) return;
    final packs = _source.verifiedPacks;
    if (packs.length != requiredPackPaths.length) {
      throw StateError('Cannot activate an incomplete release cache.');
    }

    final current =
        await (_db.select(_db.contentReleaseInstallations)
          ..where((row) => row.isActive.equals(true))).getSingleOrNull();
    await _db
        .update(_db.contentReleaseInstallations)
        .write(
          const db.ContentReleaseInstallationsCompanion(
            isActive: Value(false),
            isPrevious: Value(false),
          ),
        );
    if (current != null && current.releaseId != release.releaseId) {
      await (_db.update(_db.contentReleaseInstallations)
        ..where((row) => row.releaseId.equals(current.releaseId))).write(
        const db.ContentReleaseInstallationsCompanion(isPrevious: Value(true)),
      );
    }
    await _db
        .into(_db.contentReleaseInstallations)
        .insertOnConflictUpdate(
          db.ContentReleaseInstallationsCompanion.insert(
            releaseId: release.releaseId,
            version: release.version,
            contentChecksum: release.contentChecksum,
            notes: Value(release.notes),
            isActive: const Value(true),
            isPrevious: const Value(false),
            installedAt: DateTime.now().toUtc(),
          ),
        );
    await (_db.delete(_db.contentReleasePacks)
      ..where((row) => row.releaseId.equals(release.releaseId))).go();
    await _db.batch((batch) {
      batch.insertAll(
        _db.contentReleasePacks,
        packs.entries
            .map(
              (entry) => db.ContentReleasePacksCompanion.insert(
                releaseId: release.releaseId,
                packKey: entry.key,
                packVersion: entry.value.version,
                checksum: entry.value.checksum,
                content: jsonEncode(entry.value.content),
              ),
            )
            .toList(),
      );
    });
    final retainedIds =
        await (_db.selectOnly(_db.contentReleaseInstallations)
              ..addColumns([_db.contentReleaseInstallations.releaseId])
              ..where(
                _db.contentReleaseInstallations.isActive.equals(true) |
                    _db.contentReleaseInstallations.isPrevious.equals(true),
              ))
            .map((row) => row.read(_db.contentReleaseInstallations.releaseId)!)
            .get();
    await (_db.delete(_db.contentReleasePacks)
      ..where((row) => row.releaseId.isNotIn(retainedIds))).go();
    await (_db.delete(_db.contentReleaseInstallations)
      ..where((row) => row.releaseId.isNotIn(retainedIds))).go();
  }

  /// Coerce a JSON value into a nullable String for a text column.
  ///
  /// Lesson content authors sometimes express `answer_key` as an int
  /// (multiple-choice index) or a list (accepted answers) rather than a
  /// plain string. Preserve those non-destructively by JSON-encoding them
  /// instead of failing the whole content sync with a cast error.
  static String? _asNullableString(Object? value) => switch (value) {
    null => null,
    final String s => s,
    final other => jsonEncode(other),
  };

  /// Load and insert all units (A1 + A2).
  Future<void> _seedUnits() async {
    // A1 units
    final a1Json = await _loadAsset('assets/curriculum/a1_units.json');
    final a1Units =
        (jsonDecode(a1Json)['units'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

    final a1Companions = a1Units.map(
      (u) => db.UnitsCompanion.insert(
        id: Value(u['id'] as int),
        title: u['title'] as String,
        description: u['description'] as String,
        phase: u['phase'] as String,
        orderIndex: u['order_index'] as int,
        grammarTags: Value((u['grammar_tags'] as List<dynamic>).join(',')),
        isExamPrep: Value(u['is_exam_prep'] as bool? ?? false),
        isActive: const Value(true),
      ),
    );

    await _db.curriculumDao.insertUnits(a1Companions.toList());
    _validUnitIds.addAll(a1Units.map((u) => u['id'] as int));

    // A2 units
    final a2Json = await _loadAsset('assets/curriculum/a2_units.json');
    final a2Units =
        (jsonDecode(a2Json)['units'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

    final a2Companions = a2Units.map(
      (u) => db.UnitsCompanion.insert(
        id: Value(u['id'] as int),
        title: u['title'] as String,
        description: u['description'] as String,
        phase: u['phase'] as String,
        orderIndex: u['order_index'] as int,
        grammarTags: Value((u['grammar_tags'] as List<dynamic>).join(',')),
        isExamPrep: Value(u['is_exam_prep'] as bool? ?? false),
        isActive: const Value(true),
      ),
    );

    await _db.curriculumDao.insertUnits(a2Companions.toList());
    _validUnitIds.addAll(a2Units.map((u) => u['id'] as int));

    // NOTE: _seedLessons was moved to its own step in seedIfNeeded()
    // so each batch of lesson files gets its own transaction + yield.
  }

  Future<void> _seedLessons() async {
    for (final filePath in _lessonFilePaths) {
      final json = await _loadAsset(filePath);
      {
        final lessonData = jsonDecode(json) as Map<String, dynamic>;
        _validLessonIds.add(lessonData['id'] as int);
        await _db.curriculumDao.insertLessons([
          db.LessonsCompanion.insert(
            id: Value(lessonData['id'] as int),
            unitId: lessonData['unit_id'] as int,
            orderInUnit: lessonData['order_in_unit'] as int,
            title: lessonData['title'] as String,
            description: lessonData['description'] as String,
            durationMinutes: Value(lessonData['duration_min'] as int? ?? 10),
            lessonType: Value(
              lessonData['lesson_type'] as String? ?? 'introduction',
            ),
            isReview: Value(lessonData['is_review'] as bool? ?? false),
            isActive: const Value(true),
          ),
        ]);

        final exercises = (lessonData['exercises'] as List<dynamic>?) ?? [];
        if (exercises.isNotEmpty) {
          await _db.curriculumDao.insertExercises(
            exercises
                .map(
                  (e) => db.ExercisesCompanion.insert(
                    id: Value((e as Map<String, dynamic>)['id'] as int),
                    lessonId: e['lesson_id'] as int,
                    type: e['type'] as String,
                    prompt: e['prompt'] as String,
                    data: jsonEncode(e['data']),
                    answerKey: Value(_asNullableString(e['answer_key'])),
                    grammarRuleId: Value(e['grammar_rule_id'] as String?),
                    xpReward: Value(e['xp_reward'] as int? ?? 10),
                    isActive: const Value(true),
                  ),
                )
                .toList(),
          );
        }

        _log.info('Loaded lesson: $filePath');
      }
    }
  }

  /// Shared list of all lesson asset file paths.
  static const _lessonFilePaths = <String>[
    // Unit 1: Sounds & Pronunciation
    'assets/curriculum/lessons/unit01_lesson00.json',
    'assets/curriculum/lessons/unit01_lesson01.json',
    'assets/curriculum/lessons/unit01_lesson02.json',
    // Unit 2: Greetings & Introductions
    'assets/curriculum/lessons/unit02_lesson01.json',
    'assets/curriculum/lessons/unit02_lesson02.json',
    // Unit 3: Gender & Nominative Case
    'assets/curriculum/lessons/unit03_lesson01.json',
    'assets/curriculum/lessons/unit03_lesson02.json',
    // Unit 4: Present Tense — být & mít
    'assets/curriculum/lessons/unit04_lesson01.json',
    'assets/curriculum/lessons/unit04_lesson02.json',
    // Unit 5: Present Tense — Regular Verbs
    'assets/curriculum/lessons/unit05_lesson01.json',
    'assets/curriculum/lessons/unit05_lesson02.json',
    // Unit 6: Accusative Case
    'assets/curriculum/lessons/unit06_lesson01.json',
    'assets/curriculum/lessons/unit06_lesson02.json',
    // Unit 7: Pronouns & Possessives
    'assets/curriculum/lessons/unit07_lesson01.json',
    'assets/curriculum/lessons/unit07_lesson02.json',
    // Unit 8: Family & Basic Descriptions
    'assets/curriculum/lessons/unit08_lesson01.json',
    'assets/curriculum/lessons/unit08_lesson02.json',
    // Unit 9: Numbers, Time & Dates
    'assets/curriculum/lessons/unit09_lesson01.json',
    'assets/curriculum/lessons/unit09_lesson02.json',
    // Unit 10: Daily Routine & Reflexive Verbs
    'assets/curriculum/lessons/unit10_lesson01.json',
    'assets/curriculum/lessons/unit10_lesson02.json',
    // Unit 11: Food, Drink & Restaurants
    'assets/curriculum/lessons/unit11_lesson01.json',
    'assets/curriculum/lessons/unit11_lesson02.json',
    // Unit 12: Shopping, Prices & Clothes
    'assets/curriculum/lessons/unit12_lesson01.json',
    'assets/curriculum/lessons/unit12_lesson02.json',
    // Unit 13: Hobbies & Free Time
    'assets/curriculum/lessons/unit13_lesson01.json',
    'assets/curriculum/lessons/unit13_lesson02.json',
    // Unit 14: Directions, Places & Transport
    'assets/curriculum/lessons/unit14_lesson01.json',
    'assets/curriculum/lessons/unit14_lesson02.json',
    // Unit 15: Weather, Seasons & Travel
    'assets/curriculum/lessons/unit15_lesson01.json',
    'assets/curriculum/lessons/unit15_lesson02.json',
    // A2 — Unit 16: Genitive Case
    'assets/curriculum/lessons/unit16_lesson01.json',
    'assets/curriculum/lessons/unit16_lesson02.json',
    // A2 — Unit 17: Dative Case
    'assets/curriculum/lessons/unit17_lesson01.json',
    'assets/curriculum/lessons/unit17_lesson02.json',
    // A2 — Unit 18: Locative & Instrumental Cases
    'assets/curriculum/lessons/unit18_lesson01.json',
    'assets/curriculum/lessons/unit18_lesson02.json',
    // A2 — Unit 19: Past Tense Full
    'assets/curriculum/lessons/unit19_lesson01.json',
    'assets/curriculum/lessons/unit19_lesson02.json',
    // A2 — Unit 20: Future & Conditional
    'assets/curriculum/lessons/unit20_lesson01.json',
    'assets/curriculum/lessons/unit20_lesson02.json',
    // A2 — Unit 21: Comparisons & Adverbs
    'assets/curriculum/lessons/unit21_lesson01.json',
    'assets/curriculum/lessons/unit21_lesson02.json',
    // A2 — Unit 22: Complex Sentences
    'assets/curriculum/lessons/unit22_lesson01.json',
    'assets/curriculum/lessons/unit22_lesson02.json',
    // A2 — Unit 23: Modal Verbs
    'assets/curriculum/lessons/unit23_lesson01.json',
    'assets/curriculum/lessons/unit23_lesson02.json',
    // A2 — Unit 24: Health & Body
    'assets/curriculum/lessons/unit24_lesson01.json',
    'assets/curriculum/lessons/unit24_lesson02.json',
    // A2 — Unit 25: Professions & Education
    'assets/curriculum/lessons/unit25_lesson01.json',
    'assets/curriculum/lessons/unit25_lesson02.json',
    // A2 — Unit 26: Housing & Home
    'assets/curriculum/lessons/unit26_lesson01.json',
    'assets/curriculum/lessons/unit26_lesson02.json',
    // A2 — Unit 27: Motion Verbs
    'assets/curriculum/lessons/unit27_lesson01.json',
    'assets/curriculum/lessons/unit27_lesson02.json',
    // A2 — Unit 28: A1 Exam Prep
    'assets/curriculum/lessons/unit28_lesson01.json',
    'assets/curriculum/lessons/unit28_lesson02.json',
    // A2 — Unit 29: A2 Exam Prep
    'assets/curriculum/lessons/unit29_lesson01.json',
    'assets/curriculum/lessons/unit29_lesson02.json',
    // A2 — Unit 30: A1 Review
    'assets/curriculum/lessons/unit30_lesson01.json',
    // A2 — Unit 31: A2 Review
    'assets/curriculum/lessons/unit31_lesson01.json',
  ];

  static final Set<String> requiredPackPaths = {
    'assets/curriculum/a1_units.json',
    'assets/curriculum/a2_units.json',
    'assets/curriculum/grammar_rules.json',
    'assets/vocabulary/a1_vocabulary.json',
    'assets/vocabulary/a2_vocabulary.json',
    ..._lessonFilePaths,
  };

  /// Load and insert grammar rules.
  Future<void> _seedGrammarRules() async {
    final json = await _loadAsset('assets/curriculum/grammar_rules.json');
    {
      final rules = jsonDecode(json) as Map<String, dynamic>;

      if (rules.isEmpty) {
        _log.fine('No grammar rules to seed.');
        return;
      }

      final ruleList = (rules['rules'] as List<dynamic>?) ?? [];
      if (ruleList.isEmpty) return;

      await _db.curriculumDao.insertGrammarRules(
        ruleList
            .map(
              (r) => db.GrammarRulesCompanion.insert(
                id: (r as Map<String, dynamic>)['id'] as String,
                ruleName: r['rule_name'] as String,
                pattern: r['pattern'] as String,
                explanation: r['explanation'] as String,
                caseAffected: Value(r['case_affected'] as String?),
                examples: Value(jsonEncode(r['examples'] ?? [])),
                unitId: Value(
                  _validatedUnitId(r['unit_id'], 'Grammar rule ${r['id']}'),
                ),
                isActive: const Value(true),
              ),
            )
            .toList(),
      );
    }
  }

  /// Load and upsert vocabulary flashcards.
  Future<void> _seedVocabulary() async {
    for (final level in ['a1', 'a2']) {
      final json = await _loadAsset(
        'assets/vocabulary/${level}_vocabulary.json',
      );
      {
        final words = jsonDecode(json) as List<dynamic>;

        if (words.isEmpty) continue;

        final flashcardCompanions =
            words
                .map(
                  (w) => db.FlashcardsCompanion.insert(
                    id: Value((w as Map<String, dynamic>)['id'] as int),
                    wordCz: w['word_cz'] as String,
                    wordEn: w['word_en'] as String,
                    ipa: Value(w['ipa'] as String?),
                    gender: Value(w['gender'] as String?),
                    caseInfo: Value(w['case_info'] as String?),
                    audioHash: Value(w['audio_hash'] as String?),
                    imagePath: Value(w['image_path'] as String?),
                    exampleCz: Value(w['example_cz'] as String?),
                    exampleEn: Value(w['example_en'] as String?),
                    lemma: Value(w['word_cz'] as String),
                    senseKey: Value(
                      '${(w['word_cz'] as String).trim().toLowerCase()}|'
                      '${(w['word_en'] as String).trim().toLowerCase()}',
                    ),
                    partOfSpeech: const Value('unspecified'),
                    morphologyJson: Value(
                      jsonEncode({
                        if (w['gender'] != null) 'gender': w['gender'],
                        if (w['case_info'] != null) 'case': w['case_info'],
                      }),
                    ),
                    registerLabel: const Value('unspecified'),
                    pronunciationSource: Value(
                      w['ipa'] == null ? 'missing' : 'bundled_unreviewed',
                    ),
                    unitId: Value(
                      _validatedUnitId(
                        w['unit_id'],
                        "Flashcard ${w['id']} '${w['word_cz']}'",
                      ),
                    ),
                    lessonId: Value(
                      _validatedLessonId(
                        w['lesson_id'],
                        "Flashcard ${w['id']} '${w['word_cz']}'",
                      ),
                    ),
                    isActive: const Value(true),
                  ),
                )
                .toList();

        await _db.vocabularyDao.insertFlashcards(flashcardCompanions);

        _log.info('Synced ${words.length} $level vocabulary words.');
      }
    }
  }

  /// Create SRS cards for any flashcard that doesn't have one yet —
  /// covers both first launch and vocabulary added in app updates.
  /// Existing SRS cards (and their scheduling state) are left untouched.
  Future<void> _createMissingSrsCards() async {
    final missingIds = await _db.vocabularyDao.flashcardIdsWithoutSrsCards();
    if (missingIds.isEmpty) return;

    for (final flashcardId in missingIds) {
      await _db.vocabularyDao.upsertSrsCard(
        db.SrsCardsCompanion.insert(
          cardType: 'vocabulary',
          flashcardId: Value(flashcardId),
          stability: const Value(0.0),
          difficulty: const Value(0.0),
          due: Value(DateTime.now()),
          reps: const Value(0),
          state: const Value('newCard'),
        ),
      );
    }

    _log.info('Created SRS cards for ${missingIds.length} new flashcards.');
  }

  /// Load a text asset, returning empty string if not found.
  Future<String> _loadAsset(String path) async {
    return _source.load(path);
  }
}
