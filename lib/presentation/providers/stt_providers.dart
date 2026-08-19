import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/config/backend_config.dart';
import '../../data/services/stt/audio_recorder.dart';
import '../../data/services/stt/whisper_service.dart';
import 'sync_providers.dart';
import 'consent_providers.dart';
import '../../domain/entities/pronunciation_result.dart';
import '../../domain/engines/pronunciation_scorer.dart';
import '../../core/utils/phoneme_mapper.dart';
import '../../core/utils/text_normalizer.dart';
import '../../domain/engines/pronunciation_coverage.dart';
import '../../domain/engines/phoneme_scorer.dart';
import '../../data/services/stt/phoneme_recognizer.dart';
import '../../domain/repositories/speech_ports.dart';
import '../../domain/repositories/stt_service.dart';

/// Provider for the audio recorder.
final audioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the Whisper service. Only available when backend is
/// configured and initialized.
final whisperServiceProvider = Provider<WhisperService?>((ref) {
  final backend = ref.watch(backendServiceProvider);
  return WhisperService(
    // Resolve the client live so a session established after this provider is
    // first read is still picked up.
    clientResolver: () => backend.client,
    log: Logger('WhisperService'),
  );
});

/// Abstract pronunciation assessment provider — tries Whisper first,
/// falls back to OS-native STT when the backend is unavailable.
///
/// This is the primary entry point for pronunciation exercises. It returns
/// a [PronunciationAssessment] which includes the transcription, overall
/// score, per-word scores, and word-level confidence (when available from
/// Whisper).
/// Endpoint of the Czech acoustic recogniser. Empty by default, which keeps
/// phoneme scoring switched off and the app on transcript scoring:
///   --dart-define=PHONEME_SERVICE_URL=https://recogniser.example.com
///
/// Must be `https`. The endpoint receives raw voice recordings, so a cleartext
/// host is ignored rather than trusted — see [PhonemeRecognizer.isConfigured].
const String kPhonemeServiceUrl = String.fromEnvironment('PHONEME_SERVICE_URL');
const String kPhonemeServiceToken = String.fromEnvironment(
  'PHONEME_SERVICE_TOKEN',
);

/// Loaded once; absent or unreadable means "support nothing", so a missing
/// asset can never cause untrustworthy verdicts.
final pronunciationCoverageProvider = FutureProvider<PronunciationCoverage>(
  (ref) => PronunciationCoverage.load(),
);

final pronunciationAssessmentProvider = Provider<PronunciationAssessor>((ref) {
  final backend = ref.watch(backendServiceProvider);
  return PronunciationAssessor(
    phonemeRecognizer:
        kPhonemeServiceUrl.isEmpty
            ? null
            : PhonemeRecognizer(
              baseUrl: kPhonemeServiceUrl,
              apiToken: kPhonemeServiceToken,
              log: Logger('PhonemeRecognizer'),
            ),
    coverage: ref.watch(pronunciationCoverageProvider).value,
    recorder: ref.watch(audioRecorderProvider),
    whisper: ref.watch(whisperServiceProvider),
    fallbackStt: NativeSttService(),
    log: Logger('PronunciationAssessor'),
    cloudConsentGranted:
        () async => await ref.read(cloudSpeechConsentProvider.future),
    // Last-chance session repair: if the user reached the mic before startup
    // sign-in finished (or it failed transiently), retry it now instead of
    // silently degrading to on-device STT for the rest of the session.
    ensureCloudSession: () async {
      await backend.init();
      await backend.ensureAnonymousSession();
    },
  );
});

/// Result of a pronunciation assessment.
class PronunciationAssessment {
  final String transcribedText;
  final PronunciationResult result;
  final List<WhisperWord> whisperWords;

  /// True when this assessment used Whisper (vs OS-native STT fallback).
  final bool usedWhisper;

  /// Short human-readable note on which engine ran and why — surfaced in the UI
  /// as a temporary diagnostic while cloud speech is being validated.
  final String? diagnostic;

  const PronunciationAssessment({
    required this.transcribedText,
    required this.result,
    this.whisperWords = const [],
    this.usedWhisper = false,
    this.diagnostic,
  });
}

