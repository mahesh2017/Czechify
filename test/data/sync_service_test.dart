import 'dart:async';

import 'package:ceskina_pro/data/database/daos/sync_dao.dart';
import 'package:ceskina_pro/data/database/database.dart';
import 'package:ceskina_pro/data/sync/sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSyncBackend implements SyncBackend {
  final rows = <String, List<Map<String, dynamic>>>{};
  final sentKeys = <String>[];
  final failingKeys = <String>{};
  final failingPullEntities = <String>{};
  Completer<void>? sendGate;
  int activeSends = 0;
  int maxActiveSends = 0;

  @override
  bool isReady = true;

  @override
  String? userId = 'user-1';

  @override
  Future<String> deviceId() async => 'local-device';

  @override
  Future<void> send(SyncQueueData row, {required String onConflict}) async {
    activeSends++;
    if (activeSends > maxActiveSends) maxActiveSends = activeSends;
    try {
      await sendGate?.future;
      sentKeys.add(row.entityKey);
      if (failingKeys.contains(row.entityKey)) {
        throw StateError('rejected ${row.entityKey}');
      }
    } finally {
      activeSends--;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullPage(
    String entity, {
    required PullCursor? cursor,
    required int limit,
  }) async {
    if (failingPullEntities.contains(entity)) {
      throw StateError('pull rejected for $entity');
    }
    final source = rows[entity] ?? const [];
    final ordered = [...source]
      ..sort((a, b) => (a['revision'] as num).compareTo(b['revision'] as num));
    return ordered
        .where((row) {
          if (cursor == null) return true;
          return (row['revision'] as num).toInt() > cursor.revision;
        })
        .take(limit)
        .toList();
  }
}

void main() {
  late AppDatabase database;
  late FakeSyncBackend backend;
  late DateTime now;
  late SyncService service;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    backend = FakeSyncBackend();
    now = DateTime.utc(2026, 7, 20);
    service = SyncService(db: database, backend: backend, clock: () => now);
  });

  tearDown(() => database.close());

  Future<void> enqueue(String key) => database.syncDao.enqueue(
    entity: 'user_progress',
    entityKey: key,
    payload: {'key': key, 'value': 1},
  );

  test('concurrent sync callers share one serialized run', () async {
    await enqueue('streak');
    backend.sendGate = Completer<void>();

    final first = service.sync();
    final second = service.sync();
    await Future<void>.delayed(Duration.zero);

    expect(backend.activeSends, 1);
    expect(backend.maxActiveSends, 1);
    backend.sendGate!.complete();
    await Future.wait([first, second]);

    expect(backend.sentKeys, ['streak']);
    expect(await database.syncDao.pendingCount(), 0);
  });

  test(
    'poison row does not block later rows and is eventually dead-lettered',
    () async {
      await enqueue('poison');
      await enqueue('healthy');
      backend.failingKeys.add('poison');

      await service.push();
      expect(backend.sentKeys, containsAll(['poison', 'healthy']));
      expect(await database.syncDao.pendingCount(), 1);

      for (final seconds in [2, 4, 8, 16]) {
        now = now.add(Duration(seconds: seconds));
        await service.push();
      }

      expect(await database.syncDao.deadLetterCount(), 1);
      expect(await database.syncDao.pending(now: now), isEmpty);
      final failed = await database.select(database.syncQueue).getSingle();
      expect(failed.attempts, 5);
      expect(failed.deadLetteredAt, isNotNull);
      expect(failed.lastError, contains('rejected poison'));
    },
  );

  test('a dead-lettered row can be revived once its cause clears', () async {
    // Dead-lettering was terminal: the row was counted and then stranded, so a
    // change made while a session was expired never reached the backend and
    // nothing offered a way back. Most causes are transient.
    await enqueue('poison');
    backend.failingKeys.add('poison');
    for (final seconds in [0, 2, 4, 8, 16]) {
      now = now.add(Duration(seconds: seconds));
      await service.push();
    }
    expect(await database.syncDao.deadLetterCount(), 1);

    backend.failingKeys.clear();
    backend.sentKeys.clear();
    expect(await database.syncDao.retryDeadLettered(), 1);

    // Eligible immediately — a deliberate retry should not wait out a backoff
    // accrued by the failure the learner has just resolved.
    expect(await database.syncDao.pending(now: now), hasLength(1));
    await service.push();

    expect(backend.sentKeys, ['poison']);
    expect(await database.syncDao.deadLetterCount(), 0);
    expect(await database.syncDao.pendingCount(), 0);
  });

  test('reviving restores the full backoff ladder', () async {
    // A revived row that fails again must not dead-letter on its first
    // stumble, or one retry would burn the second chance it was given.
    await enqueue('poison');
    backend.failingKeys.add('poison');
    for (final seconds in [0, 2, 4, 8, 16]) {
      now = now.add(Duration(seconds: seconds));
      await service.push();
    }
    await database.syncDao.retryDeadLettered();

    await service.push();

    final row = await database.select(database.syncQueue).getSingle();
    expect(row.attempts, 1);
    expect(row.deadLetteredAt, isNull);
  });

  test('revision cursor paginates every row across pages', () async {
    final timestamp = DateTime.utc(2026, 7, 20, 12).toIso8601String();
    backend.rows['lesson_progress'] = List.generate(205, (index) {
      final id = index + 1;
      return {
        'revision': id,
        'updated_at': timestamp,
        'device_id': 'remote-device',
        'lesson_id': id,
        'unit_id': 1,
        'is_completed': true,
        'best_score': 80.0,
        'attempts': 1,
        'last_attempted': timestamp,
      };
    });

    await service.pull();

    expect(
      await database.select(database.lessonProgress).get(),
      hasLength(205),
    );
    final cursor = await database.syncDao.pullCursor('lesson_progress');
    expect(cursor?.revision, 205);
  });

  test(
    'a lower updated_at but higher revision is never stranded (clock skew)',
    () async {
      // First pull sees one row at revision 10.
      backend.rows['lesson_progress'] = [
        {
          'revision': 10,
          'updated_at': DateTime.utc(2026, 7, 20, 12).toIso8601String(),
          'device_id': 'remote-device',
          'lesson_id': 1,
          'unit_id': 1,
          'is_completed': true,
          'best_score': 80.0,
          'attempts': 1,
          'last_attempted': DateTime.utc(2026, 7, 20, 12).toIso8601String(),
        },
      ];
      await service.pull();
      expect(await database.syncDao.pullCursor('lesson_progress'), isNotNull);

      // A second device (lagging clock) writes an EARLIER updated_at but the
      // server stamps a HIGHER revision. Under the old (updated_at, sync_id)
      // cursor this row was stranded; under revision it must still be pulled.
      backend.rows['lesson_progress']!.add({
        'revision': 11,
        'updated_at': DateTime.utc(2026, 7, 20, 9).toIso8601String(),
        'device_id': 'remote-device',
        'lesson_id': 2,
        'unit_id': 1,
        'is_completed': true,
        'best_score': 90.0,
        'attempts': 1,
        'last_attempted': DateTime.utc(2026, 7, 20, 9).toIso8601String(),
      });

      await service.pull();

      final rows = await database.select(database.lessonProgress).get();
      expect(rows.map((r) => r.lessonId), containsAll(<int>[1, 2]));
      expect(
        (await database.syncDao.pullCursor('lesson_progress'))?.revision,
        11,
      );
    },
  );

  test(
    'gamification state is pulled without echoing into the outbox',
    () async {
      final timestamp = DateTime.utc(2026, 7, 20, 13).toIso8601String();
      backend.rows['gamification_state'] = [
        {
          'revision': 1,
          'updated_at': timestamp,
          'device_id': 'remote-device',
          'key': 'primary',
          'hearts': 3,
          'max_hearts': 5,
          'current_streak': 4,
          'longest_streak': 8,
          'total_xp': 240,
          'daily_xp': 30,
          'daily_goal_xp': 60,
          'gems': 7,
          'earned_badges': ['first', 'streak_7'],
          'last_heart_refill': null,
          'streak_freeze_available': false,
          'last_open_date': '2026-07-20',
          'daily_xp_reset_date': '2026-07-20',
        },
      ];

      await service.pull();

      final state = await database.gamificationDao.load();
      expect(state?.hearts, 3);
      expect(state?.totalXp, 240);
      expect(state?.earnedBadges, '["first","streak_7"]');
      expect(await database.syncDao.pendingCount(), 0);
    },
  );

  test(
    'account snapshot download failure leaves local data untouched',
    () async {
      await database.customStatement(
        "INSERT INTO user_progress (key,value) VALUES ('streak','9')",
      );
      backend.failingPullEntities.add('lesson_progress');
      await service.beginAccountTransition();

      try {
        await expectLater(service.downloadAccountSnapshot(), throwsStateError);
      } finally {
        service.endAccountTransition();
      }

      final rows = await database.select(database.userProgress).get();
      expect(rows, hasLength(1));
      expect(rows.single.key, 'streak');
      expect(rows.single.value, '9');
    },
  );

  test(
    'account install restores rows this device authored',
    () async {
      // The returning account's most recent work was done on THIS install, so
      // every row carries the local device id. Pull skips such rows because
      // local state already has them; an install must not, because the local
      // database was just cleared. Skipping them silently lost the learner's
      // own progress on their own phone.
      backend.rows['lesson_progress'] = [
        {
          'revision': 1,
          'device_id': 'local-device',
          'lesson_id': 1,
          'unit_id': 1,
          'is_completed': true,
          'best_score': 0.9,
          'attempts': 2,
          'last_attempted': DateTime.utc(2026, 7, 19).toIso8601String(),
        },
        {
          'revision': 2,
          'device_id': 'other-device',
          'lesson_id': 2,
          'unit_id': 1,
          'is_completed': true,
          'best_score': 0.8,
          'attempts': 1,
          'last_attempted': DateTime.utc(2026, 7, 19).toIso8601String(),
        },
      ];

      await service.beginAccountTransition();
      try {
        final snapshot = await service.downloadAccountSnapshot();
        await database.transaction(() async {
          await database.clearLearnerDataRows();
          await service.installAccountSnapshot(snapshot);
        });
      } finally {
        service.endAccountTransition();
      }

      final rows = await database.select(database.lessonProgress).get();
      expect(
        rows.map((r) => r.lessonId),
        containsAll(<int>[1, 2]),
        reason: 'both the local-device and remote-device rows must install',
      );
    },
  );

  test(
    'ordinary sync cannot push while an account transition is paused',
    () async {
      await enqueue('old-account-row');
      await service.beginAccountTransition();
      try {
        await service.sync();
        expect(backend.sentKeys, isEmpty);
        expect(await database.syncDao.pendingCount(), 1);
      } finally {
        service.endAccountTransition();
      }
    },
  );
}
