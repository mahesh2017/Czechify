import 'dart:convert';
import 'package:logging/logging.dart';
import '../repositories/llm_service.dart';
import '../entities/chat_message.dart';
import '../entities/enums.dart';

/// LLM Orchestrator — builds prompts and parses structured responses.
/// Stateless: callers pass the built request to whichever [LlmService]
/// is currently configured.
class LLMOrchestrator {
  const LLMOrchestrator();

  static final _log = Logger('LLMOrchestrator');

  /// Most history messages sent with a turn.
  ///
  /// The server rejects a conversation of more than 24 messages outright
  /// (`parseMessages` in `supabase/functions/deepseek-proxy/request_policy.ts`
  /// is the source of truth). History was previously sent whole and grows by
  /// two messages per exchange, so a conversation passed that ceiling after
  /// about twelve turns and every request from then on — including retries and
  /// any later attempt to resume the thread — failed identically. The window
  /// leaves room for the new user message plus headroom.
  static const maxHistoryMessages = 20;

  /// Character budget for everything sent with a turn. The server's own limit
  /// is 12,000; staying under it keeps a long exchange from failing the moment
  /// the count window alone would have allowed it through.
  static const maxTotalCharacters = 11000;

  /// Longest summary the server will accept in a context value.
  static const maxSummaryCharacters = 2000;

  /// Build a conversation turn request with system prompt and history.
  ///
  /// [earlierSummary] carries turns that have fallen out of the window, so a
  /// long conversation keeps its thread instead of the tutor losing the
  /// beginning of it. Null or empty simply omits it.
  LlmRequest buildConversationRequest({
    required CEFRLevel level,
    required String scenarioId,
    required String userMessage,
    required List<ChatMessage> history,
    String? earlierSummary,
  }) {
    final messages = <LlmMessage>[
      ..._windowedHistory(history, userMessage),
      LlmMessage(LlmRole.user, userMessage),
    ];

    final summary = earlierSummary?.trim();
    return LlmRequest(
      operation: LlmOperation.conversation,
      model: _selectModel(level),
      messages: messages,
      context: {
        'level': level.name,
        'scenario_id': scenarioId,
        if (summary != null && summary.isNotEmpty)
          // Truncated rather than dropped: a summary slightly over the limit
          // still carries most of the thread, and the whole request being
          // rejected for it would be a worse outcome than losing a sentence.
          'summary':
              summary.length <= maxSummaryCharacters
                  ? summary
                  : summary.substring(0, maxSummaryCharacters),
      },
    );
  }

  /// The messages that [buildConversationRequest] would drop for this turn.
  ///
  /// Callers summarize these before they are lost. Returns empty when the
  /// whole history still fits, which is the common case.
  List<ChatMessage> messagesFallingOutOfWindow({
    required List<ChatMessage> history,
    required String userMessage,
  }) {
    final kept = _windowedHistory(history, userMessage).length;
    return kept >= history.length
        ? const []
        : history.sublist(0, history.length - kept);
  }

  /// Build a request that condenses [messages] into a note for the tutor.
  LlmRequest buildConversationSummaryRequest({
    required CEFRLevel level,
    required List<ChatMessage> messages,
    String? previousSummary,
  }) {
    // The previous summary leads, so successive compressions accumulate rather
    // than each one forgetting what the one before it knew.
    final previous = previousSummary?.trim();
    return LlmRequest(
      operation: LlmOperation.conversationSummary,
      model: _selectModel(level),
      messages: [
        if (previous != null && previous.isNotEmpty)
          LlmMessage(LlmRole.user, 'Earlier summary: $previous'),
        ..._windowedHistory(messages, ''),
      ],
      context: {'level': level.name},
    );
  }

  /// The most recent slice of [history] that fits both server limits.
  ///
  /// Oldest-first is the right thing to drop: recent turns carry the thread the
  /// tutor is answering. [userMessage] is never dropped — it is what the turn
  /// is for — so it claims its share of the budget before history gets any.
  /// A single message longer than the server's 4,000-character per-message cap
  /// is still refused server-side; that is an input-length concern, not a
  /// windowing one.
  List<LlmMessage> _windowedHistory(
    List<ChatMessage> history,
    String userMessage,
  ) {
    final budget = maxTotalCharacters - userMessage.length;
    final kept = <LlmMessage>[];
    var used = 0;
    for (final message in history.reversed) {
      if (kept.length >= maxHistoryMessages) break;
      if (used + message.content.length > budget) break;
      used += message.content.length;
      kept.add(
        LlmMessage(
          message.role == MessageRole.user ? LlmRole.user : LlmRole.assistant,
          message.content,
        ),
      );
    }
    return kept.reversed.toList();
  }

