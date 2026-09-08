import 'package:drift/drift.dart';

/// Exam results table — mock exam attempt results.
class ExamResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get level => text()(); // 'a1' or 'a2'
  /// Official exam product: 'permanent_residence' (default) or 'cce'.
  TextColumn get product =>
      text().withDefault(const Constant('permanent_residence'))();
  DateTimeColumn get takenAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get readingScore => integer().withDefault(const Constant(0))();
  IntColumn get listeningScore => integer().withDefault(const Constant(0))();

  /// Nullable: null means the section was never assessed.
  ///
  /// These defaulted to 0, so an evaluator that was offline or failed left a
  /// stored zero indistinguishable from a genuinely bad answer. Rows written
  /// before schema v5 keep whatever zero they were given — there is nothing
  /// left to tell the two apart.
  IntColumn get writingScore => integer().nullable()();
  IntColumn get speakingScore => integer().nullable()();
  IntColumn get totalScore => integer().nullable()();
  BoolColumn get passed => boolean().withDefault(const Constant(false))();
  TextColumn get details => text().nullable()(); // JSON
}
