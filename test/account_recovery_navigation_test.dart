import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/account/account_service.dart';
import 'package:czechify/domain/entities/curriculum_entitlement.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/screens/settings/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:czechify/l10n/app_localizations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'account route mode is explicit and unknown values stay in manage mode',
    () {
      expect(
        AccountScreenMode.fromRouteValue('onboardingRecovery'),
        AccountScreenMode.onboardingRecovery,
      );
      expect(AccountScreenMode.fromRouteValue(null), AccountScreenMode.manage);
      expect(
        AccountScreenMode.fromRouteValue('unexpected'),
        AccountScreenMode.manage,
      );
    },
  );

  testWidgets(
    'onboarding account recovery completes first run and replaces its stack',
    (tester) async {
      final service = _RecoveringAccountService();
      final router = _router(initialLocation: '/onboarding');
      addTearDown(router.dispose);

      await _mount(tester, router: router, service: service);
      await tester.tap(find.text('Recover existing account'));
      await tester.pumpAndSettle();

      await _completeEmailRecovery(tester);

      expect(service.switchCalls, 1);
      expect(service.lastEmail, 'learner@example.com');
      expect(find.text('Home destination'), findsOneWidget);
      expect(find.text('Account'), findsNothing);
      expect(router.canPop(), isFalse);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('settings_onboarding_done'), isTrue);
    },
  );

  testWidgets('Settings account recovery keeps normal Account behavior', (
    tester,
  ) async {
    final service = _RecoveringAccountService();
    final router = _router(initialLocation: '/account');
    addTearDown(router.dispose);

    await _mount(tester, router: router, service: service);
    await _completeEmailRecovery(tester);

    expect(service.switchCalls, 1);
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('Home destination'), findsNothing);
    expect(find.text('Account recovered and synchronized.'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('settings_onboarding_done'), isTrue);
  });

  testWidgets('back is blocked while onboarding account recovery installs', (
    tester,
  ) async {
    final service = _DelayedRecoveringAccountService();
    final router = _router(initialLocation: '/onboarding');
    addTearDown(router.dispose);

    await _mount(tester, router: router, service: service);
    await tester.tap(find.text('Recover existing account'));
    await tester.pumpAndSettle();

    await _beginEmailRecovery(tester);
    expect(service.switchCalls, 1);
    expect(find.byType(AccountScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('Recover existing account'), findsNothing);

    service.finishInstall();
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
}

GoRouter _router({required String initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('Home destination')),
    ),
    GoRoute(
      path: '/onboarding',
      builder:
          (context, _) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed:
                    () => context.push('/account?mode=onboardingRecovery'),
                child: const Text('Recover existing account'),
              ),
            ),
          ),
    ),
    GoRoute(
      path: '/account',
      builder:
          (_, state) => AccountScreen(
            mode: AccountScreenMode.fromRouteValue(
              state.uri.queryParameters['mode'],
            ),
          ),
    ),
  ],
);

Future<void> _mount(
  WidgetTester tester, {
  required GoRouter router,
  required AccountService service,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountServiceProvider.overrideWithValue(service),
        accountUserProvider.overrideWith((_) => Stream.value(null)),
        curriculumEntitlementProvider.overrideWith(
          (_) async => CurriculumEntitlement.none,
        ),
      ],
      child: MaterialApp.router(
        theme: lightTheme(),
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _completeEmailRecovery(WidgetTester tester) async {
  await _beginEmailRecovery(tester);
  await tester.pumpAndSettle();
}

Future<void> _beginEmailRecovery(WidgetTester tester) async {
  final signIn = find.text('Sign in to an existing account');
  await tester.ensureVisible(signIn);
  await tester.tap(signIn);
  await tester.pumpAndSettle();

  final fields = find.byType(TextField);
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), 'learner@example.com');
  await tester.enterText(fields.at(1), 'correct horse battery staple');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();

  expect(find.text('Replace local learner data?'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in and replace'));
  await tester.pump();
}

class _RecoveringAccountService implements AccountService {
  int switchCalls = 0;
  String? lastEmail;

  @override
  Future<AccountRestoreSummary> switchToExistingAccount({
    required String email,
    required String password,
  }) async {
    switchCalls++;
    lastEmail = email;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('settings_onboarding_done', true);
    return const AccountRestoreSummary(
      onboardingComplete: true,
      legacyProgressOnly: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _DelayedRecoveringAccountService extends _RecoveringAccountService {
  final _installGate = Completer<void>();

  void finishInstall() => _installGate.complete();

  @override
  Future<AccountRestoreSummary> switchToExistingAccount({
    required String email,
    required String password,
  }) async {
    switchCalls++;
    lastEmail = email;
    await _installGate.future;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('settings_onboarding_done', true);
    return const AccountRestoreSummary(
      onboardingComplete: true,
      legacyProgressOnly: false,
    );
  }
}
