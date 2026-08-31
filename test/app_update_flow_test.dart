import 'dart:async';

import 'package:czechify/core/updates/app_update_service.dart';
import 'package:czechify/presentation/providers/app_update_providers.dart';
import 'package:czechify/presentation/routes/app_shell_keys.dart';
import 'package:czechify/presentation/widgets/common/app_update_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('manual check reports that Czechify is current', (tester) async {
    final service = _FakeUpdateService(
      const AppUpdateCheck(AppUpdateAvailability.upToDate),
    );
    await tester.pumpWidget(_app(service));

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(find.text('Czechify is up to date.'), findsOneWidget);
  });

  testWidgets('available update is explained before Play flow starts', (
    tester,
  ) async {
    final service = _FakeUpdateService(
      const AppUpdateCheck(
        AppUpdateAvailability.available,
        availableVersionCode: 8,
      ),
    );
    await tester.pumpWidget(_app(service));

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('A Czechify update is available'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(service.downloadCount, 1);
    expect(
      find.text('Update ready. Restart Czechify to finish installing it.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Restart now'));
    await tester.pump();
    expect(service.completeCount, 1);
  });

  testWidgets('automatic dismissal is remembered for the offered version', (
    tester,
  ) async {
    final service = _FakeUpdateService(
      const AppUpdateCheck(
        AppUpdateAvailability.available,
        availableVersionCode: 8,
      ),
    );
    await tester.pumpWidget(_app(service, automatic: true));
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('update_dismissed_version_code'), 8);
  });

  testWidgets('backing out does not snooze the update', (tester) async {
    final service = _FakeUpdateService(
      const AppUpdateCheck(
        AppUpdateAvailability.available,
        availableVersionCode: 8,
      ),
    );
    await tester.pumpWidget(_app(service, automatic: true));

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('Persistent update indicator'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('update_dismissed_version_code'), isNull);
  });

  testWidgets('coordinator above a router can show the automatic prompt', (
    tester,
  ) async {
    final service = _FakeUpdateService(
      const AppUpdateCheck(
        AppUpdateAvailability.available,
        availableVersionCode: 8,
      ),
    );
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Learning')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appUpdateServiceProvider.overrideWithValue(service)],
        child: MaterialApp.router(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          routerConfig: router,
          builder:
              (context, child) => AppUpdateCoordinator(
                enabled: true,
                child: child ?? const SizedBox.shrink(),
              ),
        ),
      ),
    );

    expect(service.checkCount, 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(service.checkCount, 1);
    expect(find.text('A Czechify update is available'), findsOneWidget);
    expect(find.text('Learning'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  });

  testWidgets('restart prompt survives leaving the initiating route', (
    tester,
  ) async {
    final download = Completer<AppUpdateDownloadResult>();
    final service = _FakeUpdateService(
      const AppUpdateCheck(
        AppUpdateAvailability.available,
        availableVersionCode: 8,
      ),
      downloadCompleter: download,
    );
    await tester.pumpWidget(_app(service));

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pump();

    // Replace the route content while Play's download is still running.
    rootNavigatorKey.currentState!.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Another screen')),
      ),
    );
    await tester.pumpAndSettle();
    download.complete(AppUpdateDownloadResult.downloaded);
    await tester.pumpAndSettle();

    expect(find.text('Another screen'), findsOneWidget);
    expect(
      find.text('Update ready. Restart Czechify to finish installing it.'),
      findsOneWidget,
    );
  });
}

Widget _app(_FakeUpdateService service, {bool automatic = false}) {
  return ProviderScope(
    overrides: [appUpdateServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: _UpdateTestScreen(automatic: automatic),
    ),
  );
}

class _UpdateTestScreen extends ConsumerWidget {
  const _UpdateTestScreen({required this.automatic});

  final bool automatic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateAvailable = ref.watch(appUpdateAvailableProvider);
    return Scaffold(
      body: Column(
        children: [
          Text(
            updateAvailable
                ? 'Persistent update indicator'
                : 'No update indicator',
          ),
          Center(
            child: FilledButton(
              onPressed:
                  () => showAppUpdateFlow(ref: ref, automatic: automatic),
              child: const Text('Check'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeUpdateService implements AppUpdateService {
  _FakeUpdateService(this.check, {this.downloadCompleter});

  final AppUpdateCheck check;
  final Completer<AppUpdateDownloadResult>? downloadCompleter;
  int downloadCount = 0;
  int completeCount = 0;
  int checkCount = 0;

  @override
  Future<AppUpdateCheck> checkForUpdate() async {
    checkCount += 1;
    return check;
  }

  @override
  Future<void> completeFlexibleUpdate() async {
    completeCount += 1;
  }

  @override
  Future<AppUpdateDownloadResult> startFlexibleUpdate() async {
    downloadCount += 1;
    return downloadCompleter?.future ?? AppUpdateDownloadResult.downloaded;
  }
}
