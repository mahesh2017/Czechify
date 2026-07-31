import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import '../../core/config/dev_flags.dart';
import '../../data/database/database.dart' as db;
import '../../domain/entities/unit.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/enums.dart';
import '../../domain/engines/curriculum_access_policy.dart';
import '../../domain/engines/learning_router.dart';
import '../../domain/entities/learning_evidence.dart';
import '../../l10n/app_localizations.dart';
import 'database_providers.dart';
import 'settings_providers.dart';
import '../models/curriculum_path_item.dart';

/// Provider for all units in a phase (A1 or A2).
final unitsProvider = FutureProvider.family<List<Unit>, Phase>((ref, phase) {
  final repo = ref.read(curriculumRepositoryProvider);
  return repo.getUnits(phase);
});

/// Provider for all units (A1 + A2 combined).
final allUnitsProvider = FutureProvider<List<Unit>>((ref) async {
  final repo = ref.read(curriculumRepositoryProvider);
  final a1 = await repo.getUnits(Phase.a1);
  final a2 = await repo.getUnits(Phase.a2);
  return [...a1, ...a2];
});

/// Provider for lessons in a specific unit.
final unitLessonsProvider = FutureProvider.family<List<Lesson>, int>((
  ref,
  unitId,
) {
  final repo = ref.read(curriculumRepositoryProvider);
  return repo.getLessons(unitId);
});

/// Provider for a single unit.
final unitProvider = FutureProvider.family<Unit, int>((ref, unitId) {
  final repo = ref.read(curriculumRepositoryProvider);
  return repo.getUnit(unitId);
});

/// Provider for a single lesson.
final lessonProvider = FutureProvider.family<Lesson, int>((ref, lessonId) {
  final repo = ref.read(curriculumRepositoryProvider);
  return repo.getLesson(lessonId);
});

/// Provider for the number of lessons per unit.
/// Used by the curriculum screen to show lesson counts.
final unitLessonCountProvider = FutureProvider.family<int, int>((
  ref,
  unitId,
) async {
  final lessons = await ref.read(unitLessonsProvider(unitId).future);
  return lessons.length;
});

/// Provider for completed lesson IDs.
/// Invalidate this after a lesson completes — dependents
/// ([unlockedUnitIdsProvider], [nextLessonProvider]) refresh automatically.
final completedLessonIdsProvider = FutureProvider<Set<int>>((ref) async {
  final progressRepo = ref.read(progressRepositoryProvider);
  return progressRepo.getCompletedLessonIds();
});

final placementProfileProvider = FutureProvider<db.PlacementProfile?>((ref) {
  final database = ref.read(databaseProvider);
  return database.select(database.placementProfiles).getSingleOrNull();
});

/// One explicit access graph for units, lessons, review introduction, direct
/// lesson entry, and continue-learning. XP is intentionally not an input.
final curriculumAccessProvider = FutureProvider<CurriculumAccess>((ref) async {
  final allUnits = await ref.watch(allUnitsProvider.future);
  final completedLessonIds = await ref.watch(completedLessonIdsProvider.future);
  final placement = await ref.watch(placementProfileProvider.future);
  final lessonsByUnit = <int, List<Lesson>>{};
  for (final unit in allUnits) {
    lessonsByUnit[unit.id] = await ref.watch(
      unitLessonsProvider(unit.id).future,
    );
  }
  final access = const CurriculumAccessPolicy().evaluate(
    orderedUnits: allUnits,
    lessonsByUnit: lessonsByUnit,
    completedLessonIds: completedLessonIds,
    provisionalThroughUnitId: placement?.provisionalUnit,
  );

  // Developer review mode: open every unit and lesson regardless of progress.
  // Off by default; enabled only with --dart-define=UNLOCK_ALL=true.
  if (DevFlags.unlockAll) {
    return CurriculumAccess(
      unlockedUnitIds: {for (final unit in allUnits) unit.id},
      unlockedLessonIds: {
        for (final lessons in lessonsByUnit.values)
          for (final lesson in lessons) lesson.id,
      },
      lessonPrerequisites: access.lessonPrerequisites,
    );
  }
  return access;
});

final unlockedUnitIdsProvider = FutureProvider<Set<int>>(
  (ref) async =>
      (await ref.watch(curriculumAccessProvider.future)).unlockedUnitIds,
);

final unlockedLessonIdsProvider = FutureProvider<Set<int>>(
  (ref) async =>
      (await ref.watch(curriculumAccessProvider.future)).unlockedLessonIds,
);

