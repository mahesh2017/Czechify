import 'package:drift/drift.dart';
import 'flashcards.dart';

/// Simplified SM-2 scheduling state for each flashcard or grammar pattern.
class SrsCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardType => text()(); // 'vocabulary' or 'grammar'
  IntColumn get flashcardId =>
      integer().nullable().references(Flashcards, #id)();
  TextColumn get grammarPatternKey => text().nullable()();
  RealColumn get stability => real().withDefault(const Constant(0.0))();
  RealColumn get difficulty => real().withDefault(const Constant(0.0))();
  DateTimeColumn get due => dateTime().withDefault(Constant(DateTime.now()))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  TextColumn get state => text().withDefault(const Constant('newCard'))();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
}
