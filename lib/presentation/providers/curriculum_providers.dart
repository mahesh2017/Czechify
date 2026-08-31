import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import '../../core/config/dev_flags.dart';
import '../../data/repositories/curriculum_entitlement_repository.dart';
import '../../data/database/database.dart' as db;
import '../../domain/entities/curriculum_entitlement.dart';
import '../../domain/entities/unit.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/enums.dart';
import '../../domain/engines/curriculum_access_policy.dart';
import '../../domain/engines/level_switch.dart';
import '../../domain/engines/learning_router.dart';
import '../../domain/entities/learning_evidence.dart';
import '../../l10n/app_localizations.dart';
import 'database_providers.dart';
import 'settings_providers.dart';
import 'sync_providers.dart';
import '../models/curriculum_path_item.dart';

/// Changes the learner's level after onboarding.
///
/// Deliberately one call rather than two settings writes, because the two
/// pieces of state that decide what a learner can open are easy to change
/// independently and useless apart. [AppSettings.startingLevel] drives chat
/// difficulty and which units prefetch for offline use; the placement
/// profile's provisional unit is what actually unlocks curriculum. Onboarding
/// wrote both and nothing wrote either again.
///
/// Returns true when the unlocked span moved, so the caller can offer to
/// download the new level's audio.
final levelSwitchProvider = Provider(
  (ref) => (CEFRLevel level) async {
    await ref.read(settingsProvider.notifier).setStartingLevel(level);

    final units = await ref.read(allUnitsProvider.future);
    final database = ref.read(databaseProvider);
    final placement =
        await database.select(database.placementProfiles).getSingleOrNull();
    final target = const LevelSwitch().provisionalUnitFor(
      units: units,
      level: level,
      currentProvisionalUnit: placement?.provisionalUnit,
    );

    // Null means the switch would move the ceiling down, so placement is left
    // exactly as it is — see [LevelSwitch.provisionalUnitFor]. The level still
    // changed, which is what the learner asked for.
    if (target != null) {
      await database.progressDao.setProvisionalUnit(target);
      ref.invalidate(placementProfileProvider);
      ref.invalidate(curriculumAccessProvider);
      ref.invalidate(nextLessonProvider);
    }
    return target != null;
  },
);

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

final _placementProfileChangesProvider = StreamProvider<db.PlacementProfile?>((
  ref,
) {
  final database = ref.read(databaseProvider);
  return database.select(database.placementProfiles).watchSingleOrNull();
});

/// Reactive placement state.
///
/// Placement can change outside the current widget flow when an ordinary
/// background sync merges another device's result. Watching the Drift query
/// keeps this provider, curriculum access, and continue-learning routing in
/// step with that merge without requiring the sync layer to know about UI
/// providers. Keeping the public provider asynchronous-but-single-valued also
/// lets command providers safely `read(...future)` before a widget is listening.
final placementProfileProvider = FutureProvider<db.PlacementProfile?>((ref) {
  final placement = ref.watch(_placementProfileChangesProvider);
  return switch (placement) {
    AsyncData(:final value) => Future.value(value),
    AsyncError(:final error, :final stackTrace) =>
      Future<db.PlacementProfile?>.error(error, stackTrace),
    _ => ref.watch(_placementProfileChangesProvider.future),
  };
});

final curriculumEntitlementRepositoryProvider =
    Provider<CurriculumEntitlementRepository>((ref) {
      final backend = ref.watch(backendServiceProvider);
      return CurriculumEntitlementRepository(
        fetchRemote: (userId) async {
          final client = backend.client;
          if (client == null) {
            throw StateError('Curriculum entitlement backend unavailable.');
          }
          final row = await client
              .from('curriculum_entitlements')
              .select('unlock_all, expires_at, reason')
              .eq('user_id', userId)
              .maybeSingle()
              .timeout(const Duration(seconds: 4));
          return row;
        },
      );
    });

/// Server-owned access used for reviewers and support cases. The repository
/// falls back to the last result for this exact auth user while offline.
final curriculumEntitlementProvider = FutureProvider<CurriculumEntitlement>((
  ref,
) async {
  await ref.watch(backendInitProvider.future);
  final backend = ref.watch(backendServiceProvider);
  if (!backend.isEnabled) return CurriculumEntitlement.none;
  final entitlement = await ref
      .watch(curriculumEntitlementRepositoryProvider)
      .load(backend.userId);
  final expiresAt = entitlement.expiresAt;
  if (expiresAt != null) {
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining > Duration.zero) {
      final timer = Timer(remaining, ref.invalidateSelf);
      ref.onDispose(timer.cancel);
    }
  }
  return entitlement;
});

/// One explicit access graph for units, lessons, review introduction, direct
/// lesson entry, and continue-learning. XP is intentionally not an input.
final curriculumAccessProvider = FutureProvider<CurriculumAccess>((ref) async {
  final allUnits = await ref.watch(allUnitsProvider.future);
  final completedLessonIds = await ref.watch(completedLessonIdsProvider.future);
  final placement = await ref.watch(placementProfileProvider.future);
  final entitlement = await ref.watch(curriculumEntitlementProvider.future);
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
    unlockAll:
        DevFlags.unlockAll || entitlement.isActiveAt(DateTime.now().toUtc()),
  );
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
