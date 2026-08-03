import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database.dart';
import '../database/daos/sync_dao.dart';
import 'backend_service.dart';
import 'device_id.dart';

abstract class SyncBackend {
  bool get isReady;
  String? get userId;
  Future<String> deviceId();
  Future<void> send(SyncQueueData row, {required String onConflict});
  Future<List<Map<String, dynamic>>> pullPage(
    String entity, {
    required PullCursor? cursor,
    required int limit,
  });
}

class SupabaseSyncBackend implements SyncBackend {
  SupabaseSyncBackend({
    required BackendService backend,
    required DeviceId deviceId,
  }) : _backend = backend,
       _deviceId = deviceId;

  final BackendService _backend;
  final DeviceId _deviceId;

  @override
  bool get isReady => _backend.isEnabled && _backend.isSignedIn;

  @override
  String? get userId => _backend.userId;

  @override
  Future<String> deviceId() => _deviceId.get();

  @override
  Future<List<Map<String, dynamic>>> pullPage(
    String entity, {
    required PullCursor? cursor,
    required int limit,
  }) async {
    final owner = userId;
    if (owner == null) return const [];
    var query = Supabase.instance.client
        .from(entity)
        .select()
        .eq('user_id', owner);
    if (cursor != null) {
      query = query.gt('revision', cursor.revision);
    }
    final rows = await query.order('revision').limit(limit);
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<void> send(SyncQueueData row, {required String onConflict}) async {
    final owner = userId;
    if (owner == null) return;
    final client = Supabase.instance.client;
    if (row.op == 'delete') {
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      var query = client.from(row.entity).delete().eq('user_id', owner);
      payload.forEach((key, value) {
        query = query.eq(key, value as Object);
      });
      await query;
      return;
    }
    final record = <String, dynamic>{
      ...jsonDecode(row.payload) as Map<String, dynamic>,
      'user_id': owner,
      'device_id': await deviceId(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
    };
    await client.from(row.entity).upsert(record, onConflict: onConflict);
  }
}

class AccountSyncSnapshot {
  const AccountSyncSnapshot(this.rows, this.cursors);
  final Map<String, List<Map<String, dynamic>>> rows;
  final Map<String, PullCursor> cursors;
}

/// Drains the local sync outbox to Supabase.
///
/// Queued mutations are pushed before paginated remote changes are pulled and
/// domain-merged. One serialized run is shared by concurrent callers.
///
/// Every method is a safe no-op when the backend is disabled or signed out.
class SyncService {
  SyncService({
    required AppDatabase db,
    required SyncBackend backend,
    DateTime Function()? clock,
    Logger? log,
  }) : _db = db,
       _backend = backend,
       _clock = clock ?? DateTime.now,
       _log = log ?? Logger('SyncService');
  // Named-private initializing formals read worse than these plain fields.
  // ignore_for_file: prefer_initializing_formals

  final AppDatabase _db;
  final SyncBackend _backend;
  final DateTime Function() _clock;
  final Logger _log;
  Future<void>? _activeRun;
  bool _accountTransition = false;

  /// Conflict target (composite natural key) for each backend table. Order
  /// matters for pull: `custom_cards` precedes `srs_cards` so a manual card's
  /// definition is materialized locally before its SRS scheduling row (which
  /// references it by content_uid) is merged.
  static const _conflictKeys = <String, String>{
    'lesson_progress': 'user_id,lesson_id',
    'earned_badges': 'user_id,badge_id',
    'user_progress': 'user_id,key',
    'custom_cards': 'user_id,content_uid',
    'srs_cards': 'user_id,card_type,content_key',
    'gamification_state': 'user_id,key',
  };

  /// Push all eligible outbox rows. Concurrent callers share one run.
  Future<void> push() => _serialized(_push);

  Future<void> _push() async {
    if (!_backend.isReady) return;
    var batch = await _db.syncDao.pending(now: _clock());
    while (batch.isNotEmpty) {
      final acked = <int>[];
      for (final row in batch) {
        try {
          final conflict = _conflictKeys[row.entity];
          if (conflict == null) {
            throw StateError('Unknown sync entity: ${row.entity}');
          }
          await _backend.send(row, onConflict: conflict);
          acked.add(row.id);
        } catch (e) {
          await _db.syncDao.markFailed(row.id, error: e, now: _clock());
          _log.warning('Push failed for ${row.entity}/${row.entityKey}', e);
        }
      }
      if (acked.isNotEmpty) await _db.syncDao.ack(acked);
      batch = await _db.syncDao.pending(now: _clock());
    }
  }

  /// Full sync cycle: push local changes, then pull remote ones.
  Future<void> sync() => _serialized(() async {
    await _push();
    await _pull(strict: false);
  });

  /// Pull remote changes since the last cursor and merge them into Drift.
  /// Merges are domain-aware/monotonic (see the DAO merge methods), so this is
  /// safe to run repeatedly and in any order relative to local edits.
  Future<void> pull({bool strict = false}) =>
      _serialized(() => _pull(strict: strict));

  /// Pauses background sync after any active run completes. While paused,
  /// ordinary sync triggers are harmless no-ops so old-account outbox rows
  /// cannot be pushed under a newly installed session.
  Future<void> beginAccountTransition() async {
    final active = _activeRun;
    if (active != null) await active;
    _accountTransition = true;
  }

  void endAccountTransition() {
    _accountTransition = false;
  }

  /// Downloads a target account without mutating local state. Network work is
  /// intentionally completed before the atomic database replacement begins.
  Future<AccountSyncSnapshot> downloadAccountSnapshot() async {
    if (!_accountTransition) {
      throw StateError('Account install pull requires an account transition.');
    }
    if (!_backend.isReady) {
      throw StateError('Target account backend is unavailable.');
    }
    final rowsByEntity = <String, List<Map<String, dynamic>>>{};
    final cursors = <String, PullCursor>{};
    for (final entity in _conflictKeys.keys) {
      final collected = <Map<String, dynamic>>[];
      PullCursor? cursor;
      while (true) {
        final rows = await _backend.pullPage(
          entity,
          cursor: cursor,
          limit: 100,
        );
        collected.addAll(rows);
        if (rows.isEmpty) break;
        final revision = (rows.last['revision'] as num?)?.toInt();
        if (revision == null) {
          throw StateError('$entity returned an invalid sync cursor.');
        }
        cursor = PullCursor(revision: revision);
        if (rows.length < 100) break;
      }
      rowsByEntity[entity] = collected;
      if (cursor != null) cursors[entity] = cursor;
    }
    return AccountSyncSnapshot(rowsByEntity, cursors);
  }

  /// Applies an already downloaded snapshot inside the caller's transaction.
  ///
  /// Every row is applied, including rows this device authored. That is the
  /// opposite of [_pull], and deliberately so: an install runs immediately
  /// after the local database was cleared, so "we already have this locally"
  /// is false for every row. Skipping our own `device_id` here silently lost
  /// everything the account last wrote from this install — the exact data a
  /// learner returning to a previous account expects to find waiting.
  Future<void> installAccountSnapshot(AccountSyncSnapshot snapshot) async {
    if (!_accountTransition) {
      throw StateError('Account install requires an account transition.');
    }
    for (final entity in _conflictKeys.keys) {
      for (final row in snapshot.rows[entity] ?? const []) {
        await _applyRemote(entity, row);
      }
      final cursor = snapshot.cursors[entity];
      if (cursor != null) await _db.syncDao.setPullCursor(entity, cursor);
    }
  }

  Future<void> _pull({required bool strict}) async {
    if (!_backend.isReady) return;
    final deviceId = await _backend.deviceId();
    for (final entity in _conflictKeys.keys) {
      try {
        var cursor = await _db.syncDao.pullCursor(entity);
        while (true) {
          final rows = await _backend.pullPage(
            entity,
            cursor: cursor,
            limit: 100,
          );
          for (final row in rows.cast<Map<String, dynamic>>()) {
            // Skipping our own rows is only correct here, where local state is
            // already current. See [installAccountSnapshot] for why an install
            // must apply them.
            if (row['device_id'] != deviceId) await _applyRemote(entity, row);
          }
          if (rows.isEmpty) break;
          final last = rows.last;
          final revision = (last['revision'] as num?)?.toInt();
          if (revision == null) {
            throw StateError('$entity returned an invalid sync cursor.');
          }
          final nextCursor = PullCursor(revision: revision);
          await _db.syncDao.setPullCursor(entity, nextCursor);
          cursor = nextCursor;
          if (rows.length < 100) break;
        }
      } catch (e) {
        _log.warning('Pull failed for $entity', e);
        if (strict) rethrow;
      }
    }
  }

  Future<void> _serialized(Future<void> Function() action) {
    if (_accountTransition) return Future.value();
    final active = _activeRun;
    if (active != null) return active;
    final completer = Completer<void>();
    _activeRun = completer.future;
    () async {
      try {
        await action();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _activeRun = null;
      }
    }();
    return completer.future;
  }

  DateTime? _ts(Object? iso) =>
      iso is String ? DateTime.tryParse(iso)?.toLocal() : null;

  Future<void> _applyRemote(String entity, Map<String, dynamic> r) async {
    switch (entity) {
      case 'lesson_progress':
        await _db.progressDao.mergeLessonProgress(
          lessonId: (r['lesson_id'] as num).toInt(),
          unitId: (r['unit_id'] as num).toInt(),
          isCompleted: r['is_completed'] as bool? ?? false,
          bestScore: (r['best_score'] as num?)?.toDouble() ?? 0,
          attempts: (r['attempts'] as num?)?.toInt() ?? 0,
          lastAttempted: _ts(r['last_attempted']),
        );
        break;
      case 'earned_badges':
        await _db.progressDao.mergeBadge(
          r['badge_id'] as String,
          _ts(r['earned_at']) ?? DateTime.now(),
        );
        break;
      case 'user_progress':
        await _db.progressDao.mergeUserProgress(
          r['key'] as String,
          _decodeKvValue(r['value']),
        );
        break;
      case 'custom_cards':
        await _db.vocabularyDao.mergeCustomCard(
          contentUid: r['content_uid'] as String,
          wordCz: r['word_cz'] as String,
          wordEn: r['word_en'] as String,
          ipa: r['ipa'] as String?,
        );
        break;
      case 'srs_cards':
        await _db.vocabularyDao.mergeSrsCard(
          cardType: r['card_type'] as String,
          contentKey: r['content_key'] as String,
          stability: (r['stability'] as num?)?.toDouble() ?? 0,
          difficulty: (r['difficulty'] as num?)?.toDouble() ?? 0,
          due: _ts(r['due']) ?? DateTime.now(),
          reps: (r['reps'] as num?)?.toInt() ?? 0,
          state: r['state'] as String? ?? 'newCard',
          lastReviewed: _ts(r['last_reviewed']),
        );
        break;
      case 'gamification_state':
        await _db.gamificationDao.mergeRemote(
          hearts: (r['hearts'] as num?)?.toInt() ?? 5,
          maxHearts: (r['max_hearts'] as num?)?.toInt() ?? 5,
          currentStreak: (r['current_streak'] as num?)?.toInt() ?? 0,
          longestStreak: (r['longest_streak'] as num?)?.toInt() ?? 0,
          totalXp: (r['total_xp'] as num?)?.toInt() ?? 0,
          dailyXp: (r['daily_xp'] as num?)?.toInt() ?? 0,
          dailyGoalXp: (r['daily_goal_xp'] as num?)?.toInt() ?? 50,
          gems: (r['gems'] as num?)?.toInt() ?? 0,
          earnedBadgesJson: _decodeGamificationBadges(r['earned_badges']),
          lastHeartRefill: _ts(r['last_heart_refill']),
          streakFreezeAvailable: r['streak_freeze_available'] as bool? ?? true,
          lastOpenDate: r['last_open_date'] as String?,
          dailyXpResetDate: r['daily_xp_reset_date'] as String?,
          updatedAt: _ts(r['updated_at']) ?? DateTime.now(),
        );
        break;
    }
  }

  String _decodeGamificationBadges(Object? value) {
    if (value is String) return value;
    if (value is List) return jsonEncode(value);
    return '[]';
  }

  /// user_progress.value is jsonb. Locally it's an app-defined string; unwrap a
  /// bare JSON string, otherwise re-encode structured JSON back to a string.
  String _decodeKvValue(Object? value) {
    if (value is String) return value;
    return jsonEncode(value);
  }
}
