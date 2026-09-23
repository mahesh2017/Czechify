import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../data/sync/sync_service.dart';

/// Requests a sync when the app resumes or a network interface becomes
/// available. Connectivity is only a trigger—not proof of internet access—so
/// all network errors remain handled by the durable sync service.
class SyncTriggerCoordinator with WidgetsBindingObserver {
  SyncTriggerCoordinator(
    this._syncService, {
    Connectivity? connectivity,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    this.alsoRun,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _subscription = (connectivityChanges ??
            (connectivity ?? Connectivity()).onConnectivityChanged)
        .listen(_onConnectivityChanged);
  }

  final SyncService _syncService;

  /// Other durable uploads that want the same resume/connectivity signal,
  /// such as queued referral receipts. Must not throw.
  final void Function()? alsoRun;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (results.any((result) => result != ConnectivityResult.none)) {
      unawaited(_syncService.sync());
      alsoRun?.call();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncService.sync());
      alsoRun?.call();
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _subscription.cancel();
  }
}
