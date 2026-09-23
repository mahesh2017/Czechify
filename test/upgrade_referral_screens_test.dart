import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:drift/native.dart';
import 'package:czechify/presentation/providers/sync_providers.dart';
import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:czechify/data/referrals/referral_api.dart';
import 'package:czechify/domain/entities/course_catalog.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/providers/referral_providers.dart';
import 'package:czechify/presentation/screens/monetization/referrals_screen.dart';
import 'package:czechify/presentation/screens/monetization/upgrade_screen.dart';
import 'package:czechify/presentation/widgets/common/soft_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/localized_app.dart';

User _user({required bool anonymous}) => User(
  id: 'account-a',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-09-01T00:00:00Z',
  isAnonymous: anonymous,
);

/// A referral backend that answers status and code requests from [status],
/// which a code request fills in, and records every call.
class _Backend extends BackendService {
  @override
  String? get userId => 'account-a';
}

class _Server {
  Map<String, Object?> status = {'units_earned': 0, 'next_reward_unit': 3};
  ApiResponse codeReply = const ApiResponse(200, {'referral_code': 'AB12CD'});
  int statusCode = 200;
  bool codeThrows = false;
  final calls = <String>[];

  ReferralApi get api =>
      ReferralApi((route, {required method, body, headers = const {}}) async {
        calls.add(route);
        if (route == 'referrals/code') {
          if (codeThrows) throw Exception('connection reset');
          if (codeReply.status == 200) {
            status = {...status, 'referral_code': 'AB12CD'};
          }
          return codeReply;
        }
        return ApiResponse(statusCode, status);
      });
}

