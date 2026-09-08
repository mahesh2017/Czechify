import 'dart:async';
import 'dart:convert';

import 'package:czechify/domain/entities/chat_message.dart';
import 'package:czechify/domain/repositories/conversation_repository.dart';
import 'package:czechify/domain/repositories/llm_service.dart';
import 'package:czechify/presentation/providers/chat_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/llm_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tutor turn spans two awaits the learner can outlive: persisting their
/// message, and the LLM call itself. Both used to write back into whatever
/// state existed when they returned.
void main() {
  // startConversation reads settingsProvider for the learner's level, and
  // SettingsNotifier loads from SharedPreferences on build.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a message that cannot be saved leaves the composer usable', () async {
    final repo = _FakeConversationRepository()..saveThrows = true;
    final llm = _FakeLlmService();
    final container = _container(repo, llm);
    final notifier = container.read(chatProvider.notifier);
    await notifier.loadConversation('conv-a');

    await notifier.sendMessage('Ahoj');

    // isLoading stuck true is what locked the composer until app restart.
    expect(container.read(chatProvider).isLoading, isFalse);
    expect(container.read(chatProvider).error, isNotNull);
    // And no tutor turn was spent on a message that was never persisted.
    expect(llm.pending, isEmpty);
  });

  test('the transcript never shows a message the database rejected', () async {
    final repo = _FakeConversationRepository()..saveThrows = true;
    final container = _container(repo, _FakeLlmService());
    final notifier = container.read(chatProvider.notifier);
    await notifier.loadConversation('conv-a');

    await notifier.sendMessage('Ahoj');

    expect(container.read(chatProvider).messages, isEmpty);
    expect(repo.saved, isEmpty);
  });

  test('a reply arriving after the learner switches conversations is '
      'dropped, not delivered to the new one', () async {
    final repo = _FakeConversationRepository();
    repo.histories['conv-b'] = [
      ChatMessage.user('older message in B', conversationId: 'conv-b'),
    ];
    final llm = _FakeLlmService();
    final container = _container(repo, llm);
    final notifier = container.read(chatProvider.notifier);
    await notifier.loadConversation('conv-a');

    // A turn starts in conversation A and blocks on the tutor.
    final turn = notifier.sendMessage('Ahoj z A');
    await _settle();
    expect(llm.pending, hasLength(1));

    // The learner moves to B while it is still in flight.
    await notifier.loadConversation('conv-b');

    // A's reply finally arrives.
    llm.pending.single.complete(
      LlmResponse(content: _tutorJson('Odpověď pro A')),
    );
    await turn;

    final state = container.read(chatProvider);
    expect(state.conversationId, 'conv-b');
    expect(
      state.messages.map((m) => m.content),
      isNot(contains('Odpověď pro A')),
    );
    // B's own history is intact, and nothing was persisted against it.
    expect(state.messages.map((m) => m.content), ['older message in B']);
    expect(repo.saved.where((m) => m.content == 'Odpověď pro A'), isEmpty);
  });

  test('a stale turn does not clear the loading flag of the new one', () async {
    final repo = _FakeConversationRepository();
    final llm = _FakeLlmService();
    final container = _container(repo, llm);
    final notifier = container.read(chatProvider.notifier);
    await notifier.loadConversation('conv-a');

    final staleTurn = notifier.sendMessage('Ahoj z A');
    await _settle();

    await notifier.loadConversation('conv-b');
    final freshTurn = notifier.sendMessage('Ahoj z B');
    await _settle();
    expect(container.read(chatProvider).isLoading, isTrue);

    // A's turn fails after the learner has already moved on. Its error must
    // not surface in B, nor release B's in-flight turn.
    llm.pending.first.completeError(const LlmServiceExceptionStub());
    await staleTurn;

    expect(container.read(chatProvider).isLoading, isTrue);
    expect(container.read(chatProvider).error, isNull);

    llm.pending.last.complete(
      LlmResponse(content: _tutorJson('Odpověď pro B')),
    );
    await freshTurn;
    expect(container.read(chatProvider).isLoading, isFalse);
    expect(
      container.read(chatProvider).messages.map((m) => m.content),
      contains('Odpověď pro B'),
    );
  });

  test('deleting the open conversation abandons its pending reply', () async {
    final repo = _FakeConversationRepository();
    repo.histories['conv-a'] = [
      ChatMessage.user('older message', conversationId: 'conv-a'),
    ];
    final llm = _FakeLlmService();
    final container = _container(repo, llm);
    final notifier = container.read(chatProvider.notifier);
    await notifier.loadConversation('conv-a');

    final turn = notifier.sendMessage('Ahoj');
    await _settle();
    expect(llm.pending, hasLength(1));

    // The learner deletes the conversation they are sitting in.
    await notifier.deleteConversation('conv-a');
    expect(container.read(chatProvider).conversationId, isNull);

    // The reply finally arrives for a conversation whose rows are gone. It
    // used to repopulate `messages` and try to save against a deleted parent.
    llm.pending.single.complete(LlmResponse(content: _tutorJson('Odpověď')));
    await turn;

    expect(container.read(chatProvider).conversationId, isNull);
    expect(container.read(chatProvider).messages, isEmpty);
    expect(
      repo.saved.where((m) => m.content == 'Odpověď'),
      isEmpty,
      reason: 'a reply must not be saved against a deleted conversation',
    );
  });

  test('a message that cannot be saved is reported as rejected', () async {
    final repo = _FakeConversationRepository()..saveThrows = true;
    final container = _container(repo, _FakeLlmService());
    final notifier = container.read(chatProvider.notifier);
    await notifier.loadConversation('conv-a');

    // The composer clears optimistically and needs this to put the draft
    // back; it used to get no answer and the text was gone for good.
    expect(await notifier.sendMessage('Ahoj'), isFalse);
    expect(container.read(chatProvider).isLoading, isFalse);
  });

  test('an accepted message reports acceptance', () async {
    final repo = _FakeConversationRepository();
    final llm = _FakeLlmService();
    final container = _container(repo, llm);
    final notifier = container.read(chatProvider.notifier);
    await notifier.loadConversation('conv-a');

    final send = notifier.sendMessage('Ahoj');
    await _settle();
    llm.pending.single.complete(LlmResponse(content: _tutorJson('Dobrý den')));

    expect(await send, isTrue);
  });

  test('the submission lock is claimed before the first await', () async {
    final repo = _FakeConversationRepository();
    final llm = _FakeLlmService();
    final container = _container(repo, llm);
    final notifier = container.read(chatProvider.notifier);
    await notifier.loadConversation('conv-a');

    // Two sends in the same turn of the event loop. The isLoading guard is
    // the only thing stopping them overlapping, and it used to be set after
    // the message had been persisted — a window both could pass through.
    final first = notifier.sendMessage('one');
    final second = notifier.sendMessage('two');

    expect(await second, isFalse, reason: 'the second must be turned away');
    await _settle();
    expect(llm.pending, hasLength(1));
    llm.pending.single.complete(LlmResponse(content: _tutorJson('ok')));
    await first;
  });

  /// A new conversation is created before its greeting is requested, and the
  /// greeting used to write `messages: [greeting]` — assigning, not appending.
  /// Between those two points the screen was live with an unlocked composer,
  /// so anything the learner sent was on screen until the greeting arrived and
  /// replaced it. The message stayed in the database, so the transcript and
  /// the record disagreed.
  group('the opening greeting', () {
    test('locks the composer until it arrives', () async {
      final llm = _FakeLlmService();
      final container = _container(_FakeConversationRepository(), llm);
      final notifier = container.read(chatProvider.notifier);

      final start = notifier.startConversation(
        scenario: ChatScenario.all.first,
      );
      await _settle();

      // The conversation exists and is on screen, but the tutor is still
      // composing — sendMessage returns early while isLoading.
      expect(container.read(chatProvider).conversationId, isNotNull);
      expect(container.read(chatProvider).isLoading, isTrue);

      llm.pending.single.complete(LlmResponse(content: _tutorJson('Ahoj!')));
      await start;

      expect(container.read(chatProvider).isLoading, isFalse);
      expect(container.read(chatProvider).messages.map((m) => m.content), [
        'Ahoj!',
      ]);
    });

    test('does not erase a message that reached the transcript', () async {
      final repo = _FakeConversationRepository();
      final llm = _FakeLlmService();
      final container = _container(repo, llm);
      final notifier = container.read(chatProvider.notifier);

      final start = notifier.startConversation(
        scenario: ChatScenario.all.first,
      );
      await _settle();

      // Belt and braces: even if something gets a message in while the
      // greeting is pending, the greeting must not take it away again.
      container.read(chatProvider.notifier).state = container
          .read(chatProvider)
          .copyWith(
            messages: [
              ChatMessage.user('Dobrý den', conversationId: 'conv-new'),
            ],
          );

      llm.pending.single.complete(LlmResponse(content: _tutorJson('Ahoj!')));
      await start;

      expect(container.read(chatProvider).messages.map((m) => m.content), [
        'Dobrý den',
        'Ahoj!',
      ]);
    });

    test('hands the composer back when it fails', () async {
      final llm = _FakeLlmService();
      final container = _container(_FakeConversationRepository(), llm);
      final notifier = container.read(chatProvider.notifier);

      final start = notifier.startConversation(
        scenario: ChatScenario.all.first,
      );
      await _settle();
      llm.pending.single.completeError(const LlmServiceExceptionStub());
      await start;

      // A conversation whose greeting failed still has to be usable.
      expect(container.read(chatProvider).isLoading, isFalse);
      expect(container.read(chatProvider).messages, hasLength(1));
    });
  });
}

