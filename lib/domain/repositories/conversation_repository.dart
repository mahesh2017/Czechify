import '../entities/chat_message.dart';

/// Metadata for listing/resuming a past conversation.
class ConversationSummary {
  final String id;
  final String scenario;
  final String cefrLevel;
  final DateTime createdAt;

  /// The newest message, or [createdAt] for a conversation with none yet.
  ///
  /// The list is ordered by this rather than by creation: a learner scanning
  /// their conversations is asking what they were last doing, not what they
  /// started first.
  final DateTime lastActivityAt;

  const ConversationSummary({
    required this.id,
    required this.scenario,
    required this.cefrLevel,
    required this.createdAt,
    required this.lastActivityAt,
  });
}

/// Abstract interface for conversation persistence.
abstract class ConversationRepository {
  Future<String> createConversation(String scenario, String cefrLevel);
  Future<void> saveMessage(ChatMessage message);
  Future<List<ChatMessage>> getHistory(String conversationId);
  Future<void> clearConversation(String conversationId);
  Future<List<String>> getConversationIds();

  /// Conversations by most recent activity, newest first.
  ///
  /// [offset] pages through the archive, so a learner with hundreds is not
  /// limited to whatever the first page happens to hold.
  Future<List<ConversationSummary>> getRecentConversations({
    int limit = 5,
    int offset = 0,
  });

  /// Total conversations, so a caller can tell whether more pages exist.
  Future<int> countConversations();
}
