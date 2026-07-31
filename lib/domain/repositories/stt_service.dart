/// Abstract interface for Speech-to-Text.
abstract class SttService {
  Future<String> transcribe(String audioPath);
  Stream<PartialTranscript> transcribeStream(String audioPath);
  Future<bool> isAvailable();
}

/// Partial transcription result for streaming STT.
class PartialTranscript {
  final String text;
  final double confidence;
  final bool isFinal;

  const PartialTranscript({
    required this.text,
    this.confidence = 0.0,
    this.isFinal = false,
  });
}
