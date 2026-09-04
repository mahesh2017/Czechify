import 'dart:convert';

import 'package:czechify/data/content/curriculum_pack_source.dart';
import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/seeds/content_seeder.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const verifier = ContentReleaseVerifier();

  Future<ContentRelease> loadRelease(
    CurriculumPackSource source, {
    required String releaseId,
    required int version,
    required String firstUnitTitle,
    bool includeRetirableExercise = false,
  }) async {
    final packs = <String, VerifiedContentPack>{};
    for (final key in ContentSeeder.requiredPackPaths) {
      final content = jsonDecode(await rootBundle.loadString(key)) as Object?;
      if (key == 'assets/curriculum/a1_units.json') {
        final map = content as Map<String, dynamic>;
        (map['units'] as List<dynamic>).first['title'] = firstUnitTitle;
      }
      if (includeRetirableExercise &&
          key ==
              'assets/curriculum/lessons/'
                  'unit01_lesson01.json') {
        final map = content as Map<String, dynamic>;
        (map['exercises'] as List<dynamic>).add({
          'id': 888001,
          'lesson_id': 101,
          'type': 'multiple_choice',
          'prompt': 'Release-specific exercise',
          'data': {
            'type': 'multiple_choice',
            'question_cz': 'Jedna?',
            'question_en': 'One?',
            'options': ['jedna', 'dva'],
            'correct_index': 0,
            'explanation': 'Release-specific content.',
          },
          'answer_key': '0',
          'xp_reward': 10,
        });
      }
      packs[key] = (
        version: version,
        checksum: verifier.checksum(content),
        content: content,
      );
    }
    final refs =
        packs.entries
            .map(
              (entry) => PackRef(
                packKey: entry.key,
                version: entry.value.version,
                checksum: entry.value.checksum,
              ),
            )
            .toList();
    final release = ContentRelease(
      releaseId: releaseId,
      version: version,
      contentChecksum: verifier.aggregateChecksum(refs),
      packRefs: refs,
    );
    source.loadCachedRelease(
      release: release,
      requiredPackKeys: ContentSeeder.requiredPackPaths,
      packs: packs,
    );
    return release;
  }

  test('retains active and previous releases and rolls back offline', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final source = CurriculumPackSource(backend: BackendService());
    final seeder = ContentSeeder(database, source);

    await loadRelease(
      source,
      releaseId: 'release-1',
      version: 1,
      firstUnitTitle: 'Release one title',
      includeRetirableExercise: true,
    );
    await seeder.installVerifiedRelease();
    await loadRelease(
      source,
      releaseId: 'release-2',
      version: 2,
      firstUnitTitle: 'Release two title',
    );
    await seeder.installVerifiedRelease();

    expect(
      (await database.curriculumDao.getUnit(1))?.title,
      'Release two title',
    );
    expect(
      (await database.curriculumDao.getExercisesByLesson(
        101,
      )).where((exercise) => exercise.id == 888001),
      isEmpty,
    );
    var releases =
        await database.select(database.contentReleaseInstallations).get();
    expect(releases.where((row) => row.isActive).single.releaseId, 'release-2');
    expect(
      releases.where((row) => row.isPrevious).single.releaseId,
      'release-1',
    );

    expect(await seeder.rollbackToPreviousRelease(), isTrue);
    expect(
      (await database.curriculumDao.getUnit(1))?.title,
      'Release one title',
    );
    expect(
      (await database.curriculumDao.getExercisesByLesson(
        101,
      )).map((exercise) => exercise.id),
      contains(888001),
    );
    releases =
        await database.select(database.contentReleaseInstallations).get();
    expect(releases, hasLength(2));
    expect(releases.where((row) => row.isActive).single.releaseId, 'release-1');
    expect(
      releases.where((row) => row.isPrevious).single.releaseId,
      'release-2',
    );
  });

  test('failed install preserves content and active release pointer', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final source = CurriculumPackSource(backend: BackendService());
    final seeder = ContentSeeder(database, source);

    await loadRelease(
      source,
      releaseId: 'stable',
      version: 1,
      firstUnitTitle: 'Stable title',
    );
    await seeder.installVerifiedRelease();
    await database.customStatement('''
      CREATE TRIGGER reject_release_exercises
      BEFORE INSERT ON exercises
      BEGIN
        SELECT RAISE(ABORT, 'simulated release failure');
      END
    ''');
    await loadRelease(
      source,
      releaseId: 'broken',
      version: 2,
      firstUnitTitle: 'Broken title',
    );

    await expectLater(seeder.installVerifiedRelease(), throwsA(anything));

    expect((await database.curriculumDao.getUnit(1))?.title, 'Stable title');
    final releases =
        await database.select(database.contentReleaseInstallations).get();
    expect(releases, hasLength(1));
    expect(releases.single.releaseId, 'stable');
    expect(releases.single.isActive, isTrue);
    expect(source.currentRelease?.releaseId, 'stable');
  });

  test('third release prunes cache older than the rollback target', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final source = CurriculumPackSource(backend: BackendService());
    final seeder = ContentSeeder(database, source);

    for (var version = 1; version <= 3; version++) {
      await loadRelease(
        source,
        releaseId: 'release-$version',
        version: version,
        firstUnitTitle: 'Release $version',
      );
      await seeder.installVerifiedRelease();
    }

    final releases =
        await database.select(database.contentReleaseInstallations).get();
    expect(releases.map((row) => row.releaseId).toSet(), {
      'release-2',
      'release-3',
    });
    expect(releases.where((row) => row.isActive).single.releaseId, 'release-3');
    expect(
      releases.where((row) => row.isPrevious).single.releaseId,
      'release-2',
    );
    final cachedReleaseIds =
        (await database.select(database.contentReleasePacks).get())
            .map((row) => row.releaseId)
            .toSet();
    expect(cachedReleaseIds, {'release-2', 'release-3'});
  });

  test('retires removed content while preserving learner history', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final source = CurriculumPackSource(backend: BackendService());
    final seeder = ContentSeeder(database, source);

    await loadRelease(
      source,
      releaseId: 'release-1',
      version: 1,
      firstUnitTitle: 'Current content',
    );
    await seeder.installVerifiedRelease();
    await database
        .into(database.units)
        .insert(
          UnitsCompanion.insert(
            id: const Value(999),
            title: 'Retired unit',
            description: 'Historical',
            phase: 'a2',
            orderIndex: 999,
          ),
        );
    await database
        .into(database.lessons)
        .insert(
          LessonsCompanion.insert(
            id: const Value(99901),
            unitId: 999,
            orderInUnit: 0,
            title: 'Retired lesson',
            description: 'Historical',
          ),
        );
    await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: const Value(999001),
            lessonId: 99901,
            type: 'multiple_choice',
            prompt: 'Retired exercise',
            data: '{}',
          ),
        );
    await database
        .into(database.grammarRules)
        .insert(
          GrammarRulesCompanion.insert(
            id: 'GR-RETIRED',
            ruleName: 'Retired rule',
            pattern: 'old',
            explanation: 'Historical',
            unitId: const Value(999),
          ),
        );
    await database
        .into(database.flashcards)
        .insert(
          FlashcardsCompanion.insert(
            id: const Value(800000),
            wordCz: 'historické',
            wordEn: 'historical',
            unitId: const Value(999),
            lessonId: const Value(99901),
          ),
        );
    await database
        .into(database.srsCards)
        .insert(
          SrsCardsCompanion.insert(
            cardType: 'vocabulary',
            flashcardId: const Value(800000),
            due: Value(DateTime.utc(2026)),
          ),
        );
    await database
        .into(database.lessonProgress)
        .insert(
          LessonProgressCompanion.insert(
            lessonId: const Value(99901),
            unitId: 999,
            isCompleted: const Value(true),
          ),
        );
    await database
        .into(database.lessonAttempts)
        .insert(
          LessonAttemptsCompanion.insert(
            attemptId: 'historical-attempt',
            lessonId: 99901,
            unitId: 999,
            phase: 'initial',
            score: 1,
            correctCount: 1,
            incorrectCount: 0,
            skippedCount: 0,
            startedAt: DateTime.utc(2026),
            committedAt: DateTime.utc(2026),
          ),
        );
    await database
        .into(database.exerciseAttempts)
        .insert(
          ExerciseAttemptsCompanion.insert(
            presentationId: 'historical-presentation',
            lessonAttemptId: 'historical-attempt',
            exerciseId: 999001,
            phase: 'initial',
            outcome: 'correct',
            answeredAt: DateTime.utc(2026),
          ),
        );

    await loadRelease(
      source,
      releaseId: 'release-2',
      version: 2,
      firstUnitTitle: 'Replacement content',
    );
    await seeder.installVerifiedRelease();

    expect(await database.curriculumDao.getUnit(999), isNull);
    expect(await database.curriculumDao.getLesson(99901), isNull);
    expect(await database.curriculumDao.getExercisesByLesson(99901), isEmpty);
    expect(
      await database.curriculumDao.getGrammarRuleById('GR-RETIRED'),
      isNull,
    );
    expect(await database.vocabularyDao.getFlashcardsByIds([800000]), isEmpty);
    expect(
      (await database.select(database.units).get())
          .singleWhere((row) => row.id == 999)
          .isActive,
      isFalse,
    );
    expect(await database.vocabularyDao.srsCardCount(), greaterThan(0));
    expect(
      await database.vocabularyDao.getDueCount(DateTime.utc(2027)),
      lessThan(await database.vocabularyDao.srsCardCount()),
    );
    expect(
      await (database.select(database.lessonAttempts)..where(
        (row) => row.attemptId.equals('historical-attempt'),
      )).getSingleOrNull(),
      isNotNull,
    );
    expect(
      await (database.select(database.exerciseAttempts)..where(
        (row) => row.presentationId.equals('historical-presentation'),
      )).getSingleOrNull(),
      isNotNull,
    );
    expect(
      await (database.select(database.lessonProgress)
        ..where((row) => row.lessonId.equals(99901))).getSingleOrNull(),
      isNotNull,
    );
  });
}
