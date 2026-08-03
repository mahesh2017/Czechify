import 'package:ceskina_pro/data/services/stt/whisper_service.dart';
import 'package:ceskina_pro/domain/repositories/speech_ports.dart';
import 'package:ceskina_pro/presentation/providers/stt_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

/// Whisper's per-word confidence is blended into each word score at
/// `0.6 * textSimilarity + 0.4 * confidence`. Matching a Whisper word to a
/// scored word means normalizing both, and that normalization used to be
/// asymmetric: Whisper's side was stripped with `[^\w]`, which in Dart is
/// ASCII-only, so "říká" collapsed to "k" while the lookup key kept its
/// diacritics. The keys could not meet, and confidence was silently dropped
/// for essentially every Czech word — the language the app teaches.
void main() {
  Future<PronunciationAssessment> assess({
    required String expected,
    required String heard,
    required List<WhisperWord> words,
  }) {
    final assessor = PronunciationAssessor(
      recorder: _StubRecorder(),
      whisper: _StubTranscriber(text: heard, words: words),
      fallbackStt: _UnusedTranscriber(),
      log: Logger('test'),
      cloudConsentGranted: () async => true,
    );
    return assessor.assess(expectedText: expected);
  }

  test('confidence reaches words carrying Czech diacritics', () async {
    // Perfect transcript (similarity 1.0) but Whisper was only 50% sure.
    // Blended: 0.6 * 1.0 + 0.4 * 0.5 = 0.8 — strictly below the 1.0 the
    // transcript alone would report, so a skipped blend is visible.
    final assessment = await assess(
      expected: 'Řeka šumí',
      heard: 'Řeka šumí',
      words: const [
        WhisperWord(word: 'Řeka', start: 0, end: 1, probability: 0.5),
        WhisperWord(word: 'šumí', start: 1, end: 2, probability: 0.5),
      ],
    );

    for (final score in assessment.result.wordScores) {
      expect(
        score.score,
        closeTo(0.8, 0.001),
        reason: 'confidence was not blended into "${score.word}"',
      );
    }
    expect(assessment.result.overallScore, closeTo(0.8, 0.001));
  });

  test('punctuation and case in Whisper output still match', () async {
    // Whisper emits words with attached punctuation and sentence casing.
    final assessment = await assess(
      expected: 'dobrý den',
      heard: 'Dobrý den.',
      words: const [
        WhisperWord(word: ' Dobrý', start: 0, end: 1, probability: 0.5),
        WhisperWord(word: ' den.', start: 1, end: 2, probability: 0.5),
      ],
    );

    for (final score in assessment.result.wordScores) {
      expect(score.score, closeTo(0.8, 0.001));
    }
  });

  test('a word Whisper never emitted keeps its transcript score', () async {
    final assessment = await assess(
      expected: 'ahoj světe',
      heard: 'ahoj světe',
      words: const [
        WhisperWord(word: 'ahoj', start: 0, end: 1, probability: 0.5),
      ],
    );

    final byWord = {
      for (final score in assessment.result.wordScores) score.word: score.score,
    };
    expect(byWord['ahoj'], closeTo(0.8, 0.001));
    expect(
      byWord['světe'],
      closeTo(1.0, 0.001),
      reason: 'no confidence for this word means no penalty',
    );
  });
}

class _StubRecorder implements AudioRecorderPort {
  @override
  bool get isRecording => false;

  @override
  Future<String> start() async => '/tmp/clip.wav';

  @override
  Future<String> stop() async => '/tmp/clip.wav';

  @override
  Future<void> cleanup() async {}

  @override
  Future<String> recordUntilSilence({
    Duration silenceTimeout = const Duration(seconds: 2),
    Duration maxDuration = const Duration(seconds: 10),
    Future<void>? stopSignal,
  }) async => '/tmp/clip.wav';
}

class _StubTranscriber implements CloudTranscriber {
  _StubTranscriber({required this.text, required this.words});

  final String text;
  final List<WhisperWord> words;

  @override
  bool get isAvailable => true;

  @override
  Future<WhisperResult> transcribe({
    required String audioPath,
    String language = 'cs',
    String? prompt,
  }) async => WhisperResult(
    text: text,
    language: 'cs',
    duration: 2,
    words: words,
  );
}

class _UnusedTranscriber implements LiveTranscriber {
  @override
  Future<String> listenFor({Duration timeout = const Duration(seconds: 10)}) {
    throw StateError('the cloud path must not fall back in these tests');
  }

  @override
  Future<void> stop() async {}
}
