import '../entities/chat_message.dart';

/// Abstract interface for LLM API calls.
abstract class LlmService {
  Future<LlmResponse> complete(LlmRequest request);
  Stream<LlmChunk> streamComplete(LlmRequest request);
  Future<bool> isAvailable();
}

/// LLM request.
class LlmRequest {
  final LlmOperation operation;
  final String model;
  final List<LlmMessage> messages;
  final Map<String, String> context;

  const LlmRequest({
    required this.operation,
    required this.model,
    required this.messages,
    this.context = const {},
  });
}

/// Product operations exposed by the server-side AI gateway.
///
/// The Edge Function owns prompts, model parameters, and output limits; the
/// client supplies only bounded learner content and operation context.
enum LlmOperation {
  conversation('conversation'),

  /// Condenses turns the client is about to drop from its window so the tutor
  /// keeps continuity. Internal: the learner never sees the output, and the
  /// server exempts it from the daily allowance because they did not ask for
  /// it — a long conversation should not quietly cost double.
  conversationSummary('conversation_summary'),

  grammarCheck('grammar_check'),
  writingEvaluation('writing_evaluation');

  const LlmOperation(this.apiName);
  final String apiName;
}

/// LLM message.
class LlmMessage {
  final LlmRole role;
  final String content;

  const LlmMessage(this.role, this.content);
}

enum LlmRole { system, user, assistant }

/// LLM response.
class LlmResponse {
  final String content;
  final int inputTokens;
  final int outputTokens;
  final String? model;

  /// Turns left in today's allowance, or null when the server did not say.
  ///
  /// The quota was always enforced server-side but never reported, so a
  /// learner discovered it only by being refused mid-conversation. Nullable
  /// because an older deployed function omits the field entirely — the UI
  /// shows nothing rather than guessing.
  final int? remainingToday;

  /// The full daily allowance, for phrasing "3 of 20 left".
  final int? dailyLimit;

  const LlmResponse({
    required this.content,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.model,
    this.remainingToday,
    this.dailyLimit,
  });
}

/// Streaming LLM chunk.
class LlmChunk {
  final String delta;
  final bool isFinal;

  const LlmChunk({required this.delta, this.isFinal = false});
}

/// Parsed tutor response from LLM.
class TutorResponse {
  final String tutorReplyCz;
  final String tutorReplyEn;
  final List<Correction> corrections;
  final List<NewVocabulary> newVocabulary;

  /// Short Czech replies the learner could send next (A1-level scaffolding
  /// for learners who freeze). Optional — older responses omit it.
  final List<String> suggestedReplies;

  const TutorResponse({
    required this.tutorReplyCz,
    required this.tutorReplyEn,
    required this.corrections,
    required this.newVocabulary,
    this.suggestedReplies = const [],
  });

  factory TutorResponse.fromJson(Map<String, dynamic> json) {
    final replyCz = json['tutor_reply_cz'] as String?;
    if (replyCz == null || replyCz.isEmpty) {
      throw const FormatException('Tutor response is missing tutor_reply_cz');
    }
    return TutorResponse(
      tutorReplyCz: replyCz,
      tutorReplyEn: json['tutor_reply_en'] as String? ?? '',
      corrections:
          (json['corrections'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(Correction.fromJson)
              .toList() ??
          [],
      newVocabulary:
          (json['new_vocabulary'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(NewVocabulary.fromJson)
              .toList() ??
          [],
      suggestedReplies:
          (json['suggested_replies'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
    );
  }
}