// A public named parameter initializes an intentionally private dependency.
// ignore_for_file: prefer_initializing_formals
/// Assesses pronunciation by recording audio and transcribing it.
///
/// When Whisper is available (backend configured), records audio to a WAV
/// file and sends it to the Whisper Edge Function, which returns word-level
/// timestamps and confidence scores. When Whisper is unavailable, falls back
/// to the OS-native `speech_to_text` package for live recognition.
class PronunciationAssessor {
  PronunciationAssessor({
    required AudioRecorderPort recorder,
    required CloudTranscriber? whisper,
    required LiveTranscriber fallbackStt,
    required Logger log,
    Future<void> Function()? ensureCloudSession,
    Future<bool> Function()? cloudConsentGranted,
    PhonemeRecognizer? phonemeRecognizer,
    PronunciationCoverage? coverage,
  }) : _recorder = recorder,
       _whisper = whisper,
       _fallbackStt = fallbackStt,
       _ensureCloudSession = ensureCloudSession,
       _cloudConsentGranted = cloudConsentGranted,
       _phonemeRecognizer = phonemeRecognizer,
       _coverage = coverage,
       _log = log;

  /// Optional acoustic recogniser. When present, reachable, and the phrase is
  /// one the model was measured to handle, its verdict replaces the
  /// transcript-based score — it can see a substituted sound, which comparing
  /// Whisper's cleaned-up text never can.
  final PhonemeRecognizer? _phonemeRecognizer;
  final PronunciationCoverage? _coverage;

  final AudioRecorderPort _recorder;
  final CloudTranscriber? _whisper;
  final LiveTranscriber _fallbackStt;
  final Future<void> Function()? _ensureCloudSession;
  final Future<bool> Function()? _cloudConsentGranted;
  final Logger _log;
  final _scorer = PronunciationScorer();
  final _phonemeScorer = PhonemeScorer();
  final _phonemeMapper = PhonemeMapper();

  /// Signals the in-flight Whisper recording to stop capturing and transcribe.
  Completer<void>? _manualStop;

  /// Set once cloud transcription has failed on captured audio this session.
  /// Its usual causes do not clear on their own, so later attempts skip the
  /// cloud rather than making the learner record into it again to fail again.
  bool _cloudSpeechUnavailable = false;

  /// Whether Whisper is available for high-quality transcription. Reactive to
  /// authenticated backend capability, not merely a configured client object.
  bool get hasWhisper =>
      !_cloudSpeechUnavailable && (_whisper?.isAvailable ?? false);

  /// Record audio and assess pronunciation against [expectedText].
  ///
  /// Recording auto-stops when the speaker falls silent (voice activity), at
  /// the [maxDuration] cap, or on a manual [stop] — whichever comes first — and
  /// the captured audio is always transcribed. [onCaptureComplete] fires the
  /// moment recording ends and transcription begins, so the UI can switch from
  /// "listening" to "analyzing".
  ///
  /// When Whisper is available, records to a WAV file and sends it to the
  /// Whisper API for transcription with word-level confidence. Otherwise uses
  /// OS-native STT for live recognition (lower quality, no confidence).
  Future<PronunciationAssessment> assess({
    required String expectedText,
    Duration maxDuration = const Duration(seconds: 10),
    void Function()? onCaptureComplete,
  }) async {
    final cloudAllowed =
        await (_cloudConsentGranted?.call() ?? Future.value(false));
    if (!cloudAllowed) {
      return _assessWithNativeStt(
        expectedText,
        maxDuration,
        diagnostic: 'on-device (cloud speech not enabled)',
      );
    }
    // If no session exists yet (startup sign-in still in flight, or it failed
    // transiently), make one last attempt to establish it before degrading.
    if (!hasWhisper && _ensureCloudSession != null) {
      try {
        await _ensureCloudSession();
      } catch (e) {
        _log.warning('Cloud session repair failed: $e');
      }
    }
    if (hasWhisper) {
      try {
        return await _assessWithWhisper(
          expectedText,
          maxDuration,
          onCaptureComplete,
        );
      } on _CaptureUnavailable catch (failure) {
        // Nothing was recorded, so a live on-device listen is honest: the
        // learner has not spoken yet and will be prompted to.
        _log.warning('Recorder unavailable; using native STT.', failure.cause);
        await _recorder.cleanup();
        return _assessWithNativeStt(
          expectedText,
          maxDuration,
          diagnostic: 'on-device (recorder unavailable)',
        );
      } on SpeechServiceException {
        // Audio WAS captured and could not be scored. The previous behaviour
        // fell through to a live listen here, which starts a fresh recording
        // while the UI says "analyzing" and the learner is no longer speaking
        // — it transcribed silence and reported the resulting 0% as a
        // pronunciation score. Being told you mispronounced something you said
        // correctly is worse than being told it could not be checked, so this
        // surfaces instead.
        //
        // Cloud speech is then switched off for the rest of the session: the
        // usual cause (proxy undeployed, quota spent) persists, and every later
        // attempt should take the native path from the start, where listening
        // live is the honest thing to do.
        _cloudSpeechUnavailable = true;
        await _recorder.cleanup();
        rethrow;
      }
    }
    return _assessWithNativeStt(
      expectedText,
      maxDuration,
      diagnostic:
          BackendConfig.isConfigured
              ? 'on-device (cloud unavailable — sign-in failed)'
              : 'on-device (backend not configured in this build)',
    );
  }

