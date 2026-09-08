import 'package:czechify/data/database/database.dart' hide ChatMessage;
import 'package:czechify/data/repositories/drift_conversation_repository.dart';
import 'package:czechify/domain/entities/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `createdAt` was declared `withDefault(Constant(DateTime.now()))`. Drift
/// resolves a Dart constant while it builds `CREATE TABLE`, so the schema got
/// a literal — the moment the database was created on that device — and every
/// insert that omitted the column reused it forever. A whole chat history
/// shared one timestamp and `ORDER BY created_at` had nothing to sort on.
void main() {
  group('live timestamps', () {
    late AppDatabase db;
    late DriftConversationRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = DriftConversationRepository(db);
    });

    tearDown(() => db.close());

    // Date-times are stored as whole unix seconds, so the wait has to cross a
    // second boundary for the two writes to be distinguishable at all.
    Future<void> passASecond() =>
        Future<void>.delayed(const Duration(milliseconds: 1200));

    test('conversations created apart do not share a timestamp', () async {
      final first = await repo.createConversation('Casual Chat', 'A1');
      await passASecond();
      final second = await repo.createConversation('Shopping', 'A1');

      final rows = await db.conversationDao.getAllConversations();
      final byId = {for (final row in rows) row.id: row.createdAt};

      expect(byId[first], isNot(byId[second]));
      expect(byId[second]!.isAfter(byId[first]!), isTrue);
    });

    test('a conversation is stamped with now, not with schema creation', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 2));
      final id = await repo.createConversation('At the Doctor', 'A1');
      final after = DateTime.now().add(const Duration(seconds: 2));

      final row = (await db.conversationDao.getAllConversations()).single;
      expect(row.id, id);
      expect(row.createdAt.isAfter(before), isTrue);
      expect(row.createdAt.isBefore(after), isTrue);
    });

    test('messages written apart do not share a timestamp', () async {
      final id = await repo.createConversation('Casual Chat', 'A1');
      await repo.saveMessage(ChatMessage.user('Dobrý den', conversationId: id));
      await passASecond();
      await repo.saveMessage(ChatMessage.user('Jak se máte?', conversationId: id));

      final history = await db.conversationDao.getMessagesByConversation(id);
      expect(history.first.createdAt, isNot(history.last.createdAt));
    });

    test('messages written in the same second keep insertion order', () async {
      final id = await repo.createConversation('Casual Chat', 'A1');
      for (var i = 0; i < 6; i++) {
        await repo.saveMessage(ChatMessage.user('zpráva $i', conversationId: id));
      }

      final history = await repo.getHistory(id);
      expect(history.map((m) => m.content), [
        for (var i = 0; i < 6; i++) 'zpráva $i',
      ]);
    });
  });
}
