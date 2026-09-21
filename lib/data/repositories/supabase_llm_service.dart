import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/llm_service.dart';
import 'llm_service_exception.dart';

/// Calls the server-side LLM proxy. The Scaleway credential never enters the
/// app binary; Supabase attaches the current anonymous/user JWT instead.
class SupabaseLlmService implements LlmService {
  // SupabaseClient is public while the field is intentionally private.
  // ignore: prefer_initializing_formals
  SupabaseLlmService({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    try {
      final response = await _client.functions.invoke(
        'deepseek-proxy',
        body: {
          'operation': request.operation.apiName,
          'messages':
              request.messages
                  .map(
                    (message) => {
                      'role': message.role.name,
                      'content': message.content,
                    },
                  )
                  .toList(),
          'context': request.context,
          if (request.requestId != null) 'request_id': request.requestId,
          if (request.sessionId != null) 'session_id': request.sessionId,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      return LlmResponse(
        content: data['content'] as String,
        inputTokens: (data['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (data['output_tokens'] as num?)?.toInt() ?? 0,
        model: data['model'] as String?,
        // Absent from an older deployed function; null means "don't show".
        remainingToday: (data['remaining_today'] as num?)?.toInt(),
        dailyLimit: (data['daily_limit'] as num?)?.toInt(),
      );
    } on FunctionException catch (error) {
      throw llmFailure(error.status, error.details, request.operation);
    } catch (error) {
      if (error is LlmServiceException) rethrow;
      throw const LlmServiceException(
        'Could not reach the AI tutor. Check your connection and try again.',
      );
    }
  }

  /// Streaming is not used by the current UI. Preserve the interface by
  /// yielding the completed payload as one final chunk.
  @override
  Stream<LlmChunk> streamComplete(LlmRequest request) async* {
    final response = await complete(request);
    yield LlmChunk(delta: response.content, isFinal: true);
  }

  @override
  Future<bool> isAvailable() async => _client.auth.currentSession != null;
}

/// The learner-facing failure for a proxy error response. Course feedback
/// refusals carry only a code, and their status alone would read as the
/// tutor's chat limit.
LlmServiceException llmFailure(
  int status,
  Object? details,
  LlmOperation operation,
) {
  final code = details is Map ? details['code']?.toString() : null;
  final message = details is Map ? details['error']?.toString() : null;
  final chat =
      operation == LlmOperation.conversation ||
      operation == LlmOperation.conversationSummary;
  final byCode = switch (code) {
    'course_access_required' =>
      'Feedback on this exam is part of the full course.',
    'quota_exceeded' when chat =>
      'Daily AI tutor limit reached. Try again tomorrow.',
    'quota_exceeded' => 'Daily feedback limit reached. Try again tomorrow.',
    'client_update_required' ||
    'unknown_task' => 'Update Czechify to get feedback on this task.',
    'ai_temporarily_unavailable' || 'result_unavailable' =>
      'The AI tutor is temporarily unavailable. Try again later.',
    _ => null,
  };
  final byStatus = switch (status) {
    401 => 'Your session expired. Restart the app and try again.',
    429 => 'Daily AI tutor limit reached. Try again tomorrow.',
    >= 500 => 'The AI tutor is temporarily unavailable. Try again later.',
    _ => 'The AI tutor could not complete that request.',
  };
  return LlmServiceException(byCode ?? message ?? byStatus, code: code);
}
