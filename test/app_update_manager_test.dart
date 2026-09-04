import 'dart:async';

import 'package:czechify/core/updates/app_update_service.dart';
import 'package:czechify/presentation/providers/app_update_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('automatic prompt is suppressed for one day after dismissal', () async {
    var now = DateTime(2026, 8, 25, 12);
    final manager = AppUpdateManager(_FakeUpdateService(), now: () => now);
    const update = AppUpdateCheck(
      AppUpdateAvailability.available,
      availableVersionCode: 8,
    );

    expect(await manager.shouldOfferAutomatically(update), isTrue);
    await manager.rememberDismissal(update.availableVersionCode);
    expect(await manager.shouldOfferAutomatically(update), isFalse);

    now = now.add(const Duration(hours: 23, minutes: 59));
    expect(await manager.shouldOfferAutomatically(update), isFalse);
    now = now.add(const Duration(minutes: 1));
    expect(await manager.shouldOfferAutomatically(update), isTrue);
  });

  test('a newer version is not hidden by the previous dismissal', () async {
    final manager = AppUpdateManager(
      _FakeUpdateService(),
      now: () => DateTime(2026, 8, 25, 12),
    );
    await manager.rememberDismissal(8);

    expect(
      await manager.shouldOfferAutomatically(
        const AppUpdateCheck(
          AppUpdateAvailability.available,
          availableVersionCode: 9,
        ),
      ),
      isTrue,
    );
  });

  test('downloaded update always offers restart', () async {
    final manager = AppUpdateManager(_FakeUpdateService());
    await manager.rememberDismissal(8);

    expect(
      await manager.shouldOfferAutomatically(
        const AppUpdateCheck(
          AppUpdateAvailability.readyToInstall,
          availableVersionCode: 8,
        ),
      ),
      isTrue,
    );
  });

  test('simultaneous checks share one Play request', () async {
    final completer = Completer<AppUpdateCheck>();
    final service = _FakeUpdateService(checkCompleter: completer);
    final manager = AppUpdateManager(service);

    final first = manager.checkForUpdate();
    final second = manager.checkForUpdate();
    expect(identical(first, second), isTrue);
    expect(service.checkCount, 1);

    completer.complete(const AppUpdateCheck(AppUpdateAvailability.upToDate));
    await Future.wait([first, second]);
    await manager.checkForUpdate();
    expect(service.checkCount, 2);
  });

  test('automatic checks are rate-limited within a foreground session', () {
    var now = DateTime(2026, 8, 25, 12);
    final manager = AppUpdateManager(_FakeUpdateService(), now: () => now);

    expect(manager.shouldRunAutomaticCheck(), isTrue);
    expect(manager.shouldRunAutomaticCheck(), isFalse);
    now = now.add(const Duration(minutes: 15));
    expect(manager.shouldRunAutomaticCheck(), isTrue);
  });
}

class _FakeUpdateService implements AppUpdateService {
  _FakeUpdateService({this.checkCompleter});

  final Completer<AppUpdateCheck>? checkCompleter;
  int checkCount = 0;

  @override
  Future<AppUpdateCheck> checkForUpdate() {
    checkCount += 1;
    return checkCompleter?.future ??
        Future.value(const AppUpdateCheck(AppUpdateAvailability.upToDate));
  }

  @override
  Future<void> completeFlexibleUpdate() async {}

  @override
  Future<AppUpdateDownloadResult> startFlexibleUpdate() async {
    return AppUpdateDownloadResult.downloaded;
  }
}
