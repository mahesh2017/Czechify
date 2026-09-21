import 'package:drift/drift.dart';

import '../../domain/entities/referral_receipt.dart';
import '../database/database.dart';

/// Local referral state: the account's own claim, and receipts waiting for
/// upload. Every query is scoped to one account.
class ReferralStore {
  final AppDatabase _db;
  ReferralStore(this._db);

  Future<String?> activeClaim(String accountId) async {
    final row =
        await (_db.select(_db.referralClaims)..where(
          (c) =>
              c.accountId.equals(accountId) &
              c.campaignId.equals(referralCampaignId),
        )).getSingleOrNull();
    return row?.claimId;
  }

  /// Written only from the server's claim response.
  Future<void> saveClaim(String accountId, String claimId, DateTime at) => _db
      .into(_db.referralClaims)
      .insertOnConflictUpdate(
        ReferralClaimsCompanion.insert(
          accountId: accountId,
          campaignId: referralCampaignId,
          claimId: claimId,
          claimedAt: at,
        ),
      );

  Future<List<ReferralReceiptOutboxData>> due(String accountId, DateTime now) =>
      (_db.select(_db.referralReceiptOutbox)
            ..where(
              (r) =>
                  r.accountId.equals(accountId) &
                  r.status.equals('pending') &
                  r.nextAttemptAt.isSmallerOrEqualValue(now),
            )
            ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
          .get();

  Future<List<ReferralReceiptOutboxData>> all(String accountId) =>
      (_db.select(_db.referralReceiptOutbox)
            ..where((r) => r.accountId.equals(accountId))
            ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
          .get();

  /// Final outcome from the server: sent, held or rejected.
  Future<void> settle(
    String accountId,
    String attemptId,
    String status, {
    String? error,
  }) => (_db.update(_db.referralReceiptOutbox)..where(
    (r) => r.accountId.equals(accountId) & r.attemptId.equals(attemptId),
  )).write(
    ReferralReceiptOutboxCompanion(
      status: Value(status),
      lastError: Value(error),
    ),
  );

  Future<void> retryLater(
    ReferralReceiptOutboxData row,
    DateTime at,
    String error,
  ) => (_db.update(_db.referralReceiptOutbox)..where(
    (r) =>
        r.accountId.equals(row.accountId) & r.attemptId.equals(row.attemptId),
  )).write(
    ReferralReceiptOutboxCompanion(
      attempts: Value(row.attempts + 1),
      nextAttemptAt: Value(at),
      lastError: Value(error),
    ),
  );
}
