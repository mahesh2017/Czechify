import 'package:czechify/domain/engines/llm_orchestrator.dart';
import 'package:czechify/domain/entities/chat_message.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/repositories/llm_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The proxy refuses a request whose messages exceed 4,000 characters each or
/// 12,000 in total (`parseMessages` in the deepseek-proxy request policy).
/// The client has to stay inside that on its own, because a refusal costs the
/// learner a turn and, for the summary, the very compression meant to stop the
/// thread outgrowing the window.
void main() {
  const serverTotalCap = 12000;
  const orchestrator = LLMOrchestrator();

  int charactersIn(LlmRequest request) =>
      request.messages.fold(0, (sum, m) => sum + m.content.length);

  List<ChatMessage> history(int count, int length) => [
    for (var i = 0; i < count; i++)
      ChatMessage.user('x' * length, conversationId: 'c1'),
  ];

  test('the per-message cap matches what the server enforces', () {
    // Mirrored rather than derived, so a change on either side is a visible
    // decision. The composer and the exam writing field both enforce it.
    expect(LLMOrchestrator.maxMessageCharacters, 4000);
  });

  test('a summary request with a long carried summary stays under the cap', () {
    // The carried summary used to be added on top of a full history window,
    // so a long one pushed the total past the server's limit and the whole
    // compression was refused.
    final request = orchestrator.buildConversationSummaryRequest(
      level: CEFRLevel.a1,
      messages: history(24, 900),
      previousSummary: 'y' * 3000,
    );

    expect(charactersIn(request), lessThanOrEqualTo(serverTotalCap));
  });

  test('the carried summary is never dropped to make room', () {
    final request = orchestrator.buildConversationSummaryRequest(
      level: CEFRLevel.a1,
      messages: history(24, 900),
      previousSummary: 'y' * 3000,
    );

    // It leads the request: successive compressions accumulate rather than
    // each one forgetting what the one before it knew.
    expect(request.messages.first.content, contains('y' * 3000));
  });

  test('a summary request with no carried summary still fits', () {
    final request = orchestrator.buildConversationSummaryRequest(
      level: CEFRLevel.a1,
      messages: history(24, 900),
    );

    expect(charactersIn(request), lessThanOrEqualTo(serverTotalCap));
  });

  test('an ordinary turn stays under the cap', () {
    final request = orchestrator.buildConversationRequest(
      level: CEFRLevel.a1,
      scenarioId: 'casual_chat',
      userMessage: 'z' * LLMOrchestrator.maxMessageCharacters,
      history: history(24, 900),
    );

    expect(charactersIn(request), lessThanOrEqualTo(serverTotalCap));
  });
}