  Future<PronunciationAssessment> _assessWithWhisper(
    String expectedText,
    Duration maxDuration,
    void Function()? onCaptureComplete,
  ) async {
    final manualStop = _manualStop = Completer<void>();

    // Record until silence, the max cap, or a manual stop — then always
    // transcribe whatever was captured.
    //
    // Capture is separated from transcription because the two failures deserve
    // opposite treatment: a recorder that never started leaves the caller free
    // to listen live instead, while a transcription failure means the learner
    // has already spoken and must not be silently asked to do it again.
    final String audioPath;
    try {
      audioPath = await _recorder.recordUntilSilence(
        maxDuration: maxDuration,
        stopSignal: manualStop.future,
      );
    } catch (error) {
      throw _CaptureUnavailable(error);
    }
    onCaptureComplete?.call();

    if (audioPath.isEmpty) {
      await _recorder.cleanup();
      return PronunciationAssessment(
        transcribedText: '',
        result: _scorer.score(
          expectedText: expectedText,
          actualTranscription: '',
        ),
        usedWhisper: true,
        diagnostic: 'cloud Whisper (no audio captured)',
      );
    }

    // Deliberately NOT passing `prompt: expectedText`. Whisper's prompt
    // conditions the decoder, so handing it the target sentence makes it
    // reproduce that sentence almost regardless of what was actually said —
    // gibberish came back transcribed as the expected phrase and scored ~95%.
    // For assessment the recogniser must never be told the answer.
    final WhisperResult whisperResult;
    try {
      whisperResult = await _whisper!.transcribe(
        audioPath: audioPath,
        language: 'cs',
      );
    } on SpeechServiceException {
      rethrow;
    } catch (error) {
      // Anything the transcriber did not already describe — a socket dropping,
      // a malformed payload — still means captured audio that cannot be
      // scored, so it takes the same path rather than becoming a fake score.
      _log.warning('Cloud transcription failed', error);
      throw const SpeechServiceException(
        'That recording could not be checked. Try again in a moment.',
      );
    }

    final result = _scorer.score(
      expectedText: expectedText,
      actualTranscription: whisperResult.text,
    );
    var enriched = _enrichWithConfidence(result, whisperResult.words);

    // Prefer sound-level scoring where it has been measured to be trustworthy.
    final phoneme = await _tryPhonemeScore(expectedText, audioPath);
    if (phoneme != null) {
      enriched = phoneme;
    }

    _log.info(
      'Whisper assessment: ${result.overallScore.toStringAsFixed(2)} '
      '(${whisperResult.words.length} words, '
      '${whisperResult.duration.toStringAsFixed(1)}s audio)',
    );

    await _recorder.cleanup();

    return PronunciationAssessment(
      transcribedText: whisperResult.text,
      result: enriched,
      whisperWords: whisperResult.words,
      usedWhisper: true,
      diagnostic:
          'cloud Whisper (${whisperResult.duration.toStringAsFixed(1)}s)',
    );
  }

  Future<PronunciationAssessment> _assessWithNativeStt(
    String expectedText,
    Duration maxDuration, {
    String? diagnostic,
  }) async {
    _log.info('Whisper unavailable; falling back to OS-native STT.');

    // Refuse rather than guess. With no Czech language pack the platform
    // listens in the phone's default language and returns an English-shaped
    // transcription of Czech speech, which the scorer reads as a bad
    // pronunciation. Being told you got it wrong when you got it right is
    // worse than being told it could not be checked — the same reasoning the
    // Whisper path already applies to audio it captured but could not score.
    if (!await _fallbackStt.supportsCzech()) {
      _log.warning('No Czech recogniser on this device; refusing to score.');
      throw const SpeechServiceException(
        'Your phone does not have Czech speech recognition installed, so this '
        'cannot be checked here. Add Czech in your phone\'s speech or keyboard '
        'language settings, or turn on cloud pronunciation in Settings.',
      );
    }

    final transcription = await _fallbackStt.listenFor(timeout: maxDuration);

    final result = _scorer.score(
      expectedText: expectedText,
      actualTranscription: transcription,
    );

    return PronunciationAssessment(
      transcribedText: transcription,
      result: result,
      usedWhisper: false,
      diagnostic: diagnostic ?? 'on-device',
    );
  }

