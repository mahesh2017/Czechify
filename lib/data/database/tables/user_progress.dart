import 'package:drift/drift.dart';

/// User progress table — key-value store for progress tracking.
class UserProgress extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  @override
  Set<Column> get primaryKey => {key};
}
