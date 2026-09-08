import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/llm_service_exception.dart';
import '../../domain/entities/enums.dart';
import 'llm_providers.dart';

/// Result of an AI writing evaluation.
class WritingEvaluation {
  final int grammar;
  final int vocabulary;
  final int coherence;
  final int overall;
  final String feedback;
  final List<Map<String, dynamic>> errors;

  const WritingEvaluation({
    required this.grammar,
    required this.vocabulary,
    required this.coherence,
    required this.overall,
    required this.feedback,
    required this.errors,
  });

  /// Throws [FormatException] when the payload is not an evaluation.
  ///
  /// Every field used to fall back to a default, so `fromJson({})` produced a
  /// perfectly well-formed evaluation scoring zero on everything with no
  /// feedback — indistinguishable from a real assessment of a bad answer. A
  /// provider that returned the wrong shape therefore cost the learner a
  /// quota unit and appeared to them as their own failure.
  ///
  /// Requiring only `overall` was the same bug with a smaller blast radius:
  /// `{"score":{"overall":85}}` still yielded three criterion scores of zero
  /// this code had invented, shown to the learner beside a real one as though
  /// they carried the same weight. A default is a claim about the learner's
  /// writing, and there is no default that is safe to make.
  ///
  /// The model is told what shape to return, and the server now checks the
  /// reply against that schema, but neither is a runtime guarantee here: an
  /// older deployment or a changed provider reaches this code first. A missing
  /// criterion means no evaluation happened, and the caller must treat it as
  /// an evaluation failure rather than a grade.
  factory WritingEvaluation.fromJson(Map<String, dynamic> json) {
    final score = json['score'];
    if (score is! Map<String, dynamic>) {
      throw const FormatException('writing evaluation has no score object');
    }
    final feedback = json['feedback'];
    if (feedback is! String || feedback.trim().isEmpty) {
      throw const FormatException('writing evaluation has no feedback');
    }
    return WritingEvaluation(
      grammar: _requiredScore(score, 'grammar'),
      vocabulary: _requiredScore(score, 'vocabulary'),
      coherence: _requiredScore(score, 'coherence'),
      overall: _requiredScore(score, 'overall'),
      feedback: feedback,
      errors:
          (json['errors'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [],
    );
  }

  /// One criterion the model was asked to assess, or nothing.
  ///
  /// Clamped rather than refused when out of range: a 101 is a real judgement
  /// expressed sloppily, and reading it as 100 loses nothing. Absent, or not a
  /// finite number, is different — there is no judgement to read.
  static int _requiredScore(Map<String, dynamic> score, String criterion) {
    final value = score[criterion];
    if (value is! num || !value.isFinite) {
      throw FormatException('writing evaluation has no $criterion score');
    }
    return value.clamp(0, 100).round();
  }
}

/// State for writing evaluation.
class WritingEvalState {
  final bool isEvaluating;
  final WritingEvaluation? evaluation;
  final String? error;

  const WritingEvalState({
    this.isEvaluating = false,
    this.evaluation,
    this.error,
  });

  WritingEvalState copyWith({
    bool? isEvaluating,
    WritingEvaluation? evaluation,
    String? error,
  }) {
    return WritingEvalState(
      isEvaluating: isEvaluating ?? this.isEvaluating,
      evaluation: evaluation ?? this.evaluation,
      error: error,
    );
  }
}

/// Notifier for writing evaluation.
class WritingEvalNotifier extends Notifier<WritingEvalState> {
  @override
  WritingEvalState build() => const WritingEvalState();

  /// Evaluate a learner's writing using the LLM.
  ///
  /// Returns null on failure — the error is surfaced via [WritingEvalState]
  /// so the UI shows what happened instead of a fabricated score.
  Future<WritingEvaluation?> evaluate({
    required CEFRLevel level,
    required String taskDescription,
    required String learnerText,
  }) async {
    state = const WritingEvalState(isEvaluating: true);

    try {
      final orchestrator = ref.read(llmOrchestratorProvider);
      final request = orchestrator.buildWritingEvaluationRequest(
        level: level,
        taskDescription: taskDescription,
        learnerText: learnerText,
      );

      final llm = ref.read(llmServiceProvider);
      final response = await llm.complete(request);

      final json = jsonDecode(response.content) as Map<String, dynamic>;
      final evaluation = WritingEvaluation.fromJson(json);

      state = WritingEvalState(evaluation: evaluation);
      return evaluation;
    } on LlmServiceException catch (e) {
      state = WritingEvalState(error: e.message);
      return null;
    } on FormatException {
      state = const WritingEvalState(
        error: 'The AI returned an unreadable evaluation. Try again.',
      );
      return null;
    } catch (_) {
      state = const WritingEvalState(
        error:
            'Could not evaluate your writing. '
            'Check your connection and try again.',
      );
      return null;
    }
  }

  void reset() {
    state = const WritingEvalState();
  }
}

/// Provider for writing evaluation.
final writingEvalProvider =
    NotifierProvider<WritingEvalNotifier, WritingEvalState>(
      WritingEvalNotifier.new,
    );
