import '../entities/chat_message.dart';

/// Metadata for listing/resuming a past conversation.
class ConversationSummary {
  final String id;
  final String scenario;
  final String cefrLevel;
  final DateTime createdAt;

  const ConversationSummary({
    required this.id,
    required this.scenario,
    required this.cefrLevel,
    required this.createdAt,
  });
}

/// Abstract interface for conversation persistence.
abstract class ConversationRepository {
  Future<String> createConversation(String scenario, String cefrLevel);
  Future<void> saveMessage(ChatMessage message);
  Future<List<ChatMessage>> getHistory(String conversationId);
  Future<void> clearConversation(String conversationId);
  Future<List<String>> getConversationIds();
  Future<List<ConversationSummary>> getRecentConversations({int limit = 5});
}
