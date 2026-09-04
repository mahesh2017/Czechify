import 'package:czechify/data/services/stt/whisper_service.dart';
import 'package:czechify/domain/repositories/speech_ports.dart';
import 'package:czechify/presentation/providers/stt_providers.dart';
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
      // Even an available cloud must not run without an affirmative decision.
      whisper: _FakeCloud(available: true),
      fallbackStt: native,
      log: Logger('test'),
    );

    expect(assessor.hasWhisper, isTrue);
    final assessment = await assessor.assess(expectedText: 'Dobrý den');

    expect(assessment.usedWhisper, isFalse);
    expect(assessment.transcribedText, 'dobrý den');
    // The cloud path was never entered, so no recording happened.
    expect(recorder.startCount, 0);
    expect(native.listenCount, 1);
  });

  test('a phone with no Czech recogniser is told so, not scored anyway', () async {
    // Czech ships on almost no phone sold outside Czechia. Without it the
    // platform listens in the device's default language and hands back an
    // English-shaped transcription of Czech speech, which the scorer reads as
    // a bad pronunciation — telling a learner they got it wrong when they got
    // it right. Refusing is the honest outcome.
    final native = _FakeLiveTranscriber(
      result: 'toy a kava',
      czechAvailable: false,
    );
    final assessor = PronunciationAssessor(
      recorder: _FakeRecorder(),
      whisper: _FakeCloud(available: false),
      fallbackStt: native,
      log: Logger('test'),
    );

    await expectLater(
      assessor.assess(expectedText: 'To je káva'),
      throwsA(isA<SpeechServiceException>()),
    );
    // It never listened, so nothing was scored against the wrong language.
    expect(native.listenCount, 0);
  });

  test('the refusal is one the app can offer a way out of', () async {
    final assessor = PronunciationAssessor(
      recorder: _FakeRecorder(),
      whisper: _FakeCloud(available: false),
      fallbackStt: _FakeLiveTranscriber(result: '', czechAvailable: false),
      log: Logger('test'),
    );

    try {
      await assessor.assess(expectedText: 'To je káva');
      fail('expected a SpeechServiceException');
    } on SpeechServiceException catch (e) {
      expect(e.message, contains('Czech'));
      expect(e.isQuotaExhausted, isFalse);
      // The UI offers the switch rather than describing where to find it, so
      // the failure has to say that turning cloud speech on would fix it.
      expect(e.cloudSpeechWouldFix, isTrue);
    }
  });

  test(
    'a cloud failure on captured audio is reported, not silently re-recorded',
    () async {
      // This case used to degrade to a live on-device listen. The learner had
      // already spoken and the UI had already switched to "analyzing", so that
      // second listen captured silence, scored it against the target, and
      // presented ~0% as a pronunciation result — telling someone they
      // mispronounced a phrase they may have said perfectly.
      final recorder = _FakeRecorder();
      final native = _FakeLiveTranscriber(result: 'na shledanou');
      final assessor = PronunciationAssessor(
        recorder: recorder,
        // Available capability, but the proxy throws at transcribe time —
        // exactly the "function not deployed" case.
        whisper: _FakeCloud(available: true, throwOnTranscribe: true),
        fallbackStt: native,
        log: Logger('test'),
        cloudConsentGranted: () async => true,
      );

      expect(assessor.hasWhisper, isTrue);
      await expectLater(
        assessor.assess(
          expectedText: 'Na shledanou',
          maxDuration: Duration.zero,
        ),
        throwsA(isA<SpeechServiceException>()),
      );

      expect(recorder.startCount, 1);
      expect(recorder.cleanupCount, greaterThanOrEqualTo(1));
      expect(
        native.listenCount,
        0,
        reason: 'the learner already spoke; re-recording invents an answer',
      );
    },
  );

  test('the exercise stays completable after a cloud failure', () async {
    // "Never hard-fail the exercise" still holds — it is honoured across
    // attempts rather than within one by fabricating a score. The failed
    // attempt is reported, cloud speech is dropped for the session, and the
    // next attempt takes the native path from the start, where listening live
    // is what the learner is actually being asked to do.
    final recorder = _FakeRecorder();
    final native = _FakeLiveTranscriber(result: 'na shledanou');
    final assessor = PronunciationAssessor(
      recorder: recorder,
      whisper: _FakeCloud(available: true, throwOnTranscribe: true),
      fallbackStt: native,
      log: Logger('test'),
      cloudConsentGranted: () async => true,
    );

    await expectLater(
      assessor.assess(expectedText: 'Na shledanou', maxDuration: Duration.zero),
      throwsA(isA<SpeechServiceException>()),
    );
    expect(assessor.hasWhisper, isFalse, reason: 'cloud dropped for session');

    final second = await assessor.assess(
      expectedText: 'Na shledanou',
      maxDuration: Duration.zero,
    );

    expect(second.usedWhisper, isFalse);
    expect(second.transcribedText, 'na shledanou');
    expect(native.listenCount, 1);
    expect(
      recorder.startCount,
      1,
      reason: 'the second attempt never enters the cloud capture path',
    );
  });

  test('a recorder that cannot start still degrades to a live listen', () async {
    // No audio was captured, so nothing has been asked of the learner yet and
    // prompting them to speak is honest — the opposite of the case above.
    final native = _FakeLiveTranscriber(result: 'dobrý den');
    final assessor = PronunciationAssessor(
      recorder: _BrokenRecorder(),
      whisper: _FakeCloud(available: true),
      fallbackStt: native,
      log: Logger('test'),
      cloudConsentGranted: () async => true,
    );

    final assessment = await assessor.assess(
      expectedText: 'Dobrý den',
      maxDuration: Duration.zero,
    );

    expect(assessment.usedWhisper, isFalse);
    expect(assessment.transcribedText, 'dobrý den');
    expect(native.listenCount, 1);
  });
}

/// A recorder whose capture never starts (no permission, no device).
class _BrokenRecorder extends _FakeRecorder {
  @override
  Future<String> recordUntilSilence({
    Duration silenceTimeout = const Duration(seconds: 3),
    Duration maxDuration = const Duration(seconds: 15),
    Future<void>? stopSignal,
  }) async => throw Exception('microphone unavailable');
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
  _FakeLiveTranscriber({required this.result, this.czechAvailable = true});

  final String result;

  /// Whether the phone has a Czech language pack. False on most devices sold
  /// outside Czechia, which is the case worth testing.
  final bool czechAvailable;

  int listenCount = 0;

  @override
  Future<bool> supportsCzech() async => czechAvailable;

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
