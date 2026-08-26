import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/updates/app_update_service.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return GooglePlayAppUpdateService();
});

final appUpdateManagerProvider = Provider<AppUpdateManager>((ref) {
  return AppUpdateManager(ref.read(appUpdateServiceProvider));
});

/// Coordinates Play calls shared by the automatic prompt and About screen.
///
/// Play Core permits only one update flow at a time. The manager deduplicates
/// simultaneous checks and owns the 24-hour automatic-prompt cooldown; a
/// manual check is never hidden by that cooldown.
class AppUpdateManager {
  AppUpdateManager(
    this._service, {
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  static const automaticPromptCooldown = Duration(hours: 24);
  static const automaticCheckSessionCooldown = Duration(minutes: 15);

  static const _dismissedVersionKey = 'update_dismissed_version_code';
  static const _dismissedAtKey = 'update_dismissed_at_ms';

  final AppUpdateService _service;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;

  Future<AppUpdateCheck>? _activeCheck;
  Future<AppUpdateDownloadResult>? _activeDownload;
  DateTime? _lastAutomaticCheck;
  bool _uiFlowActive = false;
  bool _updateReady = false;

  bool get updateReady => _updateReady;

  bool tryBeginUiFlow() {
    if (_uiFlowActive) return false;
    _uiFlowActive = true;
    return true;
  }

  void endUiFlow() => _uiFlowActive = false;

  bool shouldRunAutomaticCheck() {
    final last = _lastAutomaticCheck;
    if (last != null &&
        _now().difference(last) < automaticCheckSessionCooldown) {
      return false;
    }
    _lastAutomaticCheck = _now();
    return true;
  }

  Future<AppUpdateCheck> checkForUpdate() {
    final existing = _activeCheck;
    if (existing != null) return existing;

    final future = _runCheck();
    _activeCheck = future;
    return future;
  }

  Future<AppUpdateCheck> _runCheck() async {
    try {
      return await _service.checkForUpdate();
    } finally {
      _activeCheck = null;
    }
  }

  Future<bool> shouldOfferAutomatically(AppUpdateCheck check) async {
    if (check.availability == AppUpdateAvailability.readyToInstall) return true;
    if (check.availability != AppUpdateAvailability.available &&
        check.availability != AppUpdateAvailability.availableInPlayStoreOnly) {
      return false;
    }

    final versionCode = check.availableVersionCode;
    if (versionCode == null) return true;
    final prefs = await _preferences();
    if (prefs.getInt(_dismissedVersionKey) != versionCode) return true;

    final dismissedAtMs = prefs.getInt(_dismissedAtKey);
    if (dismissedAtMs == null) return true;
    final dismissedAt = DateTime.fromMillisecondsSinceEpoch(dismissedAtMs);
    return _now().difference(dismissedAt) >= automaticPromptCooldown;
  }

  Future<void> rememberDismissal(int? versionCode) async {
    if (versionCode == null) return;
    final prefs = await _preferences();
    await prefs.setInt(_dismissedVersionKey, versionCode);
    await prefs.setInt(_dismissedAtKey, _now().millisecondsSinceEpoch);
  }

  Future<AppUpdateDownloadResult> startFlexibleUpdate() {
    final existing = _activeDownload;
    if (existing != null) return existing;

    final future = _runDownload();
    _activeDownload = future;
    return future;
  }

  Future<AppUpdateDownloadResult> _runDownload() async {
    try {
      final result = await _service.startFlexibleUpdate();
      if (result == AppUpdateDownloadResult.downloaded) _updateReady = true;
      return result;
    } finally {
      _activeDownload = null;
    }
  }

  Future<void> completeFlexibleUpdate() {
    return _service.completeFlexibleUpdate();
  }

  void rememberReadyToInstall() => _updateReady = true;
}
