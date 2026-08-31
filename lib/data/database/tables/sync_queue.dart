import 'package:drift/drift.dart';

/// Sync outbox — every local mutation that must reach the backend is appended
/// here and drained by the sync service when the device is online.
///
/// This is an append-only log. Rows are deleted only after the backend
/// acknowledges them. Per-row last-write-wins on the server uses
/// [updatedAt] plus a mutation-specific device token derived at push time, so
/// ordering here is best-effort, not strict.
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Logical target table on the backend, e.g. `lesson_progress`, `srs_cards`,
  /// `earned_badges`, `user_progress`.
  TextColumn get entity => text()();

  /// Globally-stable identity of the affected row *within* [entity], as a
  /// string. For content-keyed rows this is the natural key (badgeId,
  /// user_progress key, lessonId, or the srs card's content key) — never a
  /// local autoincrement id, which collides across devices.
  TextColumn get entityKey => text()();

  /// `upsert` or `delete`.
  TextColumn get op => text().withDefault(const Constant('upsert'))();

  /// Full row snapshot as JSON — what to send to the backend.
  TextColumn get payload => text()();

  /// Reserved origin-device field. New rows leave this blank because the sync
  /// service derives the final LWW token after this row receives its id.
  TextColumn get deviceId => text()();

  /// Client mutation time — the LWW clock. Server compares this against the
  /// stored row and keeps the newer one.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  /// Set when a push attempt fails, for backoff/inspection.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Earliest time this row may be retried after a transient failure.
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  /// Rows exceeding the retry budget remain inspectable but are no longer
  /// selected for automatic delivery.
  DateTimeColumn get deadLetteredAt => dateTime().nullable()();

  /// Sanitized diagnostic text for support and future recovery UI.
  TextColumn get lastError => text().nullable()();
}

/// Local-only sync bookkeeping (e.g. per-entity pull cursors). Never synced to
/// the backend — this is device-private state about the sync process itself.
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
