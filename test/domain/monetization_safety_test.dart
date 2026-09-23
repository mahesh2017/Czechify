import 'package:czechify/domain/engines/course_access_policy.dart';
import 'package:czechify/domain/engines/curriculum_access_policy.dart';
import 'package:czechify/domain/engines/lesson_admission_policy.dart';
import 'package:czechify/domain/engines/referral_reward_policy.dart';
import 'package:czechify/domain/entities/course_catalog.dart';
import 'package:czechify/domain/entities/curriculum_entitlement.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/monetization_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = CourseCatalog.a1ReferralV1;
  final now = DateTime.utc(2026, 10, 1);
  final expiry = now.add(const Duration(days: 30));
  final core = FeatureEntitlement(
    active: true,
    validUntil: expiry,
    offlineValidUntil: now.add(const Duration(days: 7)),
  );
  const permanent = PermanentUnitGrant(
    id: 'g-3',
    unitId: 3,
    source: PermanentGrantSource.referral,
  );

  MonetizationSnapshot snapshot({
    String user = 'a',
    int revision = 1,
    DateTime? verifiedAt,
    FeatureEntitlement? coreFeature,
    FeatureEntitlement? aiFeature,
    DateTime? grace,
  }) => MonetizationSnapshot(
    userId: user,
    revision: revision,
    verifiedAt: verifiedAt ?? now,
    core: coreFeature ?? FeatureEntitlement.none,
    aiChat: aiFeature ?? FeatureEntitlement.none,
    permanentGrants: [permanent],
    migrationGraceUntil: grace,
  );

  CourseAccess access(
    MonetizationSnapshot? value, {
    DateTime? at,
    bool offline = false,
    String? account = 'a',
  }) => const CourseAccessPolicy().evaluate(
    catalog: catalog,
    accountId: account,
    now: at ?? now,
    offline: offline,
    snapshot: value,
  );

  test(
    'wrong-account or anonymous cache never grants another learner access',
    () {
      final value = snapshot(coreFeature: core, grace: expiry);
      expect(access(value, account: 'b').accessibleUnitIds, {1, 2});
      expect(access(value, account: null).accessibleUnitIds, {1, 2});
      expect(access(value, account: '').accessibleUnitIds, {1, 2});
      expect(access(snapshot(revision: -1)).accessibleUnitIds, {1, 2});
    },
  );

  test(
    'refresh rejects older revision and older same-revision verification',
    () {
      final old = snapshot(revision: 4);
      expect(
        snapshot(
          revision: 3,
          verifiedAt: expiry,
        ).canReplace(old, accountId: 'a'),
        isFalse,
      );
      expect(
        snapshot(
          revision: 4,
          verifiedAt: now.subtract(const Duration(seconds: 1)),
        ).canReplace(old, accountId: 'a'),
        isFalse,
      );
      expect(
        snapshot(
          revision: 4,
          verifiedAt: now.add(const Duration(seconds: 1)),
        ).canReplace(old, accountId: 'a'),
        isTrue,
      );
      expect(snapshot(revision: 5).canReplace(old, accountId: 'a'), isTrue);
      expect(snapshot(user: 'b').canReplace(null, accountId: 'a'), isFalse);
    },
  );

  test(
    'AI alone grants no course access; staff course override grants no AI',
    () {
      final value = snapshot(aiFeature: core);
      expect(access(value).accessibleUnitIds, {1, 2, 3});
      final staff = const CourseAccessPolicy().evaluate(
        catalog: catalog,
        accountId: 'a',
        now: now,
        offline: false,
        snapshot: snapshot(),
        staff: const CurriculumEntitlement(unlockAll: true),
      );
      expect(staff.accessibleUnitIds, catalog.allUnitIds);
      expect(snapshot().aiChat.isActiveAt(now, offline: false), isFalse);
    },
  );

  test(
    'expired lease requests verification only for units lacking another source',
    () {
      final afterLease = now.add(const Duration(days: 8));
      final result = access(
        snapshot(coreFeature: core),
        at: afterLease,
        offline: true,
      );
      expect(result.accessibleUnitIds, {1, 2, 3});
      expect(
        result.reverificationUnitIds,
        catalog.allUnitIds.difference({1, 2, 3}),
      );
      expect(
        access(snapshot(coreFeature: core), at: afterLease).accessibleUnitIds,
        catalog.allUnitIds,
      );
      expect(
        access(snapshot(coreFeature: core), at: expiry).reverificationUnitIds,
        isEmpty,
      );
    },
  );

  test(
    'sources union; cancellation or a revoked grant does not erase another source',
    () {
      final value = snapshot(coreFeature: core);
      expect(access(value).sourcesByUnit[3], {
        CourseAccessSource.core,
        CourseAccessSource.referral,
      });
      expect(access(value, at: expiry).sourcesByUnit[3], {
        CourseAccessSource.referral,
      });
      final revoked = MonetizationSnapshot(
        userId: 'a',
        revision: 2,
        verifiedAt: now,
        core: core,
        permanentGrants: const [
          PermanentUnitGrant(
            id: 'revoked',
            unitId: 3,
            source: PermanentGrantSource.referral,
            revoked: true,
          ),
        ],
      );
      expect(access(revoked).sourcesByUnit[3], {CourseAccessSource.core});
    },
  );

  test(
    'unknown unit grants are ignored and immutable snapshots cannot be edited',
    () {
      final grants = [
        permanent,
        const PermanentUnitGrant(
          id: 'foreign',
          unitId: 999,
          source: PermanentGrantSource.legacy,
        ),
      ];
      final value = MonetizationSnapshot(
        userId: 'a',
        revision: 1,
        verifiedAt: now,
        permanentGrants: grants,
      );
      grants.clear();
      expect(access(value).accessibleUnitIds, {1, 2, 3});
      expect(() => value.permanentGrants.clear(), throwsUnsupportedError);
      expect(
        () => access(value).sourcesByUnit[3]!.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'each purchase contributes its own offline bound, not mixed timestamps',
    () {
      final feature = FeatureEntitlement.fromVerifiedPurchases([
        VerifiedSubscription(
          state: SubscriptionState.active,
          validUntil: expiry,
          verifiedAt: now.subtract(const Duration(days: 6)),
        ),
        VerifiedSubscription(
          state: SubscriptionState.active,
          validUntil: now.add(const Duration(days: 2)),
          verifiedAt: now,
        ),
        VerifiedSubscription(
          state: SubscriptionState.revoked,
          validUntil: expiry.add(const Duration(days: 30)),
          verifiedAt: now,
        ),
      ], now: now);
      expect(feature.validUntil, expiry);
      expect(feature.offlineValidUntil, now.add(const Duration(days: 2)));
      expect(
        feature.isActiveAt(now.add(const Duration(days: 2)), offline: true),
        isFalse,
      );
    },
  );

  test('future or unsupported store states cannot silently become active', () {
    expect(
      SubscriptionState.fromStorage('unknown_new_state').permitsAccess,
      isFalse,
    );
    expect(
      const FeatureEntitlement(active: true).isActiveAt(now, offline: false),
      isFalse,
    );
  });

  test('grace and staff expire at the exact boundary', () {
    expect(access(snapshot(grace: expiry), at: expiry).accessibleUnitIds, {
      1,
      2,
      3,
    });
    final result = const CourseAccessPolicy().evaluate(
      catalog: catalog,
      accountId: 'a',
      now: expiry,
      offline: false,
      staff: CurriculumEntitlement(unlockAll: true, expiresAt: expiry),
    );
    expect(result.accessibleUnitIds, {1, 2});
  });

  test('referral ordinals outside 1/2 or duplicated are rejected', () {
    for (final ordinals in [
      [1, 1],
      [0],
      [3],
      [-1],
    ]) {
      expect(
        () => const ReferralRewardPolicy().allocate(
          catalog: catalog,
          permanentlyOwnedUnitIds: {},
          newQualifiedOrdinals: ordinals,
        ),
        throwsArgumentError,
      );
    }
    expect(
      const ReferralRewardPolicy()
          .allocate(
            catalog: catalog,
            permanentlyOwnedUnitIds: {},
            newQualifiedOrdinals: [2, 1],
          )
          .map((r) => (r.ordinal, r.unitId)),
      [(1, 3), (2, 4)],
    );
  });

  test(
    'catalog rejects overlapping phases, missing rewards and wrong order',
    () {
      expect(
        () => CourseCatalog(
          a1UnitIds: [1, 2, 3],
          a2UnitIds: [3],
          freeUnitIds: [1, 2],
          rewardUnitIds: [3],
        ),
        throwsArgumentError,
      );
      expect(
        () => CourseCatalog(
          a1UnitIds: [1, 2, 3],
          a2UnitIds: [],
          freeUnitIds: [1, 2],
          rewardUnitIds: [],
        ),
        throwsArgumentError,
      );
      expect(
        () => CourseCatalog(
          a1UnitIds: [1, 2, 3, 4],
          a2UnitIds: [],
          freeUnitIds: [1, 2],
          rewardUnitIds: [4, 3],
        ),
        throwsArgumentError,
      );
    },
  );

  const lesson = Lesson(
    id: 301,
    unitId: 3,
    orderInUnit: 0,
    title: '',
    description: '',
  );
  const progression = CurriculumAccess(
    unlockedUnitIds: {3},
    unlockedLessonIds: {301},
    lessonPrerequisites: {301: {}},
  );
  final permit = LessonAdmissionPermit(
    accountId: 'a',
    accountEpoch: 2,
    lessonId: 301,
    attemptId: 'attempt',
    admittedAt: now,
  );
  LessonAdmission admit({
    Lesson? target = lesson,
    String account = 'a',
    int epoch = 2,
    String attempt = 'attempt',
    DateTime? at,
    bool transition = false,
    bool loading = false,
    LessonAdmissionPermit? usePermit,
    CourseAccess? commercial,
    CurriculumAccess? graph = progression,
  }) => const LessonAdmissionPolicy().evaluate(
    lesson: target,
    progression: graph,
    commercial: commercial ?? CourseAccess(sourcesByUnit: {}),
    now: at ?? now,
    accountId: account,
    accountEpoch: epoch,
    attemptId: attempt,
    accountTransition: transition,
    loading: loading,
    permit: usePermit,
  );

  test(
    'admitted attempt finishes across expiry but never survives account transition',
    () {
      expect(
        admit(usePermit: permit, at: now.add(const Duration(minutes: 119))),
        LessonAdmission.allowed,
      );
      expect(
        admit(usePermit: permit, at: now.add(const Duration(hours: 2))),
        LessonAdmission.paymentRequired,
      );
      expect(
        admit(usePermit: permit, at: now.subtract(const Duration(seconds: 1))),
        LessonAdmission.paymentRequired,
      );
      expect(
        admit(usePermit: permit, account: 'b'),
        LessonAdmission.paymentRequired,
      );
      expect(
        admit(usePermit: permit, epoch: 3),
        LessonAdmission.paymentRequired,
      );
      expect(
        admit(usePermit: permit, attempt: 'different'),
        LessonAdmission.paymentRequired,
      );
      expect(
        admit(usePermit: permit, transition: true),
        LessonAdmission.accountTransition,
      );
    },
  );

  test(
    'loading, missing content and lease expiry are not purchase prompts',
    () {
      expect(admit(loading: true), LessonAdmission.loading);
      expect(admit(target: null), LessonAdmission.invalidContent);
      expect(admit(graph: null), LessonAdmission.loading);
      expect(
        admit(
          commercial: CourseAccess(
            sourcesByUnit: {},
            reverificationUnitIds: {3},
          ),
        ),
        LessonAdmission.reverificationRequired,
      );
      expect(
        admit(
          graph: const CurriculumAccess(
            unlockedUnitIds: {},
            unlockedLessonIds: {},
            lessonPrerequisites: {},
          ),
        ),
        LessonAdmission.invalidContent,
      );
    },
  );
}
