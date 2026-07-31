import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';
import 'database_providers.dart';

/// User-visible sync health state.  Surfaces enough information for the UI to
/// show whether the learner's progress is safely backed up, without exposing
/// internal entity names or error traces.
class SyncHealth {
  const SyncHealth({
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.isRunning = false,
  });

  /// When the last sync cycle completed successfully, or null if it never has.
  final DateTime? lastSyncedAt;

  /// Number of mutations queued in the local outbox, waiting to be pushed.
  final int pendingCount;

  /// Number of outbox rows that have been dead-lettered (failed permanently).
  final int failedCount;

  /// Whether a sync cycle is currently in progress.
  final bool isRunning;

  /// A short, user-facing description of the sync state.
  String get description {
    if (isRunning) return 'Syncing…';
    if (failedCount > 0) return '$failedCount item(s) failed to sync';
    if (pendingCount > 0) return '$pendingCount item(s) pending';
    if (lastSyncedAt != null) return 'Up to date';
    return 'Not yet synced';
  }

  /// True when the learner's data has unsynced changes or failed syncs.
  bool get hasIssues => failedCount > 0 || pendingCount > 0;

  SyncHealth copyWith({
    DateTime? lastSyncedAt,
    int? pendingCount,
    int? failedCount,
    bool? isRunning,
  }) {
    return SyncHealth(
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

/// Notifier that tracks sync health by polling the sync DAO.
class SyncHealthNotifier extends Notifier<SyncHealth> {
  Timer? _poll;

  @override
  SyncHealth build() {
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    ref.onDispose(() => _poll?.cancel());
    return const SyncHealth();
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Refresh the health state by querying the outbox.
  Future<void> _refresh() async {
    final pending = await _db.syncDao.pendingCount();
    final failed = await _db.syncDao.deadLetterCount();
    state = state.copyWith(pendingCount: pending, failedCount: failed);
  }

  /// Called when a sync cycle completes successfully.
  void markSynced() {
    state = state.copyWith(lastSyncedAt: DateTime.now(), isRunning: false);
    _refresh();
  }

  /// Called when a sync cycle starts.
  void markRunning() {
    state = state.copyWith(isRunning: true);
  }

  /// Called when a sync cycle fails.
  void markFailed() {
    state = state.copyWith(isRunning: false);
    _refresh();
  }
}

/// Provider for sync health.  The UI watches this to display sync status.
final syncHealthProvider = NotifierProvider<SyncHealthNotifier, SyncHealth>(
  SyncHealthNotifier.new,
);
