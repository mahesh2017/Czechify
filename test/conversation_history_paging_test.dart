import 'package:czechify/data/database/database.dart' hide ChatMessage;
import 'package:czechify/data/repositories/drift_conversation_repository.dart';
import 'package:czechify/domain/entities/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The conversation list read every row and threw all but the first 25 away in
/// Dart, ordered by creation. So the cost grew with the archive, older
/// conversations could not be reached at all, and talking in one did not move
/// it up — the ordering answered "when did this start" while the learner was
/// asking "what was I last doing".
void main() {
  late AppDatabase db;
  late DriftConversationRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftConversationRepository(db);
  });
  tearDown(() => db.close());

  /// Date-times are stored as whole seconds, so activity has to be spaced to
  /// be distinguishable at all.
  Future<void> passASecond() =>
      Future<void>.delayed(const Duration(milliseconds: 1100));

  test('a conversation talked in moves to the top', () async {
    final first = await repo.createConversation('Casual Chat', 'A1');
    await passASecond();
    final second = await repo.createConversation('Shopping', 'A1');

    // Newest first by creation, to begin with.
    expect((await repo.getRecentConversations()).map((c) => c.id), [
      second,
      first,
    ]);

    await passASecond();
    await repo.saveMessage(ChatMessage.user('Ahoj', conversationId: first));

    // Resuming the older one puts it back on top, which is the whole point of
    // a "continue" list.
    expect((await repo.getRecentConversations()).map((c) => c.id), [
      first,
      second,
    ]);
  });

  test('a conversation with no messages still appears', () async {
    final id = await repo.createConversation('Shopping', 'A1');

    final listed = (await repo.getRecentConversations()).single;
    expect(listed.id, id);
    // Falls back to its own creation time rather than dropping out of a list
    // built on message activity.
    expect(listed.lastActivityAt, listed.createdAt);
  });

  test('paging reaches past the first page', () async {
    for (var i = 0; i < 7; i++) {
      await repo.createConversation('Chat $i', 'A1');
    }

    final firstPage = await repo.getRecentConversations(limit: 3);
    final secondPage = await repo.getRecentConversations(limit: 3, offset: 3);

    expect(firstPage, hasLength(3));
    expect(secondPage, hasLength(3));
    // The pages tile rather than overlap.
    expect(
      firstPage.map((c) => c.id).toSet().intersection(
        secondPage.map((c) => c.id).toSet(),
      ),
      isEmpty,
    );
    expect(await repo.countConversations(), 7);
  });

  test('the limit is applied in SQL, not after the fact', () async {
    for (var i = 0; i < 30; i++) {
      await repo.createConversation('Chat $i', 'A1');
    }

    // Nothing here proves the query plan, but it does pin the contract the
    // repository used to break: ask for five, get five.
    expect(await repo.getRecentConversations(limit: 5), hasLength(5));
    expect(await repo.countConversations(), 30);
  });
}
