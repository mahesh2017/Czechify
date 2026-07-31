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

  Future<List<Conversation>> getAllConversations() =>
      (select(conversations)
        ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])).get();

  Future<void> deleteConversation(String conversationId) async {
    await (delete(chatMessages)
      ..where((m) => m.conversationId.equals(conversationId))).go();
    await (delete(conversations)
      ..where((c) => c.id.equals(conversationId))).go();
  }

  // ── Chat Messages ──

  Future<List<ChatMessage>> getMessagesByConversation(String conversationId) {
    return (select(chatMessages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();
  }

  Future<int> insertMessage(ChatMessagesCompanion message) =>
      into(chatMessages).insert(message);
}
