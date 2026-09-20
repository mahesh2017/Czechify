import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:czechify/domain/engines/course_access_policy.dart';
import 'package:czechify/domain/engines/curriculum_access_policy.dart';
import 'package:czechify/domain/engines/lesson_admission_policy.dart';
import 'package:czechify/domain/engines/referral_reward_policy.dart';
import 'package:czechify/domain/entities/course_catalog.dart';
import 'package:czechify/domain/entities/curriculum_entitlement.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/monetization_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('docs/monetization/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

Set<int> _ids(dynamic value) => (value as List).cast<int>().toSet();

void main() {
  final catalog = CourseCatalog.a1ReferralV1;
  final now = DateTime.utc(2026, 10, 1, 12);
  final until = now.add(const Duration(days: 30));
  const account = 'account-a';
  final fixture = _fixture('decision_cases.v1.json');
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();
  final domainCases = cases.where((c) => c['kind'] != 'transaction_scenario');

  test('all 40 pure decision cases remain covered; transactions need SQL', () {
    expect(domainCases.length, 40);
    expect(cases.where((c) => c['kind'] == 'transaction_scenario').length, 3);
  });

  for (final c in domainCases) {
    test('contract ${c['kind']}: ${c['id']}', () {
      final input = c['input'] as Map<String, dynamic>;
      final expected = c['expected'] as Map<String, dynamic>;
      switch (c['kind']) {
        case 'commercial_access':
          final revoked = _ids(input['revoked_unit_ids']);
          final access = const CourseAccessPolicy().evaluate(
            catalog: catalog,
            accountId: account,
            now: now,
            offline: false,
            staff: CurriculumEntitlement(
              unlockAll: input['staff_course_active'] as bool,
            ),
            snapshot: MonetizationSnapshot(
              userId: account,
              revision: 1,
              verifiedAt: now,
              core: FeatureEntitlement(
                active: input['core_entitled'] as bool,
                validUntil: until,
                offlineValidUntil: until,
              ),
              migrationGraceUntil:
                  input['migration_grace_active'] == true ? until : null,
              permanentGrants: [
                for (final id in _ids(input['active_permanent_unit_ids']))
                  PermanentUnitGrant(
                    id: 'grant-$id',
                    unitId: id,
                    source: PermanentGrantSource.referral,
                    revoked: revoked.contains(id),
                  ),
              ],
            ),
          );
          expect(
            catalog.a1UnitIds.where(access.canAccessUnit).toList(),
            expected['a1_unit_ids'],
          );
          expect(
            catalog.a2UnitIds.where(access.canAccessUnit).toList(),
            expected['a2_unit_ids'],
          );
        case 'reward_allocation':
          // Temporary Core is deliberately not an allocation input.
          final rewards = const ReferralRewardPolicy().allocate(
            catalog: catalog,
            permanentlyOwnedUnitIds: _ids(input['permanent_owned_unit_ids']),
            newQualifiedOrdinals:
                (input['new_qualified_ordinals'] as List).cast<int>(),
          );
          expect(
            rewards.map((r) => r.unitId).whereType<int>().toList(),
            expected['new_unit_ids'],
          );
          expect(
            rewards
                .map(
                  (r) =>
                      r.outcome == ReferralRewardOutcome.granted
                          ? 'granted'
                          : 'cap_reached',
                )
                .toList(),
            expected['ordinal_outcomes'],
          );
        case 'billing_access':
          final purchase = VerifiedSubscription(
            state: SubscriptionState.fromStorage(input['state'] as String),
            validUntil: DateTime.parse(input['valid_until'] as String),
            verifiedAt: now,
          );
          expect(
            purchase.isActiveAt(DateTime.parse(input['now'] as String)),
            expected['entitled'],
          );
        case 'paid_offline_lease':
          final purchase = VerifiedSubscription(
            state: SubscriptionState.active,
            validUntil: DateTime.parse(input['valid_until'] as String),
            verifiedAt: DateTime.parse(input['feature_verified_at'] as String),
          );
          final at = DateTime.parse(input['adjusted_now'] as String);
          final feature = FeatureEntitlement.fromVerifiedPurchases([
            purchase,
          ], now: at);
          expect(feature.isActiveAt(at, offline: true), expected['allowed']);
        case 'milestone_readiness':
          expect(
            const ReferralRewardPolicy().awardableOrdinals(
              completeManifestUnitIds: _ids(
                input['complete_manifest_unit_ids'],
              ),
              bothAccountsLinked: input['both_accounts_linked'] as bool,
              riskCleared: input['risk_state'] == 'clear',
            ),
            expected['awardable_ordinals'],
          );
        case 'lesson_admission':
          const lesson = Lesson(
            id: 301,
            unitId: 3,
            orderInUnit: 0,
            title: '',
            description: '',
          );
          final decision = const LessonAdmissionPolicy().evaluate(
            lesson: lesson,
            progression: CurriculumAccess(
              unlockedUnitIds: const {3},
              unlockedLessonIds:
                  input['progression_accessible'] == true ? {301} : {},
              lessonPrerequisites: const {301: {}},
            ),
            commercial: CourseAccess(
              sourcesByUnit: {
                if (input['commercially_accessible'] == true)
                  3: {CourseAccessSource.core},
              },
            ),
            now: now,
            accountId: account,
            accountEpoch: 0,
          );
          const names = {
            LessonAdmission.allowed: 'allowed',
            LessonAdmission.prerequisiteRequired: 'prerequisite_required',
            LessonAdmission.paymentRequired: 'payment_required',
          };
          expect(names[decision], expected['result']);
        default:
          fail('Unimplemented contract kind: ${c['kind']}');
      }
    });
  }

  test('campaign membership agrees with the real bundled curriculum', () {
    final manifest = _fixture('campaign_manifest.v1.json');
    expect(catalog.a1UnitIds, manifest['a1_unit_order']);
    expect(catalog.a2UnitIds, manifest['a2_unit_order']);
    expect(catalog.freeUnitIds, manifest['free_unit_ids']);
    expect(catalog.rewardUnitIds, manifest['reward_unit_order']);
    for (final phase in ['a1', 'a2']) {
      final content =
          jsonDecode(
                File(
                  'assets/curriculum/${phase}_units.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final units =
          (content['units'] as List).cast<Map<String, dynamic>>()..sort(
            (a, b) =>
                (a['order_index'] as int).compareTo(b['order_index'] as int),
          );
      expect(
        units.map((u) => u['id']).toList(),
        manifest['${phase}_unit_order'],
      );
    }
  });

  test(
    'free-unit manifest pins all eight lessons and teaching acknowledgements',
    () {
      final manifest = _fixture('campaign_manifest.v1.json');
      final lessonIds = <int>{};
      var exerciseCount = 0;
      for (final unit in manifest['free_unit_lessons'] as List) {
        for (final lesson in unit['lessons'] as List) {
          final bytes = File(lesson['source'] as String).readAsBytesSync();
          expect(sha256.convert(bytes).toString(), lesson['sha256']);
          final content =
              jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          final exercises =
              (content['exercises'] as List).cast<Map<String, dynamic>>();
          expect(content['unit_id'], unit['unit_id']);
          expect(content['id'], lesson['lesson_id']);
          expect(lessonIds.add(content['id'] as int), isTrue);
          expect(
            exercises.map((e) => e['id']).toList(),
            lesson['exercise_ids'],
          );
          expect(
            exercises
                .where((e) => e['type'] == 'teaching')
                .map((e) => e['id'])
                .toList(),
            lesson['teaching_exercise_ids'],
          );
          expect(exercises.length, lesson['required_initial_coverage']);
          exerciseCount += exercises.length;
        }
      }
      expect(lessonIds.length, 8);
      expect(exerciseCount, 92);
    },
  );
}
