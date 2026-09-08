import 'package:czechify/data/database/database.dart' as db;
import 'package:czechify/data/repositories/drift_conversation_repository.dart';
import 'package:czechify/presentation/providers/chat_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The picker showed a flat 25 with nothing beyond it, so a learner past that
/// could not reach an older conversation to resume or delete it without first
/// removing newer ones.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() {
    container.dispose();
    return database.close();
  });

  Future<void> createConversations(int count) async {
    final repo = DriftConversationRepository(database);
    for (var i = 0; i < count; i++) {
      await repo.createConversation('Chat $i', 'A1');
    }
  }

  test('one page is shown to begin with', () async {
    await createConversations(kRecentConversationPageSize + 5);

    final shown = await container.read(recentConversationsProvider.future);
    expect(shown, hasLength(kRecentConversationPageSize));
  });

  test('more conversations are reported when there are more', () async {
    await createConversations(kRecentConversationPageSize + 5);

    expect(await container.read(hasMoreConversationsProvider.future), isTrue);
  });

  test('asking for more reaches the rest', () async {
    await createConversations(kRecentConversationPageSize + 5);

    container.read(conversationPagesProvider.notifier).showMore();

    final shown = await container.read(recentConversationsProvider.future);
    expect(shown, hasLength(kRecentConversationPageSize + 5));
    // Nothing left over, so the control stops offering itself.
    expect(await container.read(hasMoreConversationsProvider.future), isFalse);
  });

  test('a short archive offers nothing more', () async {
    await createConversations(3);

    expect(
      await container.read(recentConversationsProvider.future),
      hasLength(3),
    );
    expect(await container.read(hasMoreConversationsProvider.future), isFalse);
  });

  test('resetting returns to a single page', () async {
    await createConversations(kRecentConversationPageSize + 5);
    final pages = container.read(conversationPagesProvider.notifier);

    pages.showMore();
    expect(container.read(conversationPagesProvider), 2);

    // Leaving the picker forgets how far the learner scrolled, so reopening it
    // does not silently re-read everything.
    pages.reset();
    expect(container.read(conversationPagesProvider), 1);
    expect(
      await container.read(recentConversationsProvider.future),
      hasLength(kRecentConversationPageSize),
    );
  });
}
