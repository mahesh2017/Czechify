import 'package:drift/drift.dart';

/// Conversations table — AI conversation sessions.
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get scenario => text()();
  TextColumn get cefrLevel => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  @override
  Set<Column> get primaryKey => {id};
}
