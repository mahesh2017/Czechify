import 'package:drift/drift.dart';

/// Verified signed documents only; never synchronized through client upserts.
class MonetizationSnapshots extends Table {
  TextColumn get accountId => text()();
  TextColumn get signedPayload => text()();
  IntColumn get revision => integer()();
  DateTimeColumn get serverAnchor => dateTime()();
  DateTimeColumn get localAnchor => dateTime()();
  DateTimeColumn get maximumObservedTime => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId};
}
