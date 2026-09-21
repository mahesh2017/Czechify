import 'dart:convert';
import 'dart:io';

import 'package:czechify/data/repositories/supabase_llm_service.dart';
import 'package:czechify/domain/engines/llm_orchestrator.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/repositories/exam_repository.dart';
import 'package:czechify/domain/repositories/llm_service.dart';
import 'package:czechify/presentation/providers/llm_providers.dart';
import 'package:czechify/presentation/providers/writing_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingLlm implements LlmService {
  _RecordingLlm(this.reply);
  final Future<LlmResponse> Function() reply;
  final requests = <LlmRequest>[];

  @override
  Future<LlmResponse> complete(LlmRequest request) {
    requests.add(request);
    return reply();
  }

  @override
  Stream<LlmChunk> streamComplete(LlmRequest request) =>
      const Stream<LlmChunk>.empty();

  @override
  Future<bool> isAvailable() async => true;
}

/// The server evaluates writing only against its own copy of each task. Every
/// task the app can submit must be in that manifest, under the same text.
void main() {
  final manifest =
      jsonDecode(
            File(
              'docs/monetization/fixtures/course_ai_tasks.v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final serverTasks = {
    for (final task in manifest['tasks'] as List)
      (task as Map)['task_id'] as String: task,
  };

  test('every bundled writing question names a server task with its text', () {
    var questions = 0;
    for (final bank in [
      'assets/curriculum/exam_bank_permres_a1.json',
      'assets/curriculum/exam_bank_permres_a2.json',
    ]) {
      final data = jsonDecode(File(bank).readAsStringSync()) as Map;
      for (final exam in data['exams'] as List) {
        final sections = (exam as Map)['sections'] as List;
        for (var s = 0; s < sections.length; s++) {
          final section = sections[s] as Map;
          if (section['type'] != 'writing') continue;
          final items = section['questions'] as List;
          for (var q = 0; q < items.length; q++) {
            questions++;
            final id = examTaskId(exam['id'] as String, s, q);
            final task = serverTasks[id];
            expect(task, isNotNull, reason: '$id is missing from the manifest');
            expect(task!['task_description'], (items[q] as Map)['prompt']);
            expect(task['level'], (data['level'] as String).toLowerCase());
          }
        }
      }
    }
    expect(questions, serverTasks.length, reason: 'no stale server tasks');
  });

  test('a writing request names its task', () {
    final request = const LLMOrchestrator().buildWritingEvaluationRequest(
      level: CEFRLevel.a1,
      taskDescription: 'Write about yourself.',
      learnerText: 'Jmenuji se Eva.',
      taskId: 'a1-practice-1/s1/q0',
    );
    expect(request.context['task_id'], 'a1-practice-1/s1/q0');
    expect(request.messages, hasLength(1));
  });

  group('proxy refusals read as what they are', () {
    test('course access, update and feedback limit', () {
      final access = llmFailure(403, {
        'code': 'course_access_required',
      }, LlmOperation.writingEvaluation);
      expect(access.code, 'course_access_required');
      expect(access.message, contains('full course'));
      expect(
        llmFailure(426, {
          'code': 'client_update_required',
        }, LlmOperation.writingEvaluation).message,
        contains('Update Czechify'),
      );
      expect(
        llmFailure(429, {
          'code': 'quota_exceeded',
        }, LlmOperation.writingEvaluation).message,
        contains('feedback limit'),
      );
    });

    test('a chat limit is not called a feedback limit', () {
      expect(
        llmFailure(429, {
          'code': 'quota_exceeded',
        }, LlmOperation.conversation).message,
        contains('AI tutor limit'),
      );
    });

    test('older responses keep their text and status fallbacks', () {
      expect(
        llmFailure(429, {
          'error': 'Too many AI tutor requests. Try again shortly.',
        }, LlmOperation.conversation).message,
        'Too many AI tutor requests. Try again shortly.',
      );
      final bare = llmFailure(503, null, LlmOperation.conversation);
      expect(bare.message, contains('temporarily unavailable'));
      expect(bare.code, isNull);
    });
  });

  group('exam writing evaluation', () {
    Future<(WritingEvaluation?, _RecordingLlm, ProviderContainer)> evaluate(
      Future<LlmResponse> Function() reply,
    ) async {
      final llm = _RecordingLlm(reply);
      final container = ProviderContainer(
        overrides: [llmServiceProvider.overrideWithValue(llm)],
      );
      addTearDown(container.dispose);
      final result = await container
          .read(writingEvalProvider.notifier)
          .evaluate(
            level: CEFRLevel.a1,
            taskDescription: 'Write about yourself.',
            learnerText: 'Jmenuji se Eva.',
            taskId: examTaskId('a1-practice-1', 1, 0),
          );
      return (result, llm, container);
    }

    test('sends the task the server knows', () async {
      final (result, llm, _) = await evaluate(
        () async => const LlmResponse(
          content:
              '{"feedback":"Dobře.","score":{"grammar":80,"vocabulary":80,'
              '"coherence":80,"overall":80},"errors":[]}',
        ),
      );
      expect(result?.overall, 80);
      expect(llm.requests.single.context['task_id'], 'a1-practice-1/s1/q0');
    });

    test('a refusal shows its own message, not a score', () async {
      final (result, _, container) = await evaluate(
        () => Future.error(
          llmFailure(403, {
            'code': 'course_access_required',
          }, LlmOperation.writingEvaluation),
        ),
      );
      expect(result, isNull);
      expect(
        container.read(writingEvalProvider).error,
        contains('full course'),
      );
    });
  });
}
