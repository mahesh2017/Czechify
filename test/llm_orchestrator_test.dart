import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceskina_pro/domain/engines/llm_orchestrator.dart';
import 'package:ceskina_pro/domain/entities/chat_message.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/repositories/llm_service.dart';

void main() {
  const orchestrator = LLMOrchestrator();

  group('buildConversationRequest', () {
    test('uses a valid DeepSeek model ID', () {
      final request = orchestrator.buildConversationRequest(
        level: CEFRLevel.a1,
        scenarioId: 'casual_chat',
        userMessage: 'Ahoj',
        history: [],
      );
      // 'deepseek-v3' is NOT a valid API model ID — regression guard.
      expect(request.model, 'deepseek-chat');
    });

    test('appends the user message exactly once', () {
      final history = [
        ChatMessage.tutor(text: 'Ahoj!', conversationId: 'c1'),
        ChatMessage.user('Dobrý den', conversationId: 'c1'),
        ChatMessage.tutor(text: 'Jak se máš?', conversationId: 'c1'),
      ];

      final request = orchestrator.buildConversationRequest(
        level: CEFRLevel.a1,
        scenarioId: 'casual_chat',
        userMessage: 'Mám se dobře',
        history: history,
      );

      // 3 history messages + 1 new user message; prompts are server-owned.
      expect(request.messages.length, 4);
      final occurrences =
          request.messages.where((m) => m.content == 'Mám se dobře').length;
      expect(occurrences, 1);
      expect(request.messages.last.role, LlmRole.user);
      expect(
        request.messages.any((message) => message.role == LlmRole.system),
        isFalse,
      );
      expect(request.operation, LlmOperation.conversation);
      expect(request.context['scenario_id'], 'casual_chat');
    });

    test('a long conversation stays within the server message cap', () {
      // The server refuses more than 24 messages. Two are added per exchange,
      // so an unwindowed history broke the thread permanently after ~12 turns.
      final history = [
        for (var turn = 0; turn < 40; turn++) ...[
          ChatMessage.user('otázka $turn', conversationId: 'c1'),
          ChatMessage.tutor(text: 'odpověď $turn', conversationId: 'c1'),
        ],
      ];

      final request = orchestrator.buildConversationRequest(
        level: CEFRLevel.a1,
        scenarioId: 'casual_chat',
        userMessage: 'a ještě jedna',
        history: history,
      );

      expect(request.messages.length, lessThanOrEqualTo(24));
      // The newest turns are what the tutor is answering, so those are kept.
      expect(request.messages.last.content, 'a ještě jedna');
      expect(
        request.messages.any((m) => m.content == 'odpověď 39'),
        isTrue,
        reason: 'the most recent history must survive windowing',
      );
      expect(
        request.messages.any((m) => m.content == 'otázka 0'),
        isFalse,
        reason: 'the oldest history is what gets dropped',
      );
    });

    test('a verbose conversation stays within the server character cap', () {
      // Few messages, each near the per-message ceiling: the count window
      // alone would let this through and the server would still refuse it.
      final history = [
        for (var turn = 0; turn < 10; turn++)
          ChatMessage.tutor(text: 'x' * 3000, conversationId: 'c1'),
      ];

      final request = orchestrator.buildConversationRequest(
        level: CEFRLevel.a1,
        scenarioId: 'casual_chat',
        userMessage: 'krátká otázka',
        history: history,
      );

      final total = request.messages.fold<int>(
        0,
        (sum, m) => sum + m.content.length,
      );
      expect(total, lessThanOrEqualTo(12000));
      expect(request.messages.last.content, 'krátká otázka');
    });

    test('the user message survives a history that exhausts the budget', () {
      final history = [
        for (var turn = 0; turn < 30; turn++)
          ChatMessage.tutor(text: 'y' * 3900, conversationId: 'c1'),
      ];

      final request = orchestrator.buildConversationRequest(
        level: CEFRLevel.a1,
        scenarioId: 'casual_chat',
        userMessage: 'nezmizím',
        history: history,
      );

      expect(request.messages.last.content, 'nezmizím');
      expect(request.messages.last.role, LlmRole.user);
    });

    test('maps history roles correctly', () {
      final history = [
        ChatMessage.user('u1', conversationId: 'c1'),
        ChatMessage.tutor(text: 't1', conversationId: 'c1'),
      ];
      final request = orchestrator.buildConversationRequest(
        level: CEFRLevel.a2,
        scenarioId: 'restaurant',
        userMessage: 'u2',
        history: history,
      );
      expect(request.messages[0].role, LlmRole.user);
      expect(request.messages[1].role, LlmRole.assistant);
    });

    test('writing content is user data, never a system prompt', () {
      final request = orchestrator.buildWritingEvaluationRequest(
        level: CEFRLevel.a2,
        taskDescription: 'Write an email to a landlord.',
        learnerText: 'Dobrý den, hledám byt.',
      );

      expect(request.operation, LlmOperation.writingEvaluation);
      expect(request.messages, hasLength(1));
      expect(request.messages.single.role, LlmRole.user);
      expect(request.messages.single.content, 'Dobrý den, hledám byt.');
      expect(
        request.context['task_description'],
        'Write an email to a landlord.',
      );
    });
  });

  group('parseTutorResponse', () {
    test('parses a complete response', () {
      final response = LlmResponse(
        content: jsonEncode({
          'tutor_reply_cz': 'Ahoj!',
          'tutor_reply_en': 'Hi!',
          'corrections': [
            {
              'type': 'verb_conjugation',
              'user_said': 'já jsi',
              'correct': 'já jsem',
              'rule': 'být conjugation',
              'severity': 'error',
            },
          ],
          'new_vocabulary': [
            {'cz': 'ahoj', 'en': 'hi'},
          ],
        }),
      );

      final parsed = orchestrator.parseTutorResponse(response);
      expect(parsed.tutorReplyCz, 'Ahoj!');
      expect(parsed.corrections, hasLength(1));
      expect(parsed.corrections.first.type, CorrectionType.verbConjugation);
      expect(parsed.newVocabulary, hasLength(1));
    });

    test('tolerates missing optional fields', () {
      final response = LlmResponse(
        content: jsonEncode({'tutor_reply_cz': 'Ahoj!'}),
      );
      final parsed = orchestrator.parseTutorResponse(response);
      expect(parsed.tutorReplyEn, '');
      expect(parsed.corrections, isEmpty);
      expect(parsed.newVocabulary, isEmpty);
    });

    test('throws FormatException when the reply itself is missing', () {
      final response = LlmResponse(content: jsonEncode({'foo': 'bar'}));
      expect(
        () => orchestrator.parseTutorResponse(response),
        throwsFormatException,
      );
    });
  });

  group('parseTutorResponseSafe', () {
    test('returns OK for valid JSON', () {
      final response = LlmResponse(
        content: jsonEncode({
          'tutor_reply_cz': 'Ahoj!',
          'tutor_reply_en': 'Hi!',
        }),
      );

      final result = orchestrator.parseTutorResponseSafe(response);
      expect(result, isA<TutorParseOk>());
      final ok = result as TutorParseOk;
      expect(ok.response.tutorReplyCz, 'Ahoj!');
    });

    test('returns error for empty content', () {
      final result = orchestrator.parseTutorResponseSafe(
        const LlmResponse(content: ''),
      );
      expect(result, isA<TutorParseError>());
      expect((result as TutorParseError).reason, contains('empty'));
    });

    test('returns error for malformed JSON', () {
      final result = orchestrator.parseTutorResponseSafe(
        const LlmResponse(content: 'not json at all'),
      );
      expect(result, isA<TutorParseError>());
      expect((result as TutorParseError).reason, contains('unreadable'));
      expect(result.rawLength, 'not json at all'.length);
    });

    test('returns error for non-object JSON', () {
      final result = orchestrator.parseTutorResponseSafe(
        const LlmResponse(content: '[1, 2, 3]'),
      );
      expect(result, isA<TutorParseError>());
      expect((result as TutorParseError).reason, contains('not a JSON object'));
    });

    test('returns error for missing required fields', () {
      final result = orchestrator.parseTutorResponseSafe(
        LlmResponse(content: jsonEncode({'foo': 'bar'})),
      );
      expect(result, isA<TutorParseError>());
      expect(
        (result as TutorParseError).reason,
        contains('missing required information'),
      );
    });
  });

  group('CorrectionType.parse', () {
    test('accepts LLM snake_case labels', () {
      expect(
        CorrectionType.parse('verb_conjugation'),
        CorrectionType.verbConjugation,
      );
      expect(CorrectionType.parse('word_order'), CorrectionType.wordOrder);
      expect(CorrectionType.parse('case'), CorrectionType.case_);
    });

    test('accepts Dart enum names persisted by older builds', () {
      expect(
        CorrectionType.parse('verbConjugation'),
        CorrectionType.verbConjugation,
      );
      expect(CorrectionType.parse('case_'), CorrectionType.case_);
    });

    test('unknown labels fall back to other instead of crashing', () {
      expect(CorrectionType.parse('emphasis'), CorrectionType.other);
      expect(CorrectionType.parse(''), CorrectionType.other);
    });
  });
}
