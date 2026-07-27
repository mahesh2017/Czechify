import 'package:drift/drift.dart';

/// Exam results table — mock exam attempt results.
class ExamResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get level => text()(); // 'a1' or 'a2'
  /// Official exam product: 'permanent_residence' (default) or 'cce'.
  TextColumn get product =>
      text().withDefault(const Constant('permanent_residence'))();
  DateTimeColumn get takenAt =>
      dateTime().withDefault(Constant(DateTime.now()))();
  IntColumn get readingScore => integer().withDefault(const Constant(0))();
  IntColumn get listeningScore => integer().withDefault(const Constant(0))();
  IntColumn get writingScore => integer().withDefault(const Constant(0))();
  IntColumn get speakingScore => integer().withDefault(const Constant(0))();
  IntColumn get totalScore => integer().withDefault(const Constant(0))();
  BoolColumn get passed => boolean().withDefault(const Constant(false))();
  TextColumn get details => text().nullable()(); // JSON
}