Future<void> _pump(
  WidgetTester tester,
  String location, {
  bool referrals = true,
  bool anonymous = false,
  _Server? server,
  Future<String?> Function(String code)? claim,
  AppDatabase? database,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/upgrade',
        builder:
            (_, state) => UpgradeScreen(
              unitId: int.tryParse(state.uri.queryParameters['unit'] ?? ''),
            ),
      ),
      GoRoute(path: '/referrals', builder: (_, _) => const ReferralsScreen()),
      GoRoute(
        path: '/subscriptions',
        builder: (_, _) => const Scaffold(body: Text('Subscriptions page')),
      ),
      GoRoute(
        path: '/account',
        builder: (_, _) => const Scaffold(body: Text('Account page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        backendServiceProvider.overrideWithValue(_Backend()),
        referralsEnabledProvider.overrideWith((_) async => referrals),
        accountUserProvider.overrideWith(
          (_) => Stream.value(_user(anonymous: anonymous)),
        ),
        referralApiProvider.overrideWithValue((server ?? _Server()).api),
        if (claim != null) referralClaimProvider.overrideWithValue(claim),
        if (database != null) databaseProvider.overrideWithValue(database),
      ],
      child: MaterialApp.router(
        theme: lightTheme(),
        routerConfig: router,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('claim network errors clear busy and allow retry', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      '/referrals',
      claim: (_) async {
        calls++;
        throw StateError('offline');
      },
    );
    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.ensureVisible(find.text('Use code'));
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  group('upgrade', () {
    testWidgets('an A1 unit offers Core and invitations', (tester) async {
      await _pump(tester, '/upgrade?unit=3');
      expect(find.text('Subscribe to Czechify Core'), findsOneWidget);
      expect(find.text('Invite friends'), findsNWidgets(2));
      await tester.tap(find.text('See subscriptions'));
      await tester.pumpAndSettle();
      expect(find.text('Subscriptions page'), findsOneWidget);
    });

    testWidgets('an A2 unit never promises a referral reward', (tester) async {
      final a2 = CourseCatalog.a1ReferralV1.a2UnitIds.first;
      await _pump(tester, '/upgrade?unit=$a2');
      expect(find.text('Subscribe to Czechify Core'), findsOneWidget);
      expect(find.text('Invite friends'), findsNothing);
      expect(find.textContaining('A2 is included with Core'), findsOneWidget);
    });

    testWidgets('closed invitations leave only Core', (tester) async {
      await _pump(tester, '/upgrade?unit=3', referrals: false);
      expect(find.text('Subscribe to Czechify Core'), findsOneWidget);
      expect(find.text('Invite friends'), findsNothing);
    });

    testWidgets('the invite option opens the referral screen', (tester) async {
      await _pump(tester, '/upgrade');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Invite friends'));
      await tester.pumpAndSettle();
      expect(find.text('Your invitations'), findsOneWidget);
    });
  });

  group('referrals', () {
    testWidgets('closed invitations say so and call nothing', (tester) async {
      final server = _Server();
      await _pump(tester, '/referrals', referrals: false, server: server);
      expect(find.text("Invitations aren't open yet."), findsOneWidget);
      expect(find.text('Get my invite code'), findsNothing);
    });

    testWidgets('an anonymous learner is asked to link first', (tester) async {
      await _pump(tester, '/referrals', anonymous: true);
      expect(find.textContaining('Link your account'), findsOneWidget);
      expect(find.text('Get my invite code'), findsNothing);
      await tester.tap(find.text('Link account'));
      await tester.pumpAndSettle();
      expect(find.text('Account page'), findsOneWidget);
    });

    testWidgets('a linked learner gets a code to share', (tester) async {
      final semantics = tester.ensureSemantics();
      final server = _Server();
      await _pump(tester, '/referrals', server: server);
      expect(find.text('0 of 15 A1 units earned'), findsOneWidget);
      expect(find.text('Next reward: unit 3'), findsOneWidget);
      await tester.tap(find.text('Get my invite code'));
      await tester.pumpAndSettle();
      expect(server.calls, contains('referrals/code'));
      expect(find.text('AB12CD'), findsOneWidget);
      // A screen reader spells the code out rather than reading a word.
      expect(find.bySemanticsLabel(RegExp(r'\bA B 1 2 C D\b')), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Your invitations')),
        isSemantics(isHeader: true),
      );
      semantics.dispose();
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('a code request that fails in transport can be retried', (
      tester,
    ) async {
      final server = _Server()..codeThrows = true;
      await _pump(tester, '/referrals', server: server);
      await tester.tap(find.text('Get my invite code'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't check that right now. Please try again."),
        findsOneWidget,
      );
      server.codeThrows = false;
      await tester.tap(find.text('Get my invite code'));
      await tester.pumpAndSettle();
      expect(find.text('AB12CD'), findsOneWidget);
    });

    testWidgets('a refused code request explains why', (tester) async {
      final server =
          _Server()
            ..codeReply = const ApiResponse(403, {
              'code': 'campaign_unavailable',
            });
      await _pump(tester, '/referrals', server: server);
      await tester.tap(find.text('Get my invite code'));
      await tester.pumpAndSettle();
      expect(find.text("Invitations aren't open right now."), findsOneWidget);
      expect(find.text('Get my invite code'), findsOneWidget);
    });

    testWidgets('an unloaded status claims nothing about rewards', (
      tester,
    ) async {
      await _pump(tester, '/referrals', server: _Server()..statusCode = 503);
      expect(find.textContaining('A1 units earned'), findsNothing);
      expect(find.text("You've unlocked every A1 unit."), findsNothing);
      expect(find.text('Get my invite code'), findsOneWidget);
    });

    testWidgets('every unit earned is said only when it is true', (
      tester,
    ) async {
      final none = _Server()..status = {'units_earned': 0};
      await _pump(tester, '/referrals', server: none);
      expect(find.text("You've unlocked every A1 unit."), findsNothing);

      final all =
          _Server()..status = {'units_earned': 15, 'units_available': 15};
      await _pump(tester, '/referrals', server: all);
      expect(find.text('15 of 15 A1 units earned'), findsOneWidget);
      expect(find.text("You've unlocked every A1 unit."), findsOneWidget);
    });

    testWidgets('friends appear only by number with their progress', (
      tester,
    ) async {
      final server =
          _Server()
            ..status = {
              'referral_code': 'AB12CD',
              'units_earned': 1,
              'next_reward_unit': 4,
              'friends': [
                {
                  'friend': 1,
                  'milestones': [
                    {'ordinal': 1, 'status': 'reward_granted'},
                    {'ordinal': 2, 'status': 'verification_pending'},
                  ],
                },
              ],
            };
      await _pump(tester, '/referrals', server: server);
      expect(find.text('1 of 15 A1 units earned'), findsOneWidget);
      expect(find.text('Friend 1'), findsOneWidget);
      expect(find.text('First unit: Unit unlocked'), findsOneWidget);
      expect(find.text('Second unit: Being checked'), findsOneWidget);
    });

    testWidgets('an invited learner sees their own progress', (tester) async {
      final server =
          _Server()
            ..status = {
              'units_earned': 0,
              'own_claim': {
                'lessons_completed': 3,
                'lessons_required': 8,
                'milestones': [
                  {'ordinal': 1, 'status': 'needs_review'},
                ],
              },
            };
      await _pump(tester, '/referrals', server: server);
      expect(find.text('3 of 8 lessons completed'), findsOneWidget);
      expect(find.textContaining('First unit: Under review'), findsOneWidget);
      expect(find.text('Use code'), findsNothing);
    });

    testWidgets('entering a code maps each refusal to a message', (
      tester,
    ) async {
      final entered = <String>[];
      var reply = 'referral_ineligible';
      await _pump(
        tester,
        '/referrals',
        claim: (code) async {
          entered.add(code);
          return reply;
        },
      );
      await tester.enterText(find.byType(TextField), 'ZZ99');
      await tester.tap(find.text('Use code'));
      await tester.pumpAndSettle();
      expect(entered, ['ZZ99']);
      expect(find.textContaining("This code can't be used"), findsOneWidget);

      reply = 'rate_limited';
      await tester.tap(find.text('Use code'));
      await tester.pumpAndSettle();
      expect(
        find.text('Too many tries. Please try again in an hour.'),
        findsOneWidget,
      );
    });

    testWidgets('an accepted code confirms and clears the field', (
      tester,
    ) async {
      await _pump(tester, '/referrals', claim: (_) async => null);
      await tester.enterText(find.byType(TextField), 'ab12cd');
      await tester.tap(find.text('Use code'));
      await tester.pumpAndSettle();
      expect(find.textContaining("You're in."), findsOneWidget);
    });
  });

  testWidgets('the Play Integrity check is off until the learner turns it on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, '/referrals', database: db);
    final toggle = find.widgetWithText(
      SwitchListTile,
      'Check this phone with Google Play',
    );
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('referral_integrity_consent_v1:account-a'), isTrue);
    expect(
      prefs.getString('referral_integrity_consent_v1:account-a:at'),
      isNotNull,
    );
    // Withdrawing is as easy as giving it.
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(prefs.getBool('referral_integrity_consent_v1:account-a'), isFalse);
    // Both decisions are in the consent log, with the wording's version.
    final log = await tester.runAsync(() => db.select(db.consentRecords).get());
    expect(log!.map((r) => (r.purpose, r.granted, r.noticeVersion)), [
      ('referral_integrity', true, 'referral-integrity-v2'),
      ('referral_integrity', false, 'referral-integrity-v2'),
    ]);
  });
}