  /// Enrich word scores with Whisper's per-word probability.
  /// Score the recording by comparing sounds rather than words.
  ///
  /// Returns null — meaning "use the transcript score" — whenever anything is
  /// missing or unproven: no recogniser configured, the service unreachable,
  /// or a phrase outside the measured-reliable set. Silence beats a verdict the
  /// learner cannot trust, and being wrongly told you mispronounced something
  /// is far more damaging than not being told at all.
  Future<PronunciationResult?> _tryPhonemeScore(
    String expectedText,
    String audioPath,
  ) async {
    final recognizer = _phonemeRecognizer;
    final coverage = _coverage;
    if (recognizer == null || !recognizer.isConfigured || coverage == null) {
      return null;
    }
    if (!coverage.supports(expectedText)) {
      _log.info(
        'Phoneme scoring skipped — "$expectedText" is not in the '
        'measured-reliable set.',
      );
      return null;
    }

    final heard = await recognizer.recognize(audioPath);
    if (heard == null) return null;

    // Czech orthography is close to phonemic, so the character transcript maps
    // straight to IPA and the existing Czech weights apply unchanged.
    final assessment = _phonemeScorer.score(
      expectedIpa: _phonemeMapper.toIpa(expectedText),
      actualIpa: _phonemeMapper.toIpa(heard),
    );

    _log.info(
      'Phoneme score ${assessment.overallScore.toStringAsFixed(2)} '
      '(${assessment.band.name}) heard "$heard"',
    );

    return PronunciationResult(
      overallScore: assessment.overallScore,
      // Per-word detail belongs to the transcript scorer; this path reports at
      // sound level, and the feedback strings carry the specifics.
      wordScores: const [],
      problemSounds: const [],
      feedback: assessment.displayFeedback.join('\n'),
    );
  }

  PronunciationResult _enrichWithConfidence(
    PronunciationResult base,
    List<WhisperWord> whisperWords,
  ) {
    if (whisperWords.isEmpty || base.wordScores.isEmpty) {
      return base;
    }

    // Build a map of normalized word → *average* probability from Whisper.
    // This used to sum, so a word Whisper emitted twice contributed >1.0 and
    // the blend below could push a score above 100%.
    //
    // Both sides of this map go through [TextNormalizer] so the keys actually
    // meet. They used to be built differently: Whisper's words were stripped
    // with `[^\w]`, and Dart's `\w` is ASCII-only, so every diacritic was
    // deleted ("říká" became "k") while the lookup key kept them. For Czech —
    // where most words carry one — the blend below therefore never applied,
    // and confidence was silently discarded on exactly the words that need it.
    final probSums = <String, double>{};
    final probCounts = <String, int>{};
    for (final w in whisperWords) {
      final normalized = TextNormalizer.normalize(w.word);
      if (normalized.isNotEmpty) {
        probSums[normalized] = (probSums[normalized] ?? 0) + w.probability;
        probCounts[normalized] = (probCounts[normalized] ?? 0) + 1;
      }
    }
    final wordConfidence = <String, double>{
      for (final entry in probSums.entries)
        entry.key: (entry.value / probCounts[entry.key]!).clamp(0.0, 1.0),
    };

    // The existing scorer already computed word scores from text comparison.
    // Whisper's probability gives us an additional signal: even if the text
    // matches, a low Whisper probability means the model wasn't sure about
    // the pronunciation quality.
    //
    // We blend: finalScore = 0.6 * textSimilarity + 0.4 * whisperConfidence
    // When Whisper confidence is unavailable for a word, we use textSimilarity
    // alone (no penalty).
    final enrichedWordScores =
        base.wordScores.map((ws) {
          final normalized = TextNormalizer.normalize(ws.word);
          final whisperProb = wordConfidence[normalized];
          if (whisperProb == null) {
            return ws; // No Whisper data for this word — keep text-based score
          }
          final blended = (ws.score * 0.6) + (whisperProb * 0.4);
          return WordScore(
            word: ws.word,
            isCorrect: blended >= 0.7,
            score: blended,
          );
        }).toList();

    // Recalculate overall score. The denominator must keep counting the words
    // the learner added on top of the target phrase, exactly as the scorer
    // does — otherwise reciting the phrase plus a stream of filler scores the
    // same as saying it cleanly.
    final totalScore = enrichedWordScores.fold<double>(
      0.0,
      (sum, w) => sum + w.score,
    );
    final denominator = enrichedWordScores.length + base.insertionCount;
    final accuracy = denominator == 0 ? 0.0 : totalScore / denominator;

    return PronunciationResult(
      overallScore: accuracy.clamp(0.0, 1.0),
      wordScores: enrichedWordScores,
      problemSounds: base.problemSounds,
      feedback: base.feedback,
      insertionCount: base.insertionCount,
    );
  }