ProviderContainer _container(ConversationRepository repo, LlmService llm) {
  final container = ProviderContainer(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repo),
      llmServiceProvider.overrideWithValue(llm),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lets the pending saves and the LLM dispatch run without completing them.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

String _tutorJson(String cz) => jsonEncode({
  'tutor_reply_cz': cz,
  'tutor_reply_en': 'english',
  'suggested_replies': <String>[],
});

class LlmServiceExceptionStub implements Exception {
  const LlmServiceExceptionStub();
}

class _FakeConversationRepository implements ConversationRepository {
  bool saveThrows = false;
  final List<ChatMessage> saved = [];
  final Map<String, List<ChatMessage>> histories = {};

  @override
  Future<String> createConversation(String scenario, String cefrLevel) async =>
      'conv-new';

  @override
  Future<void> saveMessage(ChatMessage message) async {
    if (saveThrows) throw Exception('database unavailable');
    saved.add(message);
  }

  @override
  Future<List<ChatMessage>> getHistory(String conversationId) async =>
      List.of(histories[conversationId] ?? const []);

  @override
  Future<void> clearConversation(String conversationId) async {}

  @override
  Future<List<String>> getConversationIds() async => histories.keys.toList();

  @override
  Future<List<ConversationSummary>> getRecentConversations({
    int limit = 5,
    int offset = 0,
  }) async => const [];

  @override
  Future<int> countConversations() async => histories.length;
}

class _FakeLlmService implements LlmService {
  final List<Completer<LlmResponse>> pending = [];

  @override
  Future<LlmResponse> complete(LlmRequest request) {
    final completer = Completer<LlmResponse>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Stream<LlmChunk> streamComplete(LlmRequest request) =>
      const Stream<LlmChunk>.empty();

  @override
  Future<bool> isAvailable() async => true;
}