/// Joins authoritative curriculum data with UI-only path metadata.
final curriculumPathItemsProvider = FutureProvider<List<CurriculumPathItem>>((
  ref,
) async {
  final locale = ref.watch(settingsProvider.select((value) => value.locale));
  final l10n = lookupAppLocalizations(locale ?? const Locale('en'));
  final units = await ref.watch(allUnitsProvider.future);
  final access = await ref.watch(curriculumAccessProvider.future);
  final completed = await ref.watch(completedLessonIdsProvider.future);
  final result = <CurriculumPathItem>[];

  for (final phase in Phase.values) {
    final levelUnits = units.where((unit) => unit.phase == phase).toList();
    for (final (index, unit) in levelUnits.indexed) {
      final lessons = await ref.watch(unitLessonsProvider(unit.id).future);
      final completedCount =
          lessons.where((lesson) => completed.contains(lesson.id)).length;
      final unlocked = access.unlockedUnitIds.contains(unit.id);
      final state =
          lessons.isNotEmpty && completedCount == lessons.length
              ? CurriculumPathState.completed
              : !unlocked
              ? CurriculumPathState.locked
              : completedCount > 0 ||
                  lessons.any(
                    (lesson) => access.unlockedLessonIds.contains(lesson.id),
                  )
              ? CurriculumPathState.current
              : CurriculumPathState.available;
      result.add(
        CurriculumPathItem(
          unit: unit,
          lessons: lessons,
          state: state,
          section: CurriculumPathItem.sectionFor(
            unit,
            index,
            levelUnits.length,
            l10n,
          ),
          payoff: CurriculumPathItem.payoffFor(unit, l10n),
          durationMinutes: lessons.fold(
            0,
            (total, lesson) => total + lesson.durationMinutes,
          ),
          recommendation:
              state == CurriculumPathState.current ? 'Recommended next' : null,
        ),
      );
    }
  }
  return result;
});

final lessonUnlockedProvider = FutureProvider.family<bool, int>(
  (ref, lessonId) async => (await ref.watch(
    curriculumAccessProvider.future,
  )).unlockedLessonIds.contains(lessonId),
);

/// The next lesson the learner should continue with, plus its unit title.
class NextLessonInfo {
  final Lesson lesson;
  final String unitTitle;
  final String reason;

  const NextLessonInfo({
    required this.lesson,
    required this.unitTitle,
    this.reason = 'Continue with new accessible work',
  });
}

final learningEvidenceProvider = FutureProvider<List<LearningEvidence>>(
  (ref) => ref.read(databaseProvider).progressDao.getLearningEvidence(),
);

/// Evidence-driven next work. Delayed transfer and support dependence can
/// route a learner back to a completed lesson; XP is not an input.
final nextLessonProvider = FutureProvider<NextLessonInfo?>((ref) async {
  final allUnits = await ref.watch(allUnitsProvider.future);
  final unlockedLessonIds = await ref.watch(unlockedLessonIdsProvider.future);
  final completedLessonIds = await ref.watch(completedLessonIdsProvider.future);
  final evidence = await ref.watch(learningEvidenceProvider.future);
  final candidates = <LearningCandidate>[];
  final lessonById = <int, (Lesson, String)>{};
  var order = 0;

  for (final unit in allUnits) {
    final lessons = await ref.watch(unitLessonsProvider(unit.id).future);
    for (final lesson in lessons) {
      order++;
      if (!unlockedLessonIds.contains(lesson.id)) continue;
      final exercises = await ref
          .read(curriculumRepositoryProvider)
          .getExercises(lesson.id);
      final concepts = <String>{
        for (final exercise in exercises)
          if (exercise.grammarRuleId case final key?) key,
        for (final exercise in exercises)
          ...?((exercise.data['concept_tags'] as List?)?.whereType<String>()),
      };
      candidates.add(
        LearningCandidate(
          lessonId: lesson.id,
          order: order,
          completed: completedLessonIds.contains(lesson.id),
          skills: exercises.map((exercise) => _skillFor(exercise.type)).toSet(),
          conceptKeys: concepts,
        ),
      );
      lessonById[lesson.id] = (lesson, unit.title);
    }
  }
  final route = const LearningRouter().select(
    candidates: candidates,
    accessibleLessonIds: unlockedLessonIds,
    evidence: evidence,
  );
  if (route == null) return null;
  final selected = lessonById[route.lessonId];
  if (selected == null) return null;
  return NextLessonInfo(
    lesson: selected.$1,
    unitTitle: selected.$2,
    reason: route.reason,
  );
});

LearningSkill _skillFor(ExerciseType type) => switch (type) {
  ExerciseType.readingComprehension => LearningSkill.reading,
  ExerciseType.listening ||
  ExerciseType.listeningComprehension ||
  ExerciseType.dictation => LearningSkill.listening,
  ExerciseType.writingTask || ExerciseType.translation => LearningSkill.writing,
  ExerciseType.speakingTask ||
  ExerciseType.pronunciation ||
  ExerciseType.dialogue => LearningSkill.speaking,
  ExerciseType.matching => LearningSkill.vocabulary,
  _ => LearningSkill.grammar,
};

/// Provider for grammar rules for a specific unit.
final grammarRulesByUnitProvider =
    FutureProvider.family<List<db.GrammarRule>, int>((ref, unitId) {
      final database = ref.read(databaseProvider);
      return database.curriculumDao.getGrammarRulesByUnit(unitId);
    });
