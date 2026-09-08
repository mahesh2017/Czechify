import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database.dart';
import '../tables/conversations.dart';
import '../tables/chat_messages.dart';

part 'conversation_dao.g.dart';

/// Data access object for conversation + chat message queries.
@DriftAccessor(tables: [Conversations, ChatMessages])
class ConversationDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationDaoMixin {
  ConversationDao(super.db);

  // ── Conversations ──

  Future<String> createConversation(String scenario, String cefrLevel) async {
    final id = 'conv_${const Uuid().v4()}';
    await into(conversations).insert(
      ConversationsCompanion.insert(
        id: id,
        scenario: scenario,
        cefrLevel: cefrLevel,
      ),
    );
    return id;
  }

  /// Conversations newest-first.
  ///
  /// The id tiebreak cannot restore chronology — ids are uuids — but it does
  /// make the order stable. Rows written under the frozen `createdAt` default
  /// all tie, and without a tiebreak sqlite is free to return them in a
  /// different order on every read, reshuffling the learner's recent list.
  Future<List<Conversation>> getAllConversations() =>
      (select(conversations)..orderBy([
        (c) => OrderingTerm.desc(c.createdAt),
        (c) => OrderingTerm.desc(c.id),
      ])).get();

  Future<void> deleteConversation(String conversationId) async {
    await (delete(chatMessages)
      ..where((m) => m.conversationId.equals(conversationId))).go();
    await (delete(conversations)
      ..where((c) => c.id.equals(conversationId))).go();
  }

  // ── Chat Messages ──

  /// Messages oldest-first.
  ///
  /// [ChatMessages.id] breaks ties. Date-times are stored as whole seconds, so
  /// a fast exchange can leave two messages with the same `createdAt` and no
  /// defined order between them — and every message written before the frozen
  /// default was fixed ties with all the others in its conversation. The
  /// auto-incrementing id preserves insertion order in both cases.
  Future<List<ChatMessage>> getMessagesByConversation(String conversationId) {
    return (select(chatMessages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([
            (m) => OrderingTerm.asc(m.createdAt),
            (m) => OrderingTerm.asc(m.id),
          ]))
        .get();
  }

  Future<int> insertMessage(ChatMessagesCompanion message) =>
      into(chatMessages).insert(message);
}
