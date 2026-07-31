import 'package:drift/drift.dart';

/// Lesson progress table — tracks completed lessons and scores.
class LessonProgress extends Table {
  IntColumn get lessonId => integer()();
  IntColumn get unitId => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  RealColumn get bestScore => real().withDefault(const Constant(0.0))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttempted => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {lessonId};
}
