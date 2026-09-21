import 'package:czechify/data/database/database.dart' as db_lib;
import 'package:czechify/data/monetization/monetization_repository.dart';
import 'package:czechify/data/monetization/snapshot_verifier.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/domain/engines/curriculum_access_policy.dart';
import 'package:czechify/domain/entities/curriculum_entitlement.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/monetization_snapshot.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:czechify/presentation/providers/course_admission_providers.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/monetization_providers.dart';
import 'package:czechify/presentation/providers/sync_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Backend extends BackendService {
  @override
  String? userId = 'account-a';
  @override
  SupabaseClient? get client => null;
}

final _now = DateTime.utc(2026, 10, 1, 12);
const _units = [
  Unit(id: 1, title: 'Free', description: '', phase: Phase.a1, orderIndex: 1),
  Unit(
    id: 3,
    title: 'Paid A1',
    description: '',
    phase: Phase.a1,
    orderIndex: 3,
  ),
  Unit(
    id: 16,
    title: 'Paid A2',
    description: '',
    phase: Phase.a2,
    orderIndex: 16,
  ),
];
Lesson _lesson(int id, int unitId) => Lesson(
  id: id,
  unitId: unitId,
  orderInUnit: id % 100,
  title: 'Lesson $id',
  description: '',
);
final _lessons = {
  1: [_lesson(100, 1), _lesson(101, 1)],
  3: [_lesson(300, 3)],
  16: [_lesson(1600, 16)],
};

void main() {
  late db_lib.AppDatabase db;
  setUp(() => db = db_lib.AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container({
    required bool paywall,
    FeatureEntitlement core = FeatureEntitlement.none,
    List<int> grantedUnits = const [],
    bool offline = false,
    bool accountTransition = false,
    Set<int> unlocked = const {100, 101, 300, 1600},
  }) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backendServiceProvider.overrideWithValue(_Backend()),
        coursePaywallEnabledProvider.overrideWith((_) async => paywall),
        allUnitsProvider.overrideWith((_) async => _units),
        unitLessonsProvider.overrideWith(
          (ref, unitId) async => _lessons[unitId] ?? const [],
        ),
        lessonProvider.overrideWith((ref, id) async {
          for (final list in _lessons.values) {
            for (final lesson in list) {
              if (lesson.id == id) return lesson;
            }
          }
          throw StateError('Unknown lesson');
        }),
        curriculumAccessProvider.overrideWith(
          (_) async => CurriculumAccess(
            unlockedUnitIds: const {1, 3, 16},
            unlockedLessonIds: unlocked,
            lessonPrerequisites: const {
              100: {},
              101: {100},
              300: {101},
              1600: {},
            },
          ),
        ),
        monetizationLoadProvider.overrideWith(
          (_) async => MonetizationLoad(
            VerifiedMonetizationDocument(
              MonetizationSnapshot(
                userId: 'account-a',
                revision: 1,
                verifiedAt: _now,
                core: core,
                permanentGrants: [
                  for (final unit in grantedUnits)
                    PermanentUnitGrant(
                      id: 'grant-$unit',
                      unitId: unit,
                      source: PermanentGrantSource.referral,
                    ),
                ],
              ),
              const CurriculumEntitlement(unlockAll: false),
              _now,
              'signed',
            ),
            offline: offline,
            requiresReverification: false,
            accountTransition: accountTransition,
            now: _now,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<LessonAdmission> admit(ProviderContainer c, int lesson) =>
      c.read(lessonAdmissionProvider(lesson).future);

  final core = FeatureEntitlement(
    active: true,
    validUntil: _now.add(const Duration(days: 20)),
    offlineValidUntil: _now.add(const Duration(days: 5)),
  );

  group('with the paywall off', () {
    test('only learning progression applies, as before', () async {
      final c = container(paywall: false, unlocked: const {100, 300});
      expect(await admit(c, 300), LessonAdmission.allowed);
      expect(await admit(c, 1600), LessonAdmission.prerequisiteRequired);
      expect(await admit(c, 999), LessonAdmission.invalidContent);
      expect(await c.read(playableLessonIdsProvider.future), {100, 300});
      expect(await c.read(examAdmissionProvider(ExamLevel.a2).future), isTrue);
      expect(await c.read(paidBoundaryLessonProvider.future), isNull);
      expect(await c.read(commercialAccessProvider.future), isNull);
    });
  });

  group('with the paywall on', () {
    test('without a subscription only the free units play', () async {
      final c = container(paywall: true);
      expect(await admit(c, 100), LessonAdmission.allowed);
      expect(await admit(c, 300), LessonAdmission.paymentRequired);
      expect(await admit(c, 1600), LessonAdmission.paymentRequired);
      expect(await c.read(playableLessonIdsProvider.future), {100, 101});
      expect(await c.read(examAdmissionProvider(ExamLevel.a1).future), isFalse);
    });

    test('payment is shown ahead of a missing prerequisite', () async {
      final c = container(paywall: true, unlocked: const {100});
      expect(await admit(c, 300), LessonAdmission.paymentRequired);
      expect(await admit(c, 101), LessonAdmission.prerequisiteRequired);
    });

    test('Core opens every published unit', () async {
      final c = container(paywall: true, core: core);
      expect(await admit(c, 300), LessonAdmission.allowed);
      expect(await admit(c, 1600), LessonAdmission.allowed);
      expect(await c.read(examAdmissionProvider(ExamLevel.a1).future), isTrue);
      expect(await c.read(examAdmissionProvider(ExamLevel.a2).future), isTrue);
    });

    test('a referral unit opens that unit only, and not the A1 exam', () async {
      final c = container(paywall: true, grantedUnits: const [3]);
      expect(await admit(c, 300), LessonAdmission.allowed);
      expect(await admit(c, 1600), LessonAdmission.paymentRequired);
      expect(await c.read(examAdmissionProvider(ExamLevel.a1).future), isFalse);
    });

    test(
      'offline past the verification lease asks to reconnect, not to pay',
      () async {
        final expiredLease = FeatureEntitlement(
          active: true,
          validUntil: _now.add(const Duration(days: 20)),
          offlineValidUntil: _now.subtract(const Duration(days: 1)),
        );
        final c = container(paywall: true, core: expiredLease, offline: true);
        expect(await admit(c, 300), LessonAdmission.reverificationRequired);
        expect(await admit(c, 100), LessonAdmission.allowed);
      },
    );

    test('during an account switch nothing new is admitted', () async {
      final c = container(paywall: true, core: core, accountTransition: true);
      expect(await admit(c, 100), LessonAdmission.accountTransition);
    });

    test(
      'the paid boundary is the lesson Continue would have chosen',
      () async {
        for (final id in [100, 101]) {
          await db.progressDao.recordLessonCompletion(
            attemptId: 'attempt-$id',
            lessonId: id,
            unitId: 1,
            score: 1,
            correctCount: 1,
            incorrectCount: 0,
            skippedCount: 0,
            startedAt: _now,
            activityXp: 10,
            exerciseEvidence: const [],
          );
        }
        final c = container(paywall: true);
        c.listen(completedLessonIdsProvider, (_, _) {});
        expect((await c.read(paidBoundaryLessonProvider.future))?.id, 300);
        final subscribed = container(paywall: true, core: core);
        expect(
          await subscribed.read(paidBoundaryLessonProvider.future),
          isNull,
        );
      },
    );
  });
}
