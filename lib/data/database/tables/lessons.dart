import 'package:drift/drift.dart';
import 'units.dart';

/// Lessons table — lessons within a unit (3-6 per unit).
class Lessons extends Table {
  IntColumn get id => integer()();
  IntColumn get unitId => integer().references(Units, #id)();
  IntColumn get orderInUnit => integer()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get canDo => text().withDefault(const Constant(''))();
  TextColumn get newLanguageJson => text().withDefault(const Constant('[]'))();
  TextColumn get recyclesJson => text().withDefault(const Constant('[]'))();
  TextColumn get exitTask => text().withDefault(const Constant(''))();
  IntColumn get durationMinutes => integer().withDefault(const Constant(10))();
  TextColumn get lessonType =>
      text().withDefault(const Constant('introduction'))();
  BoolColumn get isReview => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
