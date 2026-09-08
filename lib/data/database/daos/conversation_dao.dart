import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/repositories/conversation_repository.dart';
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

  /// Conversations by most recent activity, newest first, paged in SQL.
  ///
  /// Two things this fixes. The list was ordered by creation, so resuming a
  /// months-old chat and talking in it left it at the bottom — the ordering
  /// answered "when did this start" when the learner is asking "what was I
  /// last doing". And the repository used to read *every* conversation and
  /// throw away all but the first 25 in Dart, so the cost of the query grew
  /// with the archive while the answer stayed the same size.
  ///
  /// Activity is the newest message, falling back to the conversation's own
  /// creation time for one with no messages yet. The id breaks ties, because
  /// date-times are stored as whole seconds.
  Future<List<ConversationSummary>> recentConversations({
    int limit = 25,
    int offset = 0,
  }) async {
    final rows =
        await customSelect(
          'SELECT c.id, c.scenario, c.cefr_level, c.created_at, '
          '  COALESCE(MAX(m.created_at), c.created_at) AS last_activity '
          'FROM conversations c '
          'LEFT JOIN chat_messages m ON m.conversation_id = c.id '
          'GROUP BY c.id '
          'ORDER BY last_activity DESC, c.id DESC '
          'LIMIT ? OFFSET ?',
          variables: [Variable<int>(limit), Variable<int>(offset)],
          readsFrom: {conversations, chatMessages},
        ).get();

    return [
      for (final row in rows)
        ConversationSummary(
          id: row.read<String>('id'),
          scenario: row.read<String>('scenario'),
          cefrLevel: row.read<String>('cefr_level'),
          createdAt: row.read<DateTime>('created_at'),
          lastActivityAt: row.read<DateTime>('last_activity'),
        ),
    ];
  }

  /// How many conversations exist, for a caller paging through them.
  Future<int> conversationCount() async {
    final row =
        await customSelect(
          'SELECT COUNT(*) AS c FROM conversations',
          readsFrom: {conversations},
        ).getSingle();
    return row.read<int>('c');
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
