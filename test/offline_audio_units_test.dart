import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/services/audio/offline_audio_prefetch.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/presentation/providers/audio_prefetch_providers.dart';
import 'package:czechify/presentation/providers/course_admission_providers.dart';
import 'package:czechify/presentation/providers/monetization_providers.dart';
import 'package:czechify/presentation/screens/onboarding/offline_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// Audio is fetched ahead only for units the account can open. Clips already
/// on the device are never touched; this only narrows new downloads.
class _RecordingPrefetch implements OfflineAudioPrefetch {
  _RecordingPrefetch([
    this.result = const PrefetchProgress(
      completed: 0,
      total: 0,
      finished: true,
    ),
  ]);

  final PrefetchProgress result;
  final requested = <List<int>>[];

  @override
  Stream<PrefetchProgress> download(
    List<int> unitIds,
    String gender, {
    int concurrency = 4,
  }) async* {
    requested.add(unitIds);
    yield result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<int>> units(CEFRLevel level, Set<int> accessible) async {
    final container = ProviderContainer(
      overrides: [
        commerciallyAccessibleUnitIdsProvider.overrideWith(
          (_) async => accessible,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(offlineAudioUnitsProvider(level).future);
  }

  test('with the paywall off the first three units download', () async {
    final a1 = await OfflineAudioPrefetch.unitsForLevel(CEFRLevel.a1);
    expect(a1, hasLength(OfflineAudioPrefetch.setupUnitCount));
    expect(await units(CEFRLevel.a1, a1.toSet()), a1);
  });

  test('an unpaid unit is left out, not replaced', () async {
    final a1 = await OfflineAudioPrefetch.unitsForLevel(CEFRLevel.a1);
    expect(await units(CEFRLevel.a1, {a1[0], a1[1]}), [a1[0], a1[1]]);
  });

  test('A2 without access downloads nothing ahead', () async {
    final a1 = await OfflineAudioPrefetch.unitsForLevel(CEFRLevel.a1);
    expect(await units(CEFRLevel.a2, a1.toSet()), isEmpty);
  });

  Future<_RecordingPrefetch> openSetup(
    WidgetTester tester, [
    _RecordingPrefetch? recording,
  ]) async {
    SharedPreferences.setMockInitialValues({});
    final prefetch = recording ?? _RecordingPrefetch();
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(path: '/setup', builder: (_, _) => const OfflineSetupScreen()),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineAudioPrefetchProvider.overrideWithValue(prefetch),
          offlineAudioUnitsProvider.overrideWith((ref, level) async => [1, 2]),
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
    return prefetch;
  }

  testWidgets('setup downloads only accessible units, then continues', (
    tester,
  ) async {
    final prefetch = await openSetup(tester);
    expect(prefetch.requested, [
      [1, 2],
    ]);
    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('with every clip failing, setup says so and lets you start', (
    tester,
  ) async {
    await openSetup(
      tester,
      _RecordingPrefetch(
        const PrefetchProgress(
          completed: 2,
          total: 2,
          failed: 2,
          finished: true,
        ),
      ),
    );
    expect(find.text('No connection right now'), findsOneWidget);
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    expect(find.text('Home page'), findsOneWidget);
  });

  test('the app prefetcher reads access and account when work runs', () async {
    var accessible = {1, 2};
    var loads = 0;
    final container = ProviderContainer(
      overrides: [
        commerciallyAccessibleUnitIdsProvider.overrideWith((ref) async {
          ref.watch(monetizationLoadProvider);
          return accessible;
        }),
        monetizationLoadProvider.overrideWith((_) async {
          loads++;
          throw StateError('not needed');
        }),
      ],
    );
    addTearDown(container.dispose);
    final prefetch = container.read(offlineAudioPrefetchProvider);

    expect(await prefetch.accessibleUnits!(), {1, 2});
    accessible = {1};
    await prefetch.refreshAccess!();
    expect(await prefetch.accessibleUnits!(), {1});
    expect(loads, greaterThan(0), reason: 'refresh fetches signed access');

    final before = prefetch.accountContext!();
    container.read(lessonAccountTransitionProvider.notifier).revoke();
    expect(prefetch.accountContext!(), isNot(before));
  });
}
