/// Custom app exceptions.
class AppException implements Exception {
  AppException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException: $message';
}

class OfflineTranscriptionError extends AppException {
  OfflineTranscriptionError()
    : super(
        'Cannot transcribe audio offline. Vosk failed and no internet for Whisper fallback.',
      );
}

class AllProvidersFailedError extends AppException {
  AllProvidersFailedError() : super('All LLM providers failed.');
}

class ContentNotSeededError extends AppException {
  ContentNotSeededError()
    : super('Curriculum content has not been seeded yet.');
}

class InvalidApiKeyError extends AppException {
  InvalidApiKeyError(String provider)
    : super('Invalid or missing API key for provider: $provider');
}

class TtsSynthesisError extends AppException {
  TtsSynthesisError(String detail) : super('TTS synthesis failed: $detail');
}
