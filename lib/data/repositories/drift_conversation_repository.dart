import 'dart:convert';
import 'package:drift/drift.dart' hide Query;
import '../../domain/entities/chat_message.dart' as entity;
import '../../domain/repositories/conversation_repository.dart';
import '../database/database.dart' as db;

/// Concrete implementation of [ConversationRepository] using Drift.
class DriftConversationRepository implements ConversationRepository {
  final db.AppDatabase _db;

  DriftConversationRepository(this._db);

  @override
  Future<String> createConversation(String scenario, String cefrLevel) {
    return _db.conversationDao.createConversation(scenario, cefrLevel);
  }

  @override
  Future<void> saveMessage(entity.ChatMessage message) async {
    final correctionsJson =
        message.corrections != null
            ? jsonEncode(
              message.corrections!
                  .map(
                    (c) => {
                      'type': c.type.name,
                      'user_said': c.userSaid,
                      'correct': c.correct,
                      'rule': c.rule,
                      'severity': c.severity.name,
                    },
                  )
                  .toList(),
            )
            : null;

    final vocabJson =
        message.newVocabulary != null
            ? jsonEncode(
              message.newVocabulary!
                  .map((v) => {'cz': v.cz, 'en': v.en, 'ipa': v.ipa})
                  .toList(),
            )
            : null;

    await _db.conversationDao.insertMessage(
      db.ChatMessagesCompanion.insert(
        conversationId: message.conversationId,
        role: message.role.name,
        content: message.content,
        translation: Value(message.translation),
        corrections: Value(correctionsJson),
        newVocabulary: Value(vocabJson),
        audioPath: Value(message.audioPath),
      ),
    );
  }

  @override
  Future<List<entity.ChatMessage>> getHistory(String conversationId) async {
    final rows = await _db.conversationDao.getMessagesByConversation(
      conversationId,
    );
    return rows.map(_toEntityChatMessage).toList();
  }

  @override
  Future<void> clearConversation(String conversationId) {
    return _db.conversationDao.deleteConversation(conversationId);
  }

  @override
  Future<List<String>> getConversationIds() async {
    final rows = await _db.conversationDao.getAllConversations();
    return rows.map((c) => c.id).toList();
  }

  @override
  Future<List<ConversationSummary>> getRecentConversations({
    int limit = 5,
  }) async {
    final rows = await _db.conversationDao.getAllConversations();
    return rows
        .take(limit)
        .map(
          (c) => ConversationSummary(
            id: c.id,
            scenario: c.scenario,
            cefrLevel: c.cefrLevel,
            createdAt: c.createdAt,
          ),
        )
        .toList();
  }

  entity.ChatMessage _toEntityChatMessage(db.ChatMessage row) {
    return entity.ChatMessage(
      id: row.id.toString(),
      conversationId: row.conversationId,
      role:
          row.role == 'user'
              ? entity.MessageRole.user
              : entity.MessageRole.tutor,
      content: row.content,
      translation: row.translation,
      corrections:
          row.corrections != null
              ? (jsonDecode(row.corrections!) as List<dynamic>)
                  .map(
                    (e) =>
                        entity.Correction.fromJson(e as Map<String, dynamic>),
                  )
                  .toList()
              : null,
      newVocabulary:
          row.newVocabulary != null
              ? (jsonDecode(row.newVocabulary!) as List<dynamic>)
                  .map(
                    (e) => entity.NewVocabulary.fromJson(
                      e as Map<String, dynamic>,
                    ),
                  )
                  .toList()
              : null,
      audioPath: row.audioPath,
      createdAt: row.createdAt,
    );
  }
}
