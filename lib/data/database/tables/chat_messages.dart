import 'package:drift/drift.dart';
import 'conversations.dart';

/// Chat messages table — individual messages in AI conversations.
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get role => text()(); // 'user' or 'tutor'
  TextColumn get content => text()();
  TextColumn get translation => text().nullable()();
  TextColumn get corrections => text().nullable()(); // JSON array
  TextColumn get newVocabulary => text().nullable()(); // JSON array
  TextColumn get audioPath => text().nullable()();

  /// See [Conversations.createdAt] on why this is a SQL default. Message order
  /// is read back from this column, so a frozen default made every message in
  /// a conversation sort equal.
  ///
  /// Drift stores date-times as whole unix seconds, so two messages written in
  /// the same second still tie — readers order by [id] as well.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