  /// Manually stop an active recording. For the Whisper path this signals the
  /// in-flight [recordUntilSilence] to finish capturing so the audio is still
  /// transcribed (never discarded); for the native path it stops listening.
  Future<void> stop() async {
    final manualStop = _manualStop;
    if (manualStop != null && !manualStop.isCompleted) {
      manualStop.complete();
    }
    await _fallbackStt.stop();
  }
}

/// Internal marker: the recorder never produced audio, so no speech was
/// captured and the caller may still fall back to listening live.
class _CaptureUnavailable implements Exception {
  const _CaptureUnavailable(this.cause);
  final Object cause;

  @override
  String toString() => 'Recording could not start: $cause';
}

/// STT provider using the speech_to_text package (on-device, OS-native).
///
/// Used as a fallback when Whisper is unavailable (offline, backend not
/// configured). For Czech, this uses the OS's built-in speech recognition
/// (Google on Android, Apple on iOS/macOS).
final sttServiceProvider = Provider<SttService>((ref) {
  return NativeSttService();
});

/// Native on-device STT implementation using speech_to_text package.
class NativeSttService implements SttService, LiveTranscriber {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  String? _czechLocaleId;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = await _speech.initialize(
      onError: (error) {
        // Log error but don't crash
      },
      onStatus: (status) {
        // Listening state changes
      },
    );
    if (_initialized) {
      // Resolve the device's Czech locale id once. The exact id varies by
      // platform (cs_CZ, cs-CZ, cs); pick whatever the OS actually offers so
      // listen() doesn't silently no-op on an unknown locale.
      try {
        final locales = await _speech.locales();
        final cs =
            locales
                .where((l) => l.localeId.toLowerCase().startsWith('cs'))
                .toList();
        _czechLocaleId = cs.isNotEmpty ? cs.first.localeId : null;
      } catch (_) {
        _czechLocaleId = null;
      }
    }
  }

  @override
  Future<String> transcribe(String audioPath) async {
    await _ensureInitialized();
    if (!_initialized) return '';

    // speech_to_text works via live listening, not file transcription.
    // For file-based transcription, the on-device ONNX model would be needed.
    // For now, this returns empty — the pronunciation provider
    // uses listenFor() which captures live speech.
    return '';
  }

  @override
  Stream<PartialTranscript> transcribeStream(String audioPath) async* {
    // Not used for live recognition — see listenFor() in the provider
    yield const PartialTranscript(text: '', isFinal: true);
  }

  @override
  Future<bool> isAvailable() async {
    await _ensureInitialized();
    return _initialized;
  }

  @override
  Future<bool> supportsCzech() async {
    await _ensureInitialized();
    return _initialized && _czechLocaleId != null;
  }

  /// Start live listening and return the recognized text.
  /// This is the primary method used for pronunciation practice.
  @override
  Future<String> listenFor({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _ensureInitialized();
    if (!_initialized) return '';

    final completer = Completer<String>();
    String result = '';

    await _speech.listen(
      onResult: (recognition) {
        // Keep the latest transcription — partial OR final. Czech recognition
        // (and short utterances) often never emit a final result, so relying
        // only on finalResult loses everything the user said.
        if (recognition.recognizedWords.isNotEmpty) {
          result = recognition.recognizedWords;
        }
        if (recognition.finalResult && !completer.isCompleted) {
          completer.complete(result);
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: timeout,
        // Use the resolved Czech locale when available; otherwise fall back to
        // the device default rather than a possibly-unknown 'cs_CZ'.
        localeId: _czechLocaleId,
        listenMode: ListenMode.dictation,
      ),
    );

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _speech.stop();
        return result;
      },
    );
  }

  /// Stop listening.
  @override
  Future<void> stop() async {
    await _speech.stop();
  }
}
