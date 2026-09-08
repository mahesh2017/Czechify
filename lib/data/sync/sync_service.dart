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
  Future<void> send(
    SyncQueueData row, {
    required String onConflict,
    required String mutationDeviceId,
  });
  Future<List<Map<String, dynamic>>> pullPage(
    String entity, {
    required PullCursor? cursor,
    required int limit,
  });
}

/// A batch either commits completely or throws. Each mutation retains its
/// original tiebreaker, including when a response is lost and it is retried.
class SyncMutation {
  const SyncMutation(this.row, this.deviceId);
  final SyncQueueData row;
  final String deviceId;
}

abstract interface class BatchSyncBackend {
  Future<void> sendBatch(
    List<SyncMutation> mutations, {
    required String onConflict,
    required String ownerId,
  });
}

class SupabaseSyncBackend implements SyncBackend, BatchSyncBackend {
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
  Future<void> send(
    SyncQueueData row, {
    required String onConflict,
    required String mutationDeviceId,
  }) async {
    final owner = userId;
    if (owner == null) throw StateError('Sync account is unavailable.');
    final client = _backend.client!;
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
      'device_id': mutationDeviceId,
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
    };
    await client.from(row.entity).upsert(record, onConflict: onConflict);
  }

  @override
  Future<void> sendBatch(
    List<SyncMutation> mutations, {
    required String onConflict,
    required String ownerId,
  }) async {
    if (!isReady || userId != ownerId) {
      throw StateError('Sync account changed.');
    }
    final records = [
      for (final mutation in mutations)
        <String, dynamic>{
          ...jsonDecode(mutation.row.payload) as Map<String, dynamic>,
          'user_id': ownerId,
          'device_id': mutation.deviceId,
          'updated_at': mutation.row.updatedAt.toUtc().toIso8601String(),
        },
    ];
    // PostgREST performs the array upsert in one database transaction.
    await _backend.client!
        .from(mutations.first.row.entity)
        .upsert(records, onConflict: onConflict);
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
  static const _mutationSequenceWidth = 20;
  static const _mutationDeviceIdMaxLength = 128;
  static const _mutationSeparator = ':';

  SyncService({
    required AppDatabase db,
    required SyncBackend backend,
    DateTime Function()? clock,
    Logger? log,
    this.onPortablePreferencesChanged,
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
  final FutureOr<void> Function()? onPortablePreferencesChanged;
  Future<void>? _activeRun;
  bool _accountTransition = false;

  /// Conflict target (composite natural key) for each backend table. Order
  /// matters for pull: `custom_cards` precedes `srs_cards` so a manual card's
  /// definition is materialized locally before its SRS scheduling row (which
  /// references it by content_uid) is merged.
  ///
  /// Public so the account-export contract can be checked against it: every
  /// entity synced here holds learner data and must appear in the export the
  /// `account-data` function produces. `custom_cards` was synced for months
  /// without being exported, and nothing could have caught it.
  static const conflictKeys = <String, String>{
    'learner_profiles': 'user_id,key',
    'reminder_preferences': 'user_id,key',
    'placement_profiles': 'user_id,key',
    'lesson_progress': 'user_id,lesson_id',
    'earned_badges': 'user_id,badge_id',
    'user_progress': 'user_id,key',
    'custom_cards': 'user_id,content_uid',
    'srs_cards': 'user_id,card_type,content_key',
    'gamification_state': 'user_id,key',
    // The learning history worth carrying across devices. Both hold
    // client-generated ids, so a push is idempotent and two devices cannot
    // collide. The raw attempt logs stay local — see the migration for why.
    'learning_evidence_events': 'user_id,evidence_id',
    'delayed_transfer_assignments': 'user_id,assignment_id',
    // Reports are append-only and carry a client-generated id, so the upsert
    // is idempotent: a retried push files the same report rather than a
    // second one. Push-only — see [pushOnlyEntities].
    'tutor_reply_reports': 'user_id,report_id',
  };

  /// Entities that travel up but never come back.
  ///
  /// A report is filed, not read: nothing in the app displays one, and the
  /// account export reads them server-side. Pulling them would fetch rows on
  /// every sync for a table no screen touches.
  ///
  /// They still push through the ordinary outbox, so a report filed with no
  /// signal is retried like anything else.
  static const pushOnlyEntities = <String>{'tutor_reply_reports'};

  static Iterable<String> get _pullEntities =>
      conflictKeys.keys.where((e) => !pushOnlyEntities.contains(e));

  /// Push all eligible outbox rows. Concurrent callers share one run.
  Future<void> push() => _serialized(_push);

  Future<void> _push() async {
    if (!_backend.isReady) return;
    final owner = _backend.userId;
    if (owner == null) return;
    String? stableDeviceId;
    var batch = await _db.syncDao.pending(now: _clock());
    while (batch.isNotEmpty) {
      for (var index = 0; index < batch.length;) {
        if (!_backend.isReady || _backend.userId != owner) return;
        final rows = <SyncQueueData>[batch[index++]];
        if (_backend is BatchSyncBackend && rows.first.op == 'upsert') {
          var bytes = utf8.encode(rows.first.payload).length + 256;
          while (index < batch.length && _canBatch(rows, batch[index])) {
            final nextBytes = utf8.encode(batch[index].payload).length + 256;
            if (bytes + nextBytes > 256 * 1024) break;
            bytes += nextBytes;
            rows.add(batch[index++]);
          }
        }
        try {
          final conflict = conflictKeys[rows.first.entity];
          if (conflict == null) {
            throw StateError('Unknown sync entity: ${rows.first.entity}');
          }
          stableDeviceId ??= await _backend.deviceId();
          if (!_backend.isReady || _backend.userId != owner) return;
          await _sendGroup(rows, stableDeviceId, owner, conflict);
        } catch (e) {
          await _failRows(rows, e);
        }
      }
      batch = await _db.syncDao.pending(now: _clock());
    }
  }

  /// Keep FIFO boundaries, column defaults and duplicate-key mutations intact.
  /// PostgreSQL cannot update the same conflict key twice in one INSERT.
  static bool _canBatch(List<SyncQueueData> rows, SyncQueueData next) {
    if (next.op != 'upsert' || next.entity != rows.first.entity) return false;
    final conflict = conflictKeys[next.entity];
    if (conflict == null) return false;
    try {
      final payload = jsonDecode(next.payload) as Map<String, dynamic>;
      final columns = payload.keys.toList()..sort();
      final keys = conflict.split(',').where((key) => key != 'user_id');
      if (keys.any((key) => payload[key] == null)) return false;
      final identity = jsonEncode([for (final key in keys) payload[key]]);
      for (final row in rows) {
        final previous = jsonDecode(row.payload) as Map<String, dynamic>;
        final previousColumns = previous.keys.toList()..sort();
        if (jsonEncode(columns) != jsonEncode(previousColumns) ||
            identity == jsonEncode([for (final key in keys) previous[key]])) {
          return false;
        }
      }
      return true;
    } on Object {
      return false; // A malformed row is sent alone and gets its own failure.
    }
  }

  Future<void> _sendGroup(
    List<SyncQueueData> rows,
    String device,
    String owner,
    String conflict,
  ) async {
    if (!_backend.isReady || _backend.userId != owner) return;
    try {
      final backend = _backend;
      if (backend is BatchSyncBackend && rows.first.op == 'upsert') {
        await (backend as BatchSyncBackend).sendBatch(
          [
            for (final row in rows)
              SyncMutation(row, _mutationDeviceId(device, row.id)),
          ],
          onConflict: conflict,
          ownerId: owner,
        );
      } else {
        await backend.send(
          rows.single,
          onConflict: conflict,
          mutationDeviceId: _mutationDeviceId(device, rows.single.id),
        );
      }
    } catch (error) {
      // Split only definitive data/constraint rejections (SQLSTATE classes
      // 22/23), never a timeout, auth error or outage. Those keep the entire
      // batch queued and spend one attempt per row, not one per probe.
      final code = error is PostgrestException ? error.code ?? '' : '';
      if (rows.length > 1 && (code.startsWith('22') || code.startsWith('23'))) {
        final middle = rows.length ~/ 2;
        await _sendGroup(rows.sublist(0, middle), device, owner, conflict);
        await _sendGroup(rows.sublist(middle), device, owner, conflict);
      } else {
        await _failRows(rows, error);
      }
      return;
    }
    await _db.syncDao.ack([for (final row in rows) row.id]);
  }

  Future<void> _failRows(List<SyncQueueData> rows, Object error) async {
    for (final row in rows) {
      await _db.syncDao.markFailed(row.id, error: error, now: _clock());
      _log.warning('Push failed for ${row.entity}/${row.entityKey}', error);
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
    for (final entity in _pullEntities) {
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
    for (final entity in _pullEntities) {
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
    var portablePreferencesChanged = false;
    for (final entity in _pullEntities) {
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
            if (!_isMutationFromDevice(row['device_id'], deviceId)) {
              await _applyRemote(entity, row);
              if (entity == 'learner_profiles' ||
                  entity == 'reminder_preferences') {
                portablePreferencesChanged = true;
              }
            }
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
    if (portablePreferencesChanged) {
      await onPortablePreferencesChanged?.call();
    }
  }

  /// Builds a deterministic LWW tiebreaker for one outbox mutation.
  ///
  /// Drift persists DateTimes at second precision. Two edits to the same
  /// logical row can therefore have identical `updated_at` values. Reusing
  /// the install's stable device id would make PostgreSQL reject the second
  /// edit as an equal `(updated_at, device_id)` write. The monotonically
  /// increasing, fixed-width outbox id makes later same-device writes sort
  /// after earlier ones while staying within the backend's 128-char limit.
  static String _mutationDeviceId(String stableDeviceId, int outboxId) {
    final sequence = outboxId.toString().padLeft(_mutationSequenceWidth, '0');
    final maxStableLength =
        _mutationDeviceIdMaxLength -
        _mutationSeparator.length -
        sequence.length;
    final stablePart =
        stableDeviceId.length <= maxStableLength
            ? stableDeviceId
            : stableDeviceId.substring(0, maxStableLength);
    return '$stablePart$_mutationSeparator$sequence';
  }

  static bool _isMutationFromDevice(Object? value, String stableDeviceId) {
    if (value is! String) return false;
    if (value == stableDeviceId) return true; // Legacy rows.
    final zeroToken = _mutationDeviceId(stableDeviceId, 0);
    final tokenPrefix = zeroToken.substring(
      0,
      zeroToken.length - _mutationSequenceWidth,
    );
    return value.startsWith(tokenPrefix) &&
        value.length == tokenPrefix.length + _mutationSequenceWidth;
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

  /// Writes one pulled row into local storage.
  ///
  /// Visible for testing. This is the seam where a server column name meets a
  /// local field, so a typo here silently drops a value rather than failing —
  /// which is worth a test more than it is worth being private.
  Future<void> applyRemoteRow(String entity, Map<String, dynamic> r) =>
      _applyRemote(entity, r);

  Future<void> _applyRemote(String entity, Map<String, dynamic> r) async {
    switch (entity) {
      case 'learner_profiles':
        await _db.profileDao.mergeRemoteLearnerProfile(
          displayName: r['display_name'] as String? ?? '',
          selfAssessedCefr: r['self_assessed_cefr'] as String? ?? 'preA1',
          primaryGoal: r['primary_goal'] as String?,
          secondaryGoalsJson: _jsonText(r['secondary_goals'], const []),
          examTrack: r['exam_track'] as String?,
          targetHorizon: r['target_horizon'] as String?,
          focusSkillsJson: _jsonText(r['focus_skills'], const []),
          dailyCommitmentMinutes:
              (r['daily_commitment_minutes'] as num?)?.toInt() ?? 15,
          studyDaysPerWeek: (r['study_days_per_week'] as num?)?.toInt() ?? 7,
          preferredVoice: r['preferred_voice'] as String? ?? 'female',
          ttsSpeechRate: (r['tts_speech_rate'] as num?)?.toDouble() ?? 0.45,
          dailyGoalXp: (r['daily_goal_xp'] as num?)?.toInt() ?? 300,
          onboardingVersion: (r['onboarding_version'] as num?)?.toInt() ?? 1,
          onboardingLastStep: (r['onboarding_last_step'] as num?)?.toInt() ?? 0,
          onboardingCompletedAt: _ts(r['onboarding_completed_at']),
          updatedAt: _ts(r['updated_at']) ?? DateTime.now(),
        );
        break;
      case 'reminder_preferences':
        await _db.profileDao.mergeRemoteReminderPreference(
          wantsReminder: r['wants_reminder'] as bool? ?? false,
          preferredHour: (r['preferred_hour'] as num?)?.toInt(),
          preferredMinute: (r['preferred_minute'] as num?)?.toInt(),
          daysOfWeekJson: _jsonText(r['days_of_week'], const [
            1,
            2,
            3,
            4,
            5,
            6,
            7,
          ]),
          catchUpEnabled: r['catch_up_enabled'] as bool? ?? true,
          allowGoalSpecificText:
              r['allow_goal_specific_text'] as bool? ?? false,
          updatedAt: _ts(r['updated_at']) ?? DateTime.now(),
        );
        break;
      case 'placement_profiles':
        await _db.progressDao.mergeRemotePlacement(
          provisionalUnit: (r['provisional_unit'] as num?)?.toInt() ?? 1,
          learnerOverrideUnit: (r['learner_override_unit'] as num?)?.toInt(),
          estimatesJson: _jsonText(r['estimates'], const {}),
          sampleSize: (r['sample_size'] as num?)?.toInt() ?? 0,
          updatedAt: _ts(r['updated_at']) ?? DateTime.now(),
        );
        break;
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
      case 'learning_evidence_events':
        // Immutable once observed, so a pull is a plain restore and a repeated
        // one writes the same row rather than a second observation.
        await _db.progressDao.mergeRemoteLearningEvidence(
          evidenceId: r['evidence_id'] as String,
          lessonId: (r['lesson_id'] as num?)?.toInt() ?? 0,
          exerciseId: (r['exercise_id'] as num?)?.toInt(),
          skill: r['skill'] as String? ?? '',
          phase: r['phase'] as String? ?? '',
          correct: r['correct'] as bool? ?? false,
          novelTask: r['novel_task'] as bool? ?? false,
          supportsJson: _jsonText(r['supports'], const []),
          conceptKeysJson: _jsonText(r['concept_keys'], const []),
          responseLatencyMs: (r['response_latency_ms'] as num?)?.toInt() ?? 0,
          observedAt: _ts(r['observed_at']) ?? DateTime.now(),
        );
        break;
      case 'delayed_transfer_assignments':
        await _db.progressDao.mergeRemoteTransferAssignment(
          assignmentId: r['assignment_id'] as String,
          sourceAttemptId: r['source_attempt_id'] as String? ?? '',
          lessonId: (r['lesson_id'] as num?)?.toInt() ?? 0,
          sourceExerciseId: (r['source_exercise_id'] as num?)?.toInt() ?? 0,
          dueAt: _ts(r['due_at']) ?? DateTime.now(),
          status: r['status'] as String? ?? 'pending',
          completedEvidenceId: r['completed_evidence_id'] as String?,
          createdAt: _ts(r['created_at']) ?? DateTime.now(),
          completedAt: _ts(r['completed_at']),
        );
        break;
    }
  }

  String _decodeGamificationBadges(Object? value) {
    if (value is String) return value;
    if (value is List) return jsonEncode(value);
    return '[]';
  }

  String _jsonText(Object? value, Object fallback) {
    if (value is String) {
      try {
        jsonDecode(value);
        return value;
      } catch (_) {
        return jsonEncode(fallback);
      }
    }
    return jsonEncode(value ?? fallback);
  }

  /// user_progress.value is jsonb. Locally it's an app-defined string; unwrap a
  /// bare JSON string, otherwise re-encode structured JSON back to a string.
  String _decodeKvValue(Object? value) {
    if (value is String) return value;
    return jsonEncode(value);
  }
}
