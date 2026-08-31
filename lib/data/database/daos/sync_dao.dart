import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/sync_queue.dart';

part 'sync_dao.g.dart';

/// Keyset cursor over a table's server-owned monotonic `revision` column.
///
/// `revision` is stamped by a Postgres trigger on every insert AND update, so
/// it is immune to client clock skew. Pull orders by `revision` alone.
class PullCursor {
  const PullCursor({required this.revision});

  final int revision;
}

/// Data access for the sync outbox. Repositories call [enqueue] alongside
/// every local mutation; the sync service drains via [pending] and [ack].
@DriftAccessor(tables: [SyncQueue, SyncState])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  // ── Pull cursors (local-only) ──

  /// Revision keyset cursor. Legacy timestamp/sync_id cursors from before the
  /// server-owned-revision migration are not comparable to `revision`, so they
  /// are treated as absent — the next pull restarts from the beginning. This is
  /// safe because remote merges are domain-monotonic and idempotent, so a full
  /// re-pull cannot regress or duplicate local state.
  Future<PullCursor?> pullCursor(String entity) async {
    final row =
        await (select(syncState)
          ..where((s) => s.key.equals('pull:$entity'))).getSingleOrNull();
    if (row == null) return null;
    try {
      final value = jsonDecode(row.value) as Map<String, dynamic>;
      final revision = (value['revision'] as num?)?.toInt();
      return revision == null ? null : PullCursor(revision: revision);
    } catch (_) {
      return null;
    }
  }

  Future<void> setPullCursor(String entity, PullCursor value) {
    return into(syncState).insertOnConflictUpdate(
      SyncStateCompanion.insert(
        key: 'pull:$entity',
        value: jsonEncode({'revision': value.revision}),
      ),
    );
  }

  /// Append a mutation to the outbox. [deviceId] is left blank here; the sync
  /// service derives the backend LWW token from this row's generated id and
  /// the install's stable device id at push time.
  Future<void> enqueue({
    required String entity,
    required String entityKey,
    required Map<String, dynamic> payload,
    String op = 'upsert',
  }) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        entity: entity,
        entityKey: entityKey,
        op: Value(op),
        payload: jsonEncode(payload),
        deviceId: '',
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Oldest [limit] unsynced mutations, FIFO.
  Future<List<SyncQueueData>> pending({int limit = 100, DateTime? now}) {
    final eligibleAt = now ?? DateTime.now();
    return (select(syncQueue)
          ..where(
            (t) =>
                t.deadLetteredAt.isNull() &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(eligibleAt)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(limit))
        .get();
  }

  /// Remove rows the backend has acknowledged.
  Future<void> ack(List<int> ids) {
    return (delete(syncQueue)..where((t) => t.id.isIn(ids))).go();
  }

  /// Record a failure and either schedule exponential backoff or dead-letter
  /// the row once [maxAttempts] is reached.
  Future<void> markFailed(
    int id, {
    required Object error,
    required DateTime now,
    int maxAttempts = 5,
  }) async {
    final row =
        await (select(syncQueue)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final attempts = row.attempts + 1;
    final dead = attempts >= maxAttempts;
    final exponent = attempts > 6 ? 6 : attempts;
    final delay = Duration(seconds: 1 << exponent);
    final message = error.toString();
    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        attempts: Value(attempts),
        nextAttemptAt: Value(dead ? null : now.add(delay)),
        deadLetteredAt: Value(dead ? now : null),
        lastError: Value(
          message.length <= 500 ? message : message.substring(0, 500),
        ),
      ),
    );
  }

  Future<int> pendingCount() async {
    final row =
        await customSelect(
          'SELECT COUNT(*) AS c FROM sync_queue',
          readsFrom: {syncQueue},
        ).getSingle();
    return row.read<int>('c');
  }

  /// Returns dead-lettered rows to the queue for one more run of attempts.
  ///
  /// Rows dead-letter after [markFailed]'s attempt limit and were then simply
  /// stranded: nothing retried them, nothing reported them, and the learner's
  /// change was silently never going to reach the backend. Most of these are
  /// failures that have since resolved — an expired session, a dead network —
  /// so a deliberate retry is usually all they need.
  ///
  /// Attempts reset to zero, so a row that fails again gets the full backoff
  /// ladder rather than dead-lettering on its first stumble. Returns the
  /// number of rows revived.
  Future<int> retryDeadLettered() {
    return (update(syncQueue)
      ..where((t) => t.deadLetteredAt.isNotNull())).write(
      const SyncQueueCompanion(
        attempts: Value(0),
        nextAttemptAt: Value(null),
        deadLetteredAt: Value(null),
      ),
    );
  }

  Future<int> deadLetterCount() async {
    final count = syncQueue.id.count();
    final row =
        await (selectOnly(syncQueue)
              ..addColumns([count])
              ..where(syncQueue.deadLetteredAt.isNotNull()))
            .getSingle();
    return row.read(count) ?? 0;
  }
}
