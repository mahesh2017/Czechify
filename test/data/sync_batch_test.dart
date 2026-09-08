import 'dart:async';
import 'dart:convert';

import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/data/sync/device_id.dart';
import 'package:czechify/data/sync/sync_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Backend extends BackendService {
  _Backend(this.client);
  @override
  final SupabaseClient client;
  @override
  bool get isEnabled => true;
  @override
  String? userId = 'owner-a';
}

class _Device extends DeviceId {
  _Device() : super(const FlutterSecureStorage());
  Completer<String>? gate;
  @override
  Future<String> get() async => gate == null ? 'device' : await gate!.future;
}

void main() {
  late AppDatabase db;
  late _Backend backend;
  late _Device device;
  late SyncService sync;
  late DateTime now;
  late List<http.Request> requests;
  late Map<String, Map<String, dynamic>> server;
  String? rejectedKey;
  String? errorCode;
  bool loseResponse = false;
  void Function()? afterCommit;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    now = DateTime.utc(2026, 9, 8);
    requests = [];
    server = {};
    rejectedKey = null;
    errorCode = null;
    loseResponse = false;
    afterCommit = null;
    final client = SupabaseClient(
      'https://sync-test.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE') {
          server.remove(request.url.queryParameters['key']!.substring(3));
          return http.Response('', 204, request: request);
        }
        final decoded = jsonDecode(request.body);
        final records =
            (decoded is List ? decoded : [decoded])
                .cast<Map<String, dynamic>>();
        if (errorCode != null || records.any((r) => r['key'] == rejectedKey)) {
          return http.Response(
            jsonEncode({
              'code': errorCode ?? '23514',
              'message': 'Rejected row',
            }),
            400,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        // Model the HTTP transaction boundary: rejection above commits none.
        for (final record in records) {
          server[record['key'] as String] = record;
        }
        afterCommit?.call();
        if (loseResponse) throw http.ClientException('Response lost');
        return http.Response('', 201, request: request);
      }),
    );
    backend = _Backend(client);
    device = _Device();
    sync = SyncService(
      db: db,
      backend: SupabaseSyncBackend(backend: backend, deviceId: device),
      clock: () => now,
    );
  });

  tearDown(() async {
    await backend.client.dispose();
    await db.close();
  });

  Future<void> enqueue(
    String key, {
    int value = 1,
    Map<String, dynamic>? extra,
    String entity = 'user_progress',
    String op = 'upsert',
    String? queueKey,
  }) => db.syncDao.enqueue(
    entity: entity,
    entityKey: queueKey ?? key,
    payload: {'key': key, if (op == 'upsert') 'value': value, ...?extra},
    op: op,
  );

  test('205 distinct mutations use three real HTTP array upserts', () async {
    for (var i = 0; i < 205; i++) {
      await enqueue('key-$i', extra: {'user_id': 'forged-owner'});
    }
    await sync.push();
    expect(requests, hasLength(3));
    expect(requests.map((r) => (jsonDecode(r.body) as List).length), [
      100,
      100,
      5,
    ]);
    expect(server, hasLength(205));
    expect(server.values.map((r) => r['user_id']), everyElement('owner-a'));
    expect(server.values.map((r) => r['device_id']).toSet(), hasLength(205));
    expect(
      requests.every(
        (r) => r.url.queryParameters['on_conflict'] == 'user_id,key',
      ),
      isTrue,
    );
    expect(await db.syncDao.pendingCount(), 0);
  });

  test(
    'an invalid row is isolated; healthy rows commit and only it backs off',
    () async {
      for (final key in ['a', 'b', 'poison', 'c', 'd']) {
        await enqueue(key);
      }
      rejectedKey = 'poison';
      await sync.push();
      expect(server.keys, unorderedEquals(['a', 'b', 'c', 'd']));
      expect(requests.length, lessThanOrEqualTo(7));
      final remaining = await db.select(db.syncQueue).getSingle();
      expect(remaining.entityKey, 'poison');
      expect(remaining.attempts, 1);
      // Drift reconstructs timestamps in local time, so compare the instant
      // rather than the wall clock — the same row read on a machine set to UTC
      // and one set to CEST is the same backoff.
      expect(
        remaining.nextAttemptAt?.toUtc(),
        now.add(const Duration(seconds: 2)),
      );
      rejectedKey = null;
      now = now.add(const Duration(seconds: 2));
      await sync.push();
      expect(server, hasLength(5));
      expect(await db.syncDao.pendingCount(), 0);
    },
  );

  test(
    'lost response retries the committed batch with identical mutation ids',
    () async {
      for (final key in ['a', 'b', 'c']) {
        await enqueue(key);
      }
      loseResponse = true;
      await sync.push();
      expect(requests, hasLength(1));
      expect(server, hasLength(3));
      expect(await db.syncDao.pendingCount(), 3);
      expect(
        (await db.select(db.syncQueue).get()).map((r) => r.attempts),
        everyElement(1),
      );
      final original = requests.single.body;
      loseResponse = false;
      now = now.add(const Duration(seconds: 2));
      await sync.push();
      expect(requests, hasLength(2));
      expect(requests.last.body, original);
      expect(server, hasLength(3));
      expect(await db.syncDao.pendingCount(), 0);
    },
  );

  test(
    'permission failure does not fan out into one request per row',
    () async {
      for (var i = 0; i < 100; i++) {
        await enqueue('key-$i');
      }
      errorCode = '42501';
      await sync.push();
      expect(requests, hasLength(1));
      expect(server, isEmpty);
      expect(await db.syncDao.pendingCount(), 100);
      expect(
        (await db.select(db.syncQueue).get()).map((r) => r.attempts),
        everyElement(1),
      );
    },
  );

  test(
    'repeated natural keys stay ordered even with different queue keys',
    () async {
      await enqueue('same', value: 1, queueKey: 'first');
      await enqueue('same', value: 2, queueKey: 'second');
      await (db.update(
        db.syncQueue,
      )).write(SyncQueueCompanion(updatedAt: drift.Value(now)));
      await sync.push();
      expect(requests, hasLength(2));
      expect(server['same']!['value'], 2);
      final first = (jsonDecode(requests.first.body) as List).single;
      final last = (jsonDecode(requests.last.body) as List).single;
      expect(
        (last['device_id'] as String).compareTo(first['device_id'] as String),
        greaterThan(0),
      );
    },
  );

  test(
    'deletes, tables and differing columns preserve FIFO boundaries',
    () async {
      await enqueue('a');
      await enqueue('b', extra: {'optional': 'present'});
      await enqueue('c', entity: 'learner_profiles');
      await enqueue('a', op: 'delete');
      await enqueue('a', value: 2);
      await sync.push();
      expect(requests, hasLength(5));
      expect(requests.map((r) => r.method), [
        'POST',
        'POST',
        'POST',
        'DELETE',
        'POST',
      ]);
      expect(requests[2].url.path, endsWith('/learner_profiles'));
      expect(requests[3].url.queryParameters['user_id'], 'eq.owner-a');
      expect(server['a']!['value'], 2);
    },
  );

  test('large payloads are bounded independently of row count', () async {
    for (var i = 0; i < 3; i++) {
      await enqueue('key-$i', extra: {'text': 'č' * 70000});
    }
    await sync.push();
    expect(requests, hasLength(3));
    expect(await db.syncDao.pendingCount(), 0);
  });

  test(
    'malformed and unknown rows do not trap later valid mutations',
    () async {
      await enqueue('broken');
      await (db.update(
        db.syncQueue,
      )).write(const SyncQueueCompanion(payload: drift.Value('{bad')));
      await enqueue('unknown', entity: 'unknown');
      await enqueue('good');
      await sync.push();
      expect(server.keys, ['good']);
      expect(await db.syncDao.pendingCount(), 2);
    },
  );

  test(
    'account change while obtaining device id sends and acknowledges nothing',
    () async {
      await enqueue('a');
      device.gate = Completer<String>();
      final pending = sync.push();
      await Future<void>.delayed(Duration.zero);
      backend.userId = 'owner-b';
      device.gate!.complete('device');
      await pending;
      expect(requests, isEmpty);
      expect(await db.syncDao.pendingCount(), 1);
    },
  );

  test(
    'account change after a batch stops before sending the next batch',
    () async {
      for (var i = 0; i < 101; i++) {
        await enqueue('key-$i');
      }
      afterCommit = () {
        backend.userId = 'owner-b';
      };
      await sync.push();
      expect(requests, hasLength(1));
      expect(server.values.map((r) => r['user_id']), everyElement('owner-a'));
      expect(await db.syncDao.pendingCount(), 1);
    },
  );
}
