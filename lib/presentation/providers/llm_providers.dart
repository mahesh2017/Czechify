import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/supabase_llm_service.dart';
import '../../data/repositories/llm_service_exception.dart';
import '../../domain/engines/llm_orchestrator.dart';
import '../../domain/repositories/llm_service.dart';
import 'sync_providers.dart';

/// Resolves backend readiness for every request. Offline/unavailable AI fails
/// explicitly; production must never fabricate tutoring or assessment output.
final llmServiceProvider = Provider<LlmService>((ref) {
  final backend = ref.watch(backendServiceProvider);
  return BackendAwareLlmService(() async {
    await backend.init();
    if (!backend.isSignedIn) await backend.ensureAnonymousSession();
    return backend.client;
  });
});

final llmOrchestratorProvider = Provider<LLMOrchestrator>((ref) {
  return const LLMOrchestrator();
});

class BackendAwareLlmService implements LlmService {
  BackendAwareLlmService(this._clientResolver);
  final Future<SupabaseClient?> Function() _clientResolver;

  Future<LlmService> _delegate() async {
    final client = await _clientResolver();
    if (client == null || client.auth.currentSession == null) {
      throw const LlmServiceException(
        'AI feedback is unavailable. Check your internet connection and try again.',
      );
    }
    return SupabaseLlmService(client: client);
  }

  @override
  Future<LlmResponse> complete(LlmRequest request) async =>
      (await _delegate()).complete(request);

  @override
  Stream<LlmChunk> streamComplete(LlmRequest request) async* {
    yield* (await _delegate()).streamComplete(request);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await (await _delegate()).isAvailable();
    } catch (_) {
      return false;
    }
  }
}