  /// Parse the LLM response into structured data.
  ///
  /// Throws [FormatException] when the response is not valid JSON or is
  /// missing required fields. Callers are expected to catch this and show
  /// a user-facing fallback. The [parseTutorResponseSafe] variant returns
  /// a typed result instead.
  TutorResponse parseTutorResponse(LlmResponse response) {
    final json = jsonDecode(response.content) as Map<String, dynamic>;
    return TutorResponse.fromJson(json);
  }

  /// Parse the LLM response with structured error handling.
  ///
  /// Returns a [TutorParseResult] that distinguishes between:
  /// - [TutorParseOk] — successful parse
  /// - [TutorParseError] — malformed JSON or missing fields, with a
  ///   human-readable reason and the raw content length for telemetry.
  ///
  /// This is the preferred entry point for new call sites. The throwing
  /// [parseTutorResponse] is retained for backward compatibility.
  TutorParseResult parseTutorResponseSafe(LlmResponse response) {
    final content = response.content;
    if (content.isEmpty) {
      _log.warning('LLM returned empty content');
      return const TutorParseError(
        reason: 'The tutor returned an empty response.',
      );
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        _log.warning('LLM returned non-object JSON: ${decoded.runtimeType}');
        return const TutorParseError(
          reason: 'The tutor response was not a JSON object.',
        );
      }
      json = decoded;
    } on FormatException catch (e) {
      _log.warning('LLM returned invalid JSON: ${e.message}');
      return TutorParseError(
        reason: 'The tutor sent an unreadable reply.',
        rawLength: content.length,
      );
    }

    try {
      return TutorParseOk(TutorResponse.fromJson(json));
    } on FormatException catch (e) {
      _log.warning('LLM JSON missing required fields: ${e.message}');
      return TutorParseError(
        reason: 'The tutor response was missing required information.',
        rawLength: content.length,
      );
    } on TypeError catch (e) {
      _log.warning('LLM JSON has wrong types: $e');
      return TutorParseError(
        reason: 'The tutor response had unexpected data.',
        rawLength: content.length,
      );
    }
  }

  /// Reads the summary out of a [LlmOperation.conversationSummary] reply.
  ///
  /// Returns null on anything unusable. Summarization is an optimization: if
  /// it fails the conversation continues with a shorter memory, which is
  /// strictly better than surfacing an error for something the learner never
  /// asked for and cannot act on.
  String? parseConversationSummary(LlmResponse response) {
    try {
      final decoded = jsonDecode(response.content);
      if (decoded is! Map<String, dynamic>) return null;
      final summary = decoded['summary'];
      if (summary is! String) return null;
      final trimmed = summary.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (e) {
      _log.warning('Unusable conversation summary', e);
      return null;
    }
  }

  /// Build a grammar check request.
  LlmRequest buildGrammarCheckRequest({
    required CEFRLevel level,
    required String userText,
  }) {
    return LlmRequest(
      operation: LlmOperation.grammarCheck,
      model: _selectModel(level),
      messages: [LlmMessage(LlmRole.user, userText)],
      context: {'level': level.name},
    );
  }

  /// Build a writing evaluation request (for mock exam writing section).
  LlmRequest buildWritingEvaluationRequest({
    required CEFRLevel level,
    required String taskDescription,
    required String learnerText,
  }) {
    return LlmRequest(
      operation: LlmOperation.writingEvaluation,
      model: _selectModel(level),
      messages: [LlmMessage(LlmRole.user, learnerText)],
      context: {'level': level.name, 'task_description': taskDescription},
    );
  }

  String _selectModel(CEFRLevel level) {
    // Informational metadata only: the server owns the actual model choice.
    return 'deepseek-v4-flash-0731';
  }
}

/// Result of parsing a tutor response — either OK or an error.
sealed class TutorParseResult {
  const TutorParseResult();
}

/// Successful parse.
class TutorParseOk extends TutorParseResult {
  final TutorResponse response;
  const TutorParseOk(this.response);
}

/// Failed parse with a human-readable reason.
class TutorParseError extends TutorParseResult {
  final String reason;

  /// Length of the raw LLM content, for telemetry. Null when the content
  /// was empty or not string-typed.
  final int? rawLength;

  const TutorParseError({required this.reason, this.rawLength});
}
