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
  DateTimeColumn get createdAt =>
      dateTime().withDefault(Constant(DateTime.now()))();
}
