import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/engines/continue_lesson_selector.dart';
import '../../domain/engines/course_access_policy.dart';
import '../../domain/engines/lesson_admission_policy.dart';
import '../../domain/entities/course_catalog.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/lesson.dart';
import 'billing_providers.dart';
import 'curriculum_providers.dart';
import 'database_providers.dart';
import 'monetization_providers.dart';
import 'sync_providers.dart';

export '../../domain/engines/lesson_admission_policy.dart' show LessonAdmission;

/// Turns on the commercial course gate in internal and staging builds before
/// the server enables it for a cohort. Access still comes only from the
/// signed entitlement snapshot.
const paywallPreview = bool.fromEnvironment('MONETIZATION_PAYWALL_PREVIEW');

/// Whether commercial access limits the course for this account. Off unless
/// the server says otherwise: with it off, every published unit counts as
/// accessible and only learning progression applies, as before.
final coursePaywallEnabledProvider = FutureProvider<bool>((ref) async {
  if (paywallPreview) return true;
  return (await ref.watch(
    monetizationConfigurationProvider.future,
  )).coursePaywallEnabled;
});

/// The account's commercial access from the verified snapshot, or null while
/// the paywall is off. Loading is never read as "not paid": this resolves
/// only once the snapshot has loaded.
final commercialAccessProvider = FutureProvider<CourseAccess?>((ref) async {
  if (!await ref.watch(coursePaywallEnabledProvider.future)) return null;
  final load = await ref.watch(monetizationLoadProvider.future);
  return load.courseAccess(ref.read(backendServiceProvider).userId);
});

final _everyUnitAccessible = CourseAccess(
  sourcesByUnit: {
    for (final unit in CourseCatalog.a1ReferralV1.allUnitIds)
      unit: {CourseAccessSource.free},
  },
);

/// Lessons the learner may start now: open by learning progression and, when
/// the paywall is on, in a unit the account can access. Lesson surfaces use
/// this; reference pages keep the progression-only [unlockedUnitIdsProvider].
final playableLessonIdsProvider = FutureProvider<Set<int>>((ref) async {
  final unlocked = await ref.watch(unlockedLessonIdsProvider.future);
  final commercial = await ref.watch(commercialAccessProvider.future);
  if (commercial == null) return unlocked;
  final playable = <int>{};
  for (final unit in await ref.watch(allUnitsProvider.future)) {
    if (!commercial.canAccessUnit(unit.id)) continue;
    for (final lesson in await ref.watch(unitLessonsProvider(unit.id).future)) {
      if (unlocked.contains(lesson.id)) playable.add(lesson.id);
    }
  }
  return playable;
});

/// Units the account can access commercially, for screens that mark paid
/// content. Every unit while the paywall is off.
final commerciallyAccessibleUnitIdsProvider = FutureProvider<Set<int>>((
  ref,
) async {
  final commercial = await ref.watch(commercialAccessProvider.future);
  final units = await ref.watch(allUnitsProvider.future);
  return {
    for (final unit in units)
      if (commercial?.canAccessUnit(unit.id) ?? true) unit.id,
  };
});

/// Whether this lesson may start now, and if not, why. The lesson player asks
/// before every new attempt, so deep links, restored routes and checkpoint
/// resume all pass through it. Continue and the course map use the same rule
/// through [playableLessonIdsProvider]. Previously assigned transfer review
/// stays open by design.
final lessonAdmissionProvider = FutureProvider.family<LessonAdmission, int>((
  ref,
  lessonId,
) async {
  final Lesson lesson;
  try {
    lesson = await ref.watch(lessonProvider(lessonId).future);
  } on Object {
    return LessonAdmission.invalidContent;
  }
  final progression = await ref.watch(curriculumAccessProvider.future);
  if (!await ref.watch(coursePaywallEnabledProvider.future)) {
    return const LessonAdmissionPolicy().evaluate(
      lesson: lesson,
      progression: progression,
      commercial: _everyUnitAccessible,
      now: DateTime.now().toUtc(),
      accountId: null,
      accountEpoch: 0,
    );
  }
  final load = await ref.watch(monetizationLoadProvider.future);
  return const LessonAdmissionPolicy().evaluate(
    lesson: lesson,
    progression: progression,
    commercial: load.courseAccess(ref.read(backendServiceProvider).userId),
    now: load.now,
    accountId: ref.read(backendServiceProvider).userId,
    accountEpoch: 0,
    accountTransition: load.accountTransition,
  );
});

/// Whether a new mock exam may start. A1 needs access to every A1 unit (or
/// Core, grace or staff), A2 to every A2 unit. Results stay readable and a
/// saved exam can be resumed either way; this gates starting a new one.
final examAdmissionProvider = FutureProvider.family<bool, ExamLevel>((
  ref,
  level,
) async {
  final commercial = await ref.watch(commercialAccessProvider.future);
  if (commercial == null) return true;
  return CourseCatalog.a1ReferralV1
      .unitsFor(level == ExamLevel.a1 ? Phase.a1 : Phase.a2)
      .every(commercial.canAccessUnit);
});

/// The lesson the course continues with when learning has reached content the
/// account has not paid for: the one Continue would choose by progression
/// alone. Null while the paywall is off or when nothing paid is next. The
/// course map and Home use it to offer Subscribe or Invite friends instead of
/// silently showing nothing to continue.
final paidBoundaryLessonProvider = FutureProvider<Lesson?>((ref) async {
  if (await ref.watch(commercialAccessProvider.future) == null) return null;
  final playable = await ref.watch(playableLessonIdsProvider.future);
  final unlocked = await ref.watch(unlockedLessonIdsProvider.future);
  final units = await ref.watch(allUnitsProvider.future);
  await ref.watch(completedLessonIdsProvider.future);
  final completedRows = await ref
      .read(databaseProvider)
      .progressDao
      .getCompletedLessons();
  final lessons = <ContinueLessonCandidate>[];
  final byId = <int, Lesson>{};
  for (final unit in units) {
    for (final lesson in await ref.watch(unitLessonsProvider(unit.id).future)) {
      lessons.add(
        ContinueLessonCandidate(lessonId: lesson.id, isPreferredLevel: true),
      );
      byId[lesson.id] = lesson;
    }
  }
  final next = const ContinueLessonSelector().select(
    lessons: lessons,
    unlockedLessonIds: unlocked,
    completedAt: {
      for (final row in completedRows) row.lessonId: row.lastAttempted,
    },
  );
  if (next == null || playable.contains(next)) return null;
  return byId[next];
});
