import 'package:drift/drift.dart';

/// Conversations table — AI conversation sessions.
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get scenario => text()();
  TextColumn get cefrLevel => text()();

  /// Must stay a SQL-evaluated default, never `Constant(DateTime.now())`.
  /// A Dart constant is baked into `CREATE TABLE` as a literal, so it freezes
  /// at the moment the schema is created on the device and every later insert
  /// that omits this column is stamped with that same first-launch time.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
