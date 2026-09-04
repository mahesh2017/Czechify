import 'dart:async';

import 'package:czechify/data/database/daos/sync_dao.dart';
import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/sync/sync_service.dart';
import 'package:czechify/presentation/coordinators/sync_trigger_coordinator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineBackend implements SyncBackend {
  @override
  bool get isReady => false;
  @override
  String? get userId => null;
  @override
  Future<String> deviceId() async => 'test-device';
  @override
  Future<List<Map<String, dynamic>>> pullPage(
    String entity, {
    required PullCursor? cursor,
    required int limit,
  }) async => const [];
  @override
  Future<void> send(
    SyncQueueData row, {
    required String onConflict,
    required String mutationDeviceId,
  }) async {}
}

class _CountingSyncService extends SyncService {
  _CountingSyncService(AppDatabase database)
    : super(db: database, backend: _OfflineBackend());

  int calls = 0;

  @override
  Future<void> sync() async {
    calls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('network restoration and app resume trigger sync', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final changes = StreamController<List<ConnectivityResult>>();
    final service = _CountingSyncService(database);
    final coordinator = SyncTriggerCoordinator(
      service,
      connectivityChanges: changes.stream,
    );
    addTearDown(() async {
      await coordinator.dispose();
      await changes.close();
      await database.close();
    });

    changes.add([ConnectivityResult.none]);
    await tester.pump();
    expect(service.calls, 0);

    changes.add([ConnectivityResult.wifi]);
    await tester.pump();
    expect(service.calls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.calls, 2);
  });
}
