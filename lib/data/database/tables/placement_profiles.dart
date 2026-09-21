import 'package:drift/drift.dart';

class PlacementProfiles extends Table {
  TextColumn get key => text().withDefault(const Constant('primary'))();
  TextColumn get phaseCeilingsJson => text().nullable()();
  IntColumn get provisionalUnit => integer()();
  IntColumn get learnerOverrideUnit => integer().nullable()();
  TextColumn get estimatesJson => text()();
  IntColumn get sampleSize => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
