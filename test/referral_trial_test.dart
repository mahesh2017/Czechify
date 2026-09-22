import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/monetization/monetization_repository.dart';
import 'package:czechify/data/monetization/snapshot_verifier.dart';
import 'package:czechify/data/referrals/referral_status.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/domain/entities/course_catalog.dart';
import 'package:czechify/domain/entities/curriculum_entitlement.dart';
import 'package:czechify/domain/entities/monetization_snapshot.dart';
import 'package:czechify/domain/engines/course_access_policy.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/providers/billing_providers.dart';
import 'package:czechify/presentation/providers/monetization_providers.dart';
import 'package:czechify/presentation/providers/referral_providers.dart';
import 'package:czechify/presentation/providers/sync_providers.dart';
import 'package:czechify/presentation/screens/monetization/referrals_screen.dart';
import 'package:czechify/presentation/screens/settings/subscriptions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/localized_app.dart';

/// The invited friend's side of an invitation: two weeks of Core, free, when
/// they finish the two free units. Until this existed they got nothing, so
/// there was no reason of their own to enter a code.
class _Backend extends BackendService {
  @override
  String? get userId => 'account-a';
}

final _now = DateTime.utc(2026, 11, 20, 12);
final _trialEnds = DateTime.utc(2026, 12, 4, 12);

MonetizationSnapshot _snapshot({DateTime? trial, DateTime? grace}) =>
    MonetizationSnapshot(
      userId: 'account-a',
      revision: 3,
      verifiedAt: _now,
      referralTrialUntil: trial,
      migrationGraceUntil: grace,
    );

void main() {
  group('course access', () {
    CourseAccess access(MonetizationSnapshot value, {DateTime? at}) =>
        const CourseAccessPolicy().evaluate(
          catalog: CourseCatalog.a1ReferralV1,
          accountId: 'account-a',
          now: at ?? _now,
          offline: false,
          snapshot: value,
        );

    test('a running trial opens the whole course', () {
      final result = access(_snapshot(trial: _trialEnds));
      expect(
        result.accessibleUnitIds,
        CourseCatalog.a1ReferralV1.allUnitIds.toSet(),
      );
      expect(
        result.sourcesByUnit[5],
        contains(CourseAccessSource.referralTrial),
      );
    });

    test('when it ends, only the free units remain', () {
      final result = access(
        _snapshot(trial: _trialEnds),
        at: _trialEnds.add(const Duration(seconds: 1)),
      );
      expect(result.accessibleUnitIds, {1, 2});
    });

    test('a trial is not shown as existing-user grace', () {
      final result = access(_snapshot(trial: _trialEnds));
      expect(
        result.sourcesByUnit[5],
        isNot(contains(CourseAccessSource.migrationGrace)),
      );
      // Both windows at once still grant once, from both sources.
      final both = access(_snapshot(trial: _trialEnds, grace: _trialEnds));
      expect(both.sourcesByUnit[5], {
        CourseAccessSource.migrationGrace,
        CourseAccessSource.referralTrial,
      });
    });
  });

  group('status', () {
    test('the trial and its length are read from the server', () {
      final status = ReferralStatus.fromJson({
        'units_earned': 0,
        'trial_days': 14,
        'own_claim': {
          'claim_id': 'c1',
          'lessons_completed': 8,
          'lessons_required': 8,
          'trial_until': _trialEnds.toIso8601String(),
          'milestones': [],
        },
      });
      expect(status.trialDays, 14);
      expect(status.ownClaim!.trialUntil, _trialEnds);
    });

    test('an older server without them keeps the app working', () {
      final status = ReferralStatus.fromJson({
        'units_earned': 1,
        'own_claim': {
          'lessons_completed': 0,
          'lessons_required': 8,
          'milestones': [],
        },
      });
      expect(status.trialDays, 14);
      expect(status.ownClaim!.trialUntil, isNull);
      for (final odd in [0, -5, 'ten', null]) {
        expect(
          ReferralStatus.fromJson({'trial_days': odd}).trialDays,
          14,
          reason: '$odd',
        );
      }
    });
  });

  group('screens', () {
    Future<void> pumpInvites(
      WidgetTester tester, {
      required ReferralStatus status,
    }) async {
      tester.view.physicalSize = const Size(400, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            backendServiceProvider.overrideWithValue(_Backend()),
            referralsEnabledProvider.overrideWith((_) async => true),
            accountUserProvider.overrideWith(
              (_) => Stream.value(
                const User(
                  id: 'account-a',
                  appMetadata: {},
                  userMetadata: {},
                  aud: 'authenticated',
                  createdAt: '2026-11-01T00:00:00Z',
                  isAnonymous: false,
                ),
              ),
            ),
            referralStatusProvider.overrideWith((_) async => status),
          ],
          child: MaterialApp(
            theme: lightTheme(),
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: const ReferralsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    OwnReferralClaim claim(DateTime? trial) => OwnReferralClaim(
      claimId: 'c1',
      lessonsCompleted: 8,
      lessonsRequired: 8,
      milestones: const [],
      trialUntil: trial,
    );

    testWidgets('before joining, the screen says what the friend gets', (
      tester,
    ) async {
      await pumpInvites(tester, status: const ReferralStatus(trialDays: 14));
      expect(
        find.textContaining(
          '14 days of Czechify Core free',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'two weeks of Czechify Core free',
          skipOffstage: false,
        ),
        findsOneWidget,
        reason: 'the how-it-works text names both sides',
      );
    });

    testWidgets('a running trial says when it ends', (tester) async {
      await pumpInvites(
        tester,
        status: ReferralStatus(
          ownClaim: claim(DateTime.now().toUtc().add(const Duration(days: 9))),
        ),
      );
      expect(
        find.textContaining(
          'Czechify Core is free for you until',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Enter a friend', skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('an ended trial is not advertised as running', (tester) async {
      await pumpInvites(
        tester,
        status: ReferralStatus(
          ownClaim: claim(
            DateTime.now().toUtc().subtract(const Duration(days: 1)),
          ),
        ),
      );
      expect(
        find.textContaining(
          'Czechify Core is free for you until',
          skipOffstage: false,
        ),
        findsNothing,
      );
    });

    testWidgets('subscriptions explains why the course is open', (
      tester,
    ) async {
      Future<void> pump({DateTime? trial}) async {
        tester.view.physicalSize = const Size(400, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              billingPlatformSupportedProvider.overrideWithValue(true),
              checkoutEnabledProvider.overrideWith((_) async => true),
              accountUserProvider.overrideWith((_) => const Stream.empty()),
              monetizationLoadProvider.overrideWith(
                (_) async => MonetizationLoad(
                  VerifiedMonetizationDocument(
                    _snapshot(trial: trial),
                    const CurriculumEntitlement(unlockAll: false),
                    _now,
                    'signed',
                  ),
                  offline: false,
                  requiresReverification: false,
                  now: _now,
                ),
              ),
            ],
            child: MaterialApp(
              theme: lightTheme(),
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              home: const SubscriptionsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(trial: _trialEnds);
      expect(
        find.textContaining('Czechify Core is free until'),
        findsOneWidget,
      );
      await pump();
      expect(find.textContaining('Czechify Core is free until'), findsNothing);
    });
  });
}
