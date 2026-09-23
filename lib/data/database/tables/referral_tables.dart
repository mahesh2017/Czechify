import 'package:drift/drift.dart';

/// The account's own referral claim as an invitee. Server-owned: written
/// only from a successful claim response, never synchronized as progress.
class ReferralClaims extends Table {
  TextColumn get accountId => text()();
  TextColumn get campaignId => text()();
  TextColumn get claimId => text()();
  DateTimeColumn get claimedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId, campaignId};
}

/// Lesson receipts waiting for upload, written in the same transaction as
/// the lesson attempt they describe. Keyed by account so one account's
/// receipts are never uploaded under another's session.
class ReferralReceiptOutbox extends Table {
  TextColumn get accountId => text()();
  TextColumn get attemptId => text()();
  TextColumn get claimId => text()();
  IntColumn get lessonId => integer()();
  TextColumn get receiptJson => text()();
  TextColumn get receiptDigest => text()();

  /// pending: to upload; sent: the server holds it; held: the server needs a
  /// content or campaign change first; rejected: the server refused it.
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId, attemptId};
}
