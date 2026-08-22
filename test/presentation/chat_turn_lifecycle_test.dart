import 'dart:async';
import 'dart:convert';

import 'package:ceskina_pro/domain/entities/chat_message.dart';
import 'package:ceskina_pro/domain/repositories/conversation_repository.dart';
import 'package:ceskina_pro/domain/repositories/llm_service.dart';
import 'package:ceskina_pro/presentation/providers/chat_providers.dart';
import 'package:ceskina_pro/presentation/providers/database_providers.dart';
import 'package:ceskina_pro/presentation/providers/llm_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tutor turn spans two awaits the learner can outlive: persisting their
/// message, and the LLM call itself. Both used to write back into whatever
/// state existed when they returned.
void main() {
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
    expect(
      repo.saved.where((m) => m.content == 'Odpověď pro A'),
      isEmpty,
    );
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
  }) async => const [];
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
