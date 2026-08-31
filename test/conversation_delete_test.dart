import 'package:czechify/data/database/database.dart' hide ChatMessage;
import 'package:czechify/data/repositories/drift_conversation_repository.dart';
import 'package:czechify/domain/entities/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Conversations piled up with no way to remove them — starting a new one
/// always left the old behind. These pin what deleting must actually do.
void main() {
  late AppDatabase db;
  late DriftConversationRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftConversationRepository(db);
  });

  tearDown(() => db.close());

  Future<String> conversationWithMessages(String scenario, int count) async {
    final id = await repo.createConversation(scenario, 'A1');
    for (var i = 0; i < count; i++) {
      await repo.saveMessage(ChatMessage.user('zpráva $i', conversationId: id));
    }
    return id;
  }

  test('deleting removes the conversation from the list', () async {
    final keep = await conversationWithMessages('Casual Chat', 2);
    final remove = await conversationWithMessages('Shopping', 2);

    await repo.clearConversation(remove);

    final remaining = await repo.getRecentConversations();
    expect(remaining.map((c) => c.id), [keep]);
  });

  test('deleting takes its messages with it', () async {
    final id = await conversationWithMessages('At the Doctor', 3);
    expect(await repo.getHistory(id), hasLength(3));

    await repo.clearConversation(id);

    expect(
      await repo.getHistory(id),
      isEmpty,
      reason:
          'orphaned messages would keep occupying the database and could '
          'resurface if an id were ever reused',
    );
  });

  test('other conversations keep their messages', () async {
    final keep = await conversationWithMessages('Casual Chat', 4);
    final remove = await conversationWithMessages('Shopping', 2);

    await repo.clearConversation(remove);

    expect(await repo.getHistory(keep), hasLength(4));
  });

  test('deleting one of many leaves the rest intact', () async {
    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      ids.add(await conversationWithMessages('Scenario $i', 1));
    }

    await repo.clearConversation(ids[2]);

    final remaining = await repo.getRecentConversations(limit: 25);
    expect(remaining, hasLength(4));
    expect(remaining.map((c) => c.id), isNot(contains(ids[2])));
  });

  test('the list can return more than a handful', () async {
    // The screen fetched five and showed three, which is how a backlog became
    // invisible and unmanageable.
    for (var i = 0; i < 12; i++) {
      await conversationWithMessages('Scenario $i', 1);
    }
    expect(await repo.getRecentConversations(limit: 25), hasLength(12));
  });

  test('deleting an unknown id is harmless', () async {
    final id = await conversationWithMessages('Casual Chat', 1);
    await repo.clearConversation('does-not-exist');
    expect(await repo.getRecentConversations(), hasLength(1));
    expect(await repo.getHistory(id), hasLength(1));
  });
}
