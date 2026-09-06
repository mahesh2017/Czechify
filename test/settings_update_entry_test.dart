import 'package:czechify/data/database/database.dart';
import 'package:czechify/core/updates/app_update_service.dart';
import 'package:czechify/presentation/providers/app_update_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/routes/app_shell_keys.dart';
import 'package:czechify/presentation/screens/settings/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// Settings owes the badge that sends learners to it.
///
/// The home screen badges its settings icon when an update is waiting. Until
/// this card existed, Settings said nothing about it, and the only route
/// through was Settings → About → Check for updates — About being where you
/// go for a version number and a privacy link, not for something to do.
/// Dismissing the automatic prompt sets a 24-hour cooldown, so the badge
/// would sit there for a day with no way back in.
void main() {
  late AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() async => database.close());

  Future<_FakeUpdateService> openSettings(
    WidgetTester tester, {
    required bool updateAvailable,
  }) async {
    // Tall enough that the whole screen builds: Settings is a lazy list, and
    // the About group at the bottom is not constructed on a phone-sized
    // viewport, so `find.text` would not see it.
    tester.view.physicalSize = const Size(420, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeUpdateService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          appUpdateServiceProvider.overrideWithValue(service),
          if (updateAvailable)
            appUpdateAvailableProvider.overrideWith(_AlwaysAvailable.new),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    // Fixed frames rather than pumpAndSettle: something on this screen
    // animates continuously — a progress indicator in one of the status rows —
    // so settling never completes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return service;
  }

  testWidgets('the card is absent when there is nothing to update', (
    tester,
  ) async {
    await openSettings(tester, updateAvailable: false);
    expect(find.text('Update Czechify'), findsNothing);
    // The permanent row stays regardless — it is how a learner asks.
    expect(find.text('Check for updates'), findsOneWidget);
  });

  testWidgets('an available update is offered at the top of Settings', (
    tester,
  ) async {
    await openSettings(tester, updateAvailable: true);

    expect(find.text('Update Czechify'), findsOneWidget);

    // Above the first group: the badge sent the learner here, so this is the
    // first thing on the screen rather than something to scroll for.
    final card = tester.getTopLeft(find.text('Update Czechify')).dy;
    final firstGroup = tester.getTopLeft(find.text('Profile')).dy;
    expect(
      card,
      lessThan(firstGroup),
      reason: 'The update card is below the first settings group',
    );
  });

  testWidgets('the card starts a check that ignores the dismissal cooldown', (
    tester,
  ) async {
    // "Not now" sets a 24-hour, version-scoped cooldown. A learner who then
    // comes to Settings is asking, so the flow must run anyway.
    SharedPreferences.setMockInitialValues({
      'update_dismissed_version_code': 8,
      'update_dismissed_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
    final service = await openSettings(tester, updateAvailable: true);

    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      service.checkCount,
      1,
      reason: 'Tapping the card did not run an update check',
    );
  });

  testWidgets('the permanent row also runs a check', (tester) async {
    final service = await openSettings(tester, updateAvailable: false);

    await tester.tap(find.text('Check for updates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(service.checkCount, 1);
  });
}

class _AlwaysAvailable extends AppUpdateAvailabilityNotifier {
  @override
  bool build() => true;
}

class _FakeUpdateService implements AppUpdateService {
  int checkCount = 0;

  @override
  Future<AppUpdateCheck> checkForUpdate() async {
    checkCount++;
    return const AppUpdateCheck(
      AppUpdateAvailability.available,
      availableVersionCode: 8,
    );
  }

  @override
  Future<void> completeFlexibleUpdate() async {}

  @override
  Future<AppUpdateDownloadResult> startFlexibleUpdate() async =>
      AppUpdateDownloadResult.downloaded;
}
