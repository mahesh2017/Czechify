import 'dart:async';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../../domain/entities/course_catalog.dart';
import '../../domain/entities/curriculum_entitlement.dart';
import '../../domain/engines/course_access_policy.dart';
import 'snapshot_verifier.dart';

/// A fetch that could not reach the entitlement service, so the verified
/// cache applies. Account-fence failures stay [StateError]s: those must never
/// fall back to a cached document.
class EntitlementFetchUnavailable implements Exception {
  final String message;
  const EntitlementFetchUnavailable(this.message);

  @override
  String toString() => 'EntitlementFetchUnavailable: $message';
}

class MonetizationLoad {
  final VerifiedMonetizationDocument? document;
  final bool offline;
  final bool accountTransition;
  final bool requiresReverification;
  final DateTime now;
  CourseAccess courseAccess(String? accountId) =>
      const CourseAccessPolicy().evaluate(
        catalog: CourseCatalog.a1ReferralV1,
        accountId: accountId,
        now: now,
        offline: offline,
        clockTrusted: !requiresReverification,
        snapshot: document?.snapshot,
        staff: document?.staff ?? const CurriculumEntitlement(unlockAll: false),
      );

  const MonetizationLoad(
    this.document, {
    required this.offline,
    this.accountTransition = false,
    required this.requiresReverification,
    required this.now,
  });
}

/// One instance per account lifecycle. Generation checks fence old async work;
/// persisted rows are additionally keyed by account and cleared on transition.
class MonetizationRepository {
  final AppDatabase database;
  final SnapshotVerifier verifier;
  final Future<String> Function(String accountId) fetch;
  final DateTime Function() wallNow;
  final Stopwatch _elapsed = Stopwatch()..start();
  String? _account;
  int _epoch = 0;
  bool _disposed = false;
  bool _suspended = false;
  bool _clockSuspect = false;
  DateTime? _serverAnchor;
  Duration _elapsedAnchor = Duration.zero;
  Future<MonetizationLoad>? _inFlight;

  MonetizationRepository({
    required this.database,
    required this.verifier,
    required this.fetch,
    DateTime Function()? wallNow,
  }) : wallNow = wallNow ?? DateTime.now;

  void setAccount(String? accountId) {
    if (_disposed || _suspended || _account == accountId) return;
    _account = accountId;
    _epoch++;
    _serverAnchor = null;
    _clockSuspect = false;
    _inFlight = null;
  }

  void suspend() {
    setAccount(null);
    _suspended = true;
    _epoch++;
    _inFlight = null;
  }

  void resume(String? accountId) {
    _suspended = false;
    setAccount(accountId);
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _elapsed.stop();
  }

  Future<MonetizationLoad> load() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final epoch = _epoch;
    final task = _load(epoch);
    _inFlight = task;
    // Ignore completion from a previous generation; it cannot clear new work.
    unawaited(
      task.then(
        (_) {
          if (_epoch == epoch) _inFlight = null;
        },
        onError: (Object _, StackTrace __) {
          if (_epoch == epoch) _inFlight = null;
        },
      ),
    );
    return task;
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;

  Future<MonetizationLoad> _load(int epoch) async {
    final account = _account;
    if (account == null || account.isEmpty || !_current(epoch)) {
      return MonetizationLoad(
        null,
        offline: true,
        requiresReverification: false,
        accountTransition: _suspended || _disposed,
        now: wallNow().toUtc(),
      );
    }
    final cached = await (database.select(
      database.monetizationSnapshots,
    )..where((t) => t.accountId.equals(account))).getSingleOrNull();
    VerifiedMonetizationDocument? previous;
    if (cached != null) {
      try {
        previous = await verifier.verify(
          cached.signedPayload,
          accountId: account,
        );
      } on FormatException {
        /* Untrusted/corrupt cache cannot authorize access. */
      }
    }
    if (!_current(epoch)) {
      throw StateError('Account changed during entitlement load.');
    }
    try {
      final raw = await fetch(account).timeout(const Duration(seconds: 8));
      final fresh = await verifier.verify(raw, accountId: account);
      if (!_current(epoch)) {
        throw StateError('Account changed during entitlement load.');
      }
      if (!fresh.snapshot.canReplace(previous?.snapshot, accountId: account) ||
          (previous != null && !fresh.issuedAt.isAfter(previous.issuedAt))) {
        // Replaying an identical signed document must not reset the clock
        // anchor and keep a paid offline lease alive indefinitely.
        throw const FormatException('Stale entitlement revision or time.');
      }
      final now = fresh.issuedAt;
      // A strictly newer authenticated server document can repair a device
      // clock that was moved forwards. Replayed documents never reach here.
      final maximum = now;
      await database.transaction(() async {
        if (!_current(epoch)) {
          throw StateError('Account changed before cache commit.');
        }
        await database
            .into(database.monetizationSnapshots)
            .insertOnConflictUpdate(
              MonetizationSnapshotsCompanion.insert(
                accountId: account,
                signedPayload: raw,
                revision: fresh.snapshot.revision,
                serverAnchor: now,
                localAnchor: wallNow().toUtc(),
                maximumObservedTime: maximum,
              ),
            );
        if (!_current(epoch)) {
          throw StateError('Account changed before transaction commit.');
        }
      });
      if (!_current(epoch)) {
        throw StateError('Account changed during cache commit.');
      }
      _serverAnchor = maximum;
      _clockSuspect = false;
      _elapsedAnchor = _elapsed.elapsed;
      return MonetizationLoad(
        fresh,
        offline: false,
        requiresReverification: false,
        now: maximum,
      );
    } on Exception {
      if (!_current(epoch)) {
        throw StateError('Account changed during entitlement load.');
      }
      final local = wallNow().toUtc();
      if (cached == null || previous == null) {
        return MonetizationLoad(
          null,
          offline: true,
          requiresReverification: true,
          now: local,
        );
      }
      final estimated =
          _serverAnchor?.add(_elapsed.elapsed - _elapsedAnchor) ??
          cached.serverAnchor.add(local.difference(cached.localAnchor));
      final backwards = estimated.isBefore(
        cached.maximumObservedTime.subtract(const Duration(minutes: 5)),
      );
      final maximum = estimated.isBefore(cached.maximumObservedTime)
          ? cached.maximumObservedTime
          : estimated;
      await database.transaction(() async {
        if (!_current(epoch)) {
          throw StateError('Account changed before clock checkpoint.');
        }
        await (database.update(
          database.monetizationSnapshots,
        )..where((t) => t.accountId.equals(account))).write(
          MonetizationSnapshotsCompanion(maximumObservedTime: Value(maximum)),
        );
      });
      if (!_current(epoch)) {
        throw StateError('Account changed during clock checkpoint.');
      }
      _serverAnchor = maximum;
      _elapsedAnchor = _elapsed.elapsed;
      return MonetizationLoad(
        previous,
        offline: true,
        requiresReverification: _clockSuspect = (_clockSuspect || backwards),
        now: maximum,
      );
    }
  }
}
