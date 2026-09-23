import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/referrals/referral_integrity_consent.dart';
import 'package:czechify/data/referrals/referral_status.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/providers/referral_providers.dart';
import 'package:czechify/presentation/providers/sync_providers.dart';
import 'package:czechify/presentation/screens/monetization/referrals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/localized_app.dart';

/// The Play Integrity question is asked when the friend joins, before any
/// lesson result is sent: one sent unchecked puts the whole invitation into
/// manual review, so results wait for the answer.
class _Backend extends BackendService {
  @override
  String? get userId => 'account-a';
}

const _joined = ReferralStatus(
  ownClaim: OwnReferralClaim(
    claimId: 'c1',
    lessonsCompleted: 3,
    lessonsRequired: 8,
    milestones: [],
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'the choice is unknown until made, then remembered per account',
    () async {
      expect(await ReferralIntegrityConsent.choice('account-a'), isNull);
      expect(await ReferralIntegrityConsent.granted('account-a'), isFalse);
      await ReferralIntegrityConsent.set('account-a', false);
      expect(await ReferralIntegrityConsent.choice('account-a'), isFalse);
      expect(await ReferralIntegrityConsent.choice('account-b'), isNull);
    },
  );

  Future<List<bool>> pump(
    WidgetTester tester, {
    required ReferralStatus status,
    Future<String?> Function(String code)? claim,
  }) async {
    final chosen = <bool>[];
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
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
          referralClaimProvider.overrideWithValue(claim ?? (_) async => null),
          setReferralIntegrityConsentProvider.overrideWithValue((allow) async {
            chosen.add(allow);
          }),
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
    return chosen;
  }

  testWidgets('joining asks the question before anything is sent', (
    tester,
  ) async {
    final chosen = await pump(tester, status: const ReferralStatus());
    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();
    expect(find.text('Choose how your lessons are checked'), findsOneWidget);
    await tester.tap(find.text('Check by hand'));
    await tester.pumpAndSettle();
    expect(chosen, [false]);
  });

  testWidgets('a refused code asks nothing', (tester) async {
    final chosen = await pump(
      tester,
      status: const ReferralStatus(),
      claim: (_) async => 'referral_ineligible',
    );
    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();
    expect(find.text('Choose how your lessons are checked'), findsNothing);
    expect(chosen, isEmpty);
  });

  testWidgets('a dismissed question stays on the screen until answered', (
    tester,
  ) async {
    final chosen = await pump(tester, status: _joined);
    expect(find.text('Choose how your lessons are checked'), findsOneWidget);
    await tester.tap(find.text('Check with Google Play'));
    await tester.pumpAndSettle();
    expect(chosen, [true]);
  });

  testWidgets('once chosen, the question is gone', (tester) async {
    SharedPreferences.setMockInitialValues({
      'referral_integrity_consent_v1:account-a': false,
    });
    await pump(tester, status: _joined);
    expect(find.text('Choose how your lessons are checked'), findsNothing);
  });
}
