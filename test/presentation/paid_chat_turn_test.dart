import 'dart:convert';

import 'package:czechify/data/repositories/llm_service_exception.dart';
import 'package:czechify/domain/entities/chat_message.dart';
import 'package:czechify/domain/repositories/conversation_repository.dart';
import 'package:czechify/domain/repositories/llm_service.dart';
import 'package:czechify/presentation/providers/chat_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/llm_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paid tutor turns carry a request ID the server charges once. A retry of
/// the same turn must resend exactly the same request under the same ID; a
/// new ID is a new charge the learner chose.
const _session = '0a1b2c3d-4e5f-4a6b-8c7d-8e9f0a1b2c3d';
const _conversation = 'conv_$_session';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChatNotifier.inProgressDelay = Duration.zero;
  });

  test(
    'a conversation ID becomes the server session only when it is a UUID',
    () {
      expect(ChatNotifier.sessionIdFor(_conversation), _session);
      expect(ChatNotifier.sessionIdFor('conv-legacy'), isNull);
      expect(ChatNotifier.sessionIdFor(null), isNull);
    },
  );

  test('a turn carries a request ID and the conversation session', () async {
    final llm = _ScriptedLlm([_reply('Ahoj!')]);
    final notifier = await _open(llm);
    await notifier.sendMessage('Ahoj');

    final request = llm.requests.single;
    expect(request.sessionId, _session);
    expect(request.requestId, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test('retrying a failed turn resends the identical request, summary and '
      'all, under the same ID', () async {
    // Long enough that the turn first summarizes what falls out of the window.
    final history = [
      for (var i = 0; i < 24; i++)
        i.isEven
            ? ChatMessage.user('u$i', conversationId: _conversation)
            : ChatMessage.tutor(
              text: 't$i',
              translation: 'e',
              conversationId: _conversation,
            ),
    ];
    final llm = _ScriptedLlm([
      _summary('first summary'),
      const LlmServiceException('No connection.'),
      // Were the turn rebuilt, it would summarize again and take this reply
      // as its summary, which the assertions below would catch.
      _reply('Ahoj!'),
    ]);
    final notifier = await _open(llm, history: history);
    await notifier.sendMessage('Ahoj');
    expect(notifier.state.error, isNotNull);

    await notifier.retryLastMessage();

    final turns =
        llm.requests
            .where((r) => r.operation == LlmOperation.conversation)
            .toList();
    expect(turns, hasLength(2));
    expect(turns[1].requestId, turns[0].requestId);
    expect(turns[1].context, turns[0].context);
    expect(
      llm.requests.where(
        (r) => r.operation == LlmOperation.conversationSummary,
      ),
      hasLength(1),
      reason: 'the retry did not summarize again',
    );
    expect(notifier.state.messages.last.content, 'Ahoj!');
  });

  test('a turn still running is asked about again under the same ID', () async {
    final llm = _ScriptedLlm([
      const LlmServiceException('busy', code: 'request_in_progress'),
      const LlmServiceException('busy', code: 'request_in_progress'),
      _reply('Ahoj!'),
    ]);
    final notifier = await _open(llm);
    await notifier.sendMessage('Ahoj');

    expect(llm.requests.map((r) => r.requestId).toSet(), hasLength(1));
    expect(notifier.state.error, isNull);
    expect(notifier.state.messages.last.content, 'Ahoj!');
  });

  test('after an unknown outcome, sending again is a new turn', () async {
    final llm = _ScriptedLlm([
      const LlmServiceException('unknown', code: 'result_unavailable'),
      _reply('Ahoj!'),
    ]);
    final notifier = await _open(llm);
    await notifier.sendMessage('Ahoj');
    expect(notifier.state.errorCode, 'result_unavailable');

    await notifier.retryLastMessage();

    expect(llm.requests, hasLength(2));
    expect(llm.requests[1].requestId, isNot(llm.requests[0].requestId));
  });

  test('a refusal keeps its code for the screen', () async {
    final llm = _ScriptedLlm([
      const LlmServiceException('limit', code: 'quota_exceeded'),
    ]);
    final notifier = await _open(llm);
    await notifier.sendMessage('Ahoj');
    expect(notifier.state.errorCode, 'quota_exceeded');
    expect(notifier.state.isLoading, isFalse);
  });

  test('without the subscription, a new conversation says why instead of '
      'faking a greeting', () async {
    final llm = _ScriptedLlm([
      const LlmServiceException('no', code: 'ai_entitlement_required'),
    ]);
    final repo = _Repo();
    final container = _container(repo, llm);
    final notifier = container.read(chatProvider.notifier);
    await notifier.startConversation(scenario: ChatScenario.all.first);

    final state = container.read(chatProvider);
    expect(state.errorCode, 'ai_entitlement_required');
    expect(state.messages, isEmpty);
    expect(repo.saved, isEmpty);
    expect(llm.requests.single.sessionId, _session);
  });
}

Future<ChatNotifier> _open(
  _ScriptedLlm llm, {
  List<ChatMessage> history = const [],
}) async {
  final repo = _Repo()..histories[_conversation] = history;
  final container = _container(repo, llm);
  final notifier = container.read(chatProvider.notifier);
  await notifier.loadConversation(_conversation);
  return notifier;
}

ProviderContainer _container(_Repo repo, _ScriptedLlm llm) {
  final container = ProviderContainer(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repo),
      llmServiceProvider.overrideWithValue(llm),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

LlmResponse _reply(String cz) => LlmResponse(
  content: jsonEncode({
    'tutor_reply_cz': cz,
    'tutor_reply_en': 'english',
    'suggested_replies': <String>[],
  }),
);

LlmResponse _summary(String text) =>
    LlmResponse(content: jsonEncode({'summary': text}));

class _ScriptedLlm implements LlmService {
  _ScriptedLlm(this.script);
  final List<Object> script;
  final requests = <LlmRequest>[];

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    requests.add(request);
    final next = script.removeAt(0);
    if (next is LlmServiceException) throw next;
    return next as LlmResponse;
  }

  @override
  Stream<LlmChunk> streamComplete(LlmRequest request) =>
      const Stream<LlmChunk>.empty();

  @override
  Future<bool> isAvailable() async => true;
}

class _Repo implements ConversationRepository {
  final List<ChatMessage> saved = [];
  final Map<String, List<ChatMessage>> histories = {};

  @override
  Future<String> createConversation(String scenario, String cefrLevel) async =>
      _conversation;

  @override
  Future<void> saveMessage(ChatMessage message) async => saved.add(message);

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
