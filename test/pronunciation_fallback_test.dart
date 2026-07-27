import 'package:ceskina_pro/data/services/stt/whisper_service.dart';
import 'package:ceskina_pro/domain/repositories/speech_ports.dart';
import 'package:ceskina_pro/presentation/providers/stt_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

/// Phase 0B: a linked backend without a usable `whisper-proxy` must never
/// hard-fail the pronunciation exercise. The assessor degrades to on-device
/// recognition, and cloud capability is reactive rather than client-presence.
void main() {
  test('unavailable cloud transcriber routes straight to native STT', () async {
    final recorder = _FakeRecorder();
    final native = _FakeLiveTranscriber(result: 'dobrý den');
    final assessor = PronunciationAssessor(
      recorder: recorder,
      whisper: _FakeCloud(available: false),
      fallbackStt: native,
      log: Logger('test'),
    );

    expect(assessor.hasWhisper, isFalse);
    final assessment = await assessor.assess(expectedText: 'Dobrý den');

    expect(assessment.usedWhisper, isFalse);
    expect(assessment.transcribedText, 'dobrý den');
    // The cloud path was never entered, so no recording happened.
    expect(recorder.startCount, 0);
    expect(native.listenCount, 1);
  });

  test(
    'runtime cloud failure degrades to native STT without hard-failing',
    () async {
      final recorder = _FakeRecorder();
      final native = _FakeLiveTranscriber(result: 'na shledanou');
      final assessor = PronunciationAssessor(
        recorder: recorder,
        // Available capability, but the proxy throws at transcribe time —
        // exactly the "function not deployed" case.
        whisper: _FakeCloud(available: true, throwOnTranscribe: true),
        fallbackStt: native,
        log: Logger('test'),
      );

      expect(assessor.hasWhisper, isTrue);
      final assessment = await assessor.assess(
        expectedText: 'Na shledanou',
        maxDuration: Duration.zero,
      );

      expect(assessment.usedWhisper, isFalse);
      expect(assessment.transcribedText, 'na shledanou');
      // Cloud path recorded, then cleaned up before degrading.
      expect(recorder.startCount, 1);
      expect(recorder.cleanupCount, greaterThanOrEqualTo(1));
      expect(native.listenCount, 1);
    },
  );
}

class _FakeCloud implements CloudTranscriber {
  _FakeCloud({required this.available, this.throwOnTranscribe = false});

  final bool available;
  final bool throwOnTranscribe;

  @override
  bool get isAvailable => available;

  @override
  Future<WhisperResult> transcribe({
    required String audioPath,
    String language = 'cs',
    String? prompt,
  }) async {
    if (throwOnTranscribe) {
      throw Exception('whisper-proxy not deployed');
    }
    return const WhisperResult(
      text: 'cloud',
      language: 'cs',
      duration: 1,
      words: [],
    );
  }
}

class _FakeRecorder implements AudioRecorderPort {
  int startCount = 0;
  int stopCount = 0;
  int cleanupCount = 0;
  bool _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<String> start() async {
    startCount++;
    _recording = true;
    return '/tmp/fake.wav';
  }

  @override
  Future<String> stop() async {
    stopCount++;
    _recording = false;
    return '/tmp/fake.wav';
  }

  @override
  Future<void> cleanup() async {
    cleanupCount++;
  }

  @override
  Future<String> recordUntilSilence({
    Duration silenceTimeout = const Duration(seconds: 3),
    Duration maxDuration = const Duration(seconds: 15),
    Future<void>? stopSignal,
  }) async {
    await start();
    return stop();
  }
}

class _FakeLiveTranscriber implements LiveTranscriber {
  _FakeLiveTranscriber({required this.result});

  final String result;
  int listenCount = 0;

  @override
  Future<String> listenFor({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    listenCount++;
    return result;
  }

  @override
  Future<void> stop() async {}
}
