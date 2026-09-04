import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// What Google Play currently knows about an update for this installation.
enum AppUpdateAvailability {
  unsupported,
  upToDate,
  available,
  availableInPlayStoreOnly,
  readyToInstall,
}

class AppUpdateCheck {
  const AppUpdateCheck(this.availability, {this.availableVersionCode});

  final AppUpdateAvailability availability;
  final int? availableVersionCode;
}

enum AppUpdateDownloadResult { downloaded, cancelled, failed }

/// Small seam around Play Core so update policy and UI can be tested without
/// invoking a platform channel.
abstract interface class AppUpdateService {
  Future<AppUpdateCheck> checkForUpdate();

  Future<AppUpdateDownloadResult> startFlexibleUpdate();

  Future<void> completeFlexibleUpdate();
}

/// Android implementation backed by the official Google Play update flow.
///
/// An AAB installed by `flutter run`, adb, or an APK file has no Play ownership
/// and Play will report that the API is unavailable. That is an expected
/// result, not an app-startup failure.
class GooglePlayAppUpdateService implements AppUpdateService {
  @override
  Future<AppUpdateCheck> checkForUpdate() async {
    // A debug/sideloaded build has no Play ownership, so calling Play Core is
    // guaranteed to fail. Internal and production track AABs are release
    // builds and take the real path below.
    if (!Platform.isAndroid || kDebugMode) {
      return const AppUpdateCheck(AppUpdateAvailability.unsupported);
    }

    final info = await InAppUpdate.checkForUpdate();
    if (info.installStatus == InstallStatus.downloaded) {
      return AppUpdateCheck(
        AppUpdateAvailability.readyToInstall,
        availableVersionCode: info.availableVersionCode,
      );
    }

    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      return AppUpdateCheck(
        info.flexibleUpdateAllowed
            ? AppUpdateAvailability.available
            : AppUpdateAvailability.availableInPlayStoreOnly,
        availableVersionCode: info.availableVersionCode,
      );
    }

    return const AppUpdateCheck(AppUpdateAvailability.upToDate);
  }

  @override
  Future<AppUpdateDownloadResult> startFlexibleUpdate() async {
    final result = await InAppUpdate.startFlexibleUpdate();
    return switch (result) {
      AppUpdateResult.success => AppUpdateDownloadResult.downloaded,
      AppUpdateResult.userDeniedUpdate => AppUpdateDownloadResult.cancelled,
      AppUpdateResult.inAppUpdateFailed => AppUpdateDownloadResult.failed,
    };
  }

  @override
  Future<void> completeFlexibleUpdate() {
    return InAppUpdate.completeFlexibleUpdate();
  }
}
