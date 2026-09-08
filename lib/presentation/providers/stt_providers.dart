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
///
/// **Not a shipped feature, deliberately.** `env/prod.json` sets no value, so
/// release builds leave this empty and `pronunciationAssessmentProvider`
/// constructs no recogniser at all. The plan is to revisit phoneme scoring
/// with a cloud model trained for Czech audio; the local service under
/// `services/phoneme-recognizer/` is a prototype kept for that work.
///
/// Three findings from the September 2026 audit are dormant only because this
/// is empty, and must be addressed **before** any build sets it:
///
/// * Docker Compose publishes port 8080 on all interfaces and defaults
///   `API_TOKEN` to empty, and the server then skips authentication. A shared
///   token would also travel inside every client binary, so it cannot be a
///   durable secret or a per-user authorisation boundary — the recogniser
///   belongs behind the authenticated server proxy with per-user quotas.
/// * The upload endpoint reads the whole file and decodes it before checking
///   the 20-second limit, so large or highly compressed audio can exhaust the
///   container's memory before rejection.
/// * Cloud-speech consent names OpenAI as the recipient. Sending recordings to
///   a phoneme host as well is outside the wording the learner agreed to, and
///   the notice would need re-versioning first — see [ConsentRepository],
///   which now refuses a grant made against superseded wording.
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
    // The plugin is a singleton. Sharing its wrapper keeps pronunciation,
    // lessons and dictation on the same active error handler.
    fallbackStt: ref.watch(liveTranscriberProvider),
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
        'Your phone cannot recognise Czech speech, so this cannot be checked '
        'on the device.',
        cloudSpeechWouldFix: true,
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
      // sound level, and the tips carry the specifics.
      wordScores: const [],
      problemSounds: const [],
      tips: assessment.displayTips,
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
      tips: base.tips,
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
final sttServiceProvider = Provider<SttService>(
  (ref) => ref.watch(_nativeSttProvider),
);

/// The same recogniser, typed as the port the recording UI actually needs.
///
/// [SttService] describes transcribing a file; holding the microphone open and
/// letting go of it is [LiveTranscriber]. Every screen that records was
/// reaching the second through `ref.read(sttServiceProvider) as
/// NativeSttService`, which is also where the lifecycle bugs collected — a
/// cast to the implementation invites reaching past the port for whatever else
/// it happens to expose.
final liveTranscriberProvider = Provider<LiveTranscriber>(
  (ref) => ref.watch(_nativeSttProvider),
);

/// One recogniser behind both ports. Two instances would mean two
/// [SpeechToText] objects contending for one microphone.
final _nativeSttProvider = Provider<NativeSttService>(
  (ref) => NativeSttService(),
);

/// Native on-device STT implementation using speech_to_text package.
class NativeSttService implements SttService, LiveTranscriber {
  NativeSttService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  void Function(String)? _onRecordingError;
  bool _initialized = false;
  String? _czechLocaleId;

  /// Why the recogniser last refused to start, when it did.
  ///
  /// `initialize()` reports only true or false; the reason arrives separately
  /// through the error callback, so it has to be caught on the way past or it
  /// is gone. Without it, "you have not granted the microphone" and "this
  /// phone has no recogniser" are the same false, and the learner is told the
  /// wrong one.
  String? _startupFailure;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _startupFailure = null;
    _initialized = await _speech.initialize(
      onError: (error) {
        if (!_initialized) {
          _startupFailure = error.errorMsg;
        } else {
          _onRecordingError?.call(error.errorMsg);
        }
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
    bool requireCzech = true,
  }) async {
    await _ensureInitialized();

    // A recogniser that never started has heard nothing, and "" is not that.
    //
    // This returned an empty string, which every caller then treated as a
    // real transcript of silence: the lesson speaking task scored it against
    // the expected phrase and marked the learner wrong, and the exam recorded
    // a zero. Denying the microphone became a failed answer on their record.
    // The Czech-locale refusal below was added for exactly this reason and
    // sits *after* this line, so it never covered the commoner case.
    //
    // Thrown for every caller, including the ones that pass
    // [requireCzech] false: dictation with no recogniser is not a rough
    // transcription worth having, it is nothing at all, and the chat composer
    // already says so rather than silently doing nothing.
    if (!_initialized) throw _cannotStart();

    // Refuse rather than listen in the wrong language — when the result is
    // going to be scored.
    //
    // Without a Czech locale, `localeId: null` below hands the utterance to
    // the device default, and an English recogniser transcribing Czech
    // produces words the scorer reads as bad pronunciation.
    // [PronunciationAssessor] checked this before calling, but the lesson
    // speaking task and the exam call straight through, so the check belongs
    // here where nothing can route around it.
    //
    // Callers whose text the learner reads and edits before anything happens
    // to it — chat dictation — opt out. A rough transcription is better than
    // no dictation at all when nothing grades it.
    if (requireCzech && _czechLocaleId == null) {
      throw const SpeechServiceException(
        'Your phone cannot recognise Czech speech, so this cannot be checked '
        'on the device.',
        cloudSpeechWouldFix: true,
      );
    }

    if (_onRecordingError != null) {
      throw const SpeechServiceException('A recording is already in progress.');
    }
    final completer = Completer<String>();
    String result = '';
    SpeechServiceException? failure;
    _onRecordingError = (message) {
      failure =
          message.toLowerCase().contains('permission')
              ? const SpeechServiceException(
                'Czechify needs microphone permission. You can enable it in '
                'your device settings.',
              )
              : const SpeechServiceException(
                'Speech recognition stopped unexpectedly. Please try recording again.',
              );
      // Wake the awaiting call even if the platform emits no final result.
      // Store the error separately: callbacks can run before listen() returns.
      if (!completer.isCompleted) completer.complete('');
    };

    try {
      await _speech.listen(
        onResult: (recognition) {
          if (recognition.recognizedWords.isNotEmpty) {
            result = recognition.recognizedWords;
          }
          if (recognition.finalResult && !completer.isCompleted) {
            completer.complete(result);
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: timeout,
          localeId: _czechLocaleId,
          listenMode: ListenMode.dictation,
        ),
      );
      final transcript = await completer.future.timeout(
        timeout,
        onTimeout: () => result,
      );
      if (failure != null) throw failure!;
      if (transcript.trim().isEmpty) {
        throw const SpeechServiceException(
          'No speech was recognised. Please try recording again.',
          nothingHeard: true,
        );
      }
      return transcript;
    } finally {
      _onRecordingError = null;
      // Cancel clears plugin timers and prevents late partial/final events
      // from leaking into a retry. Cleanup must not replace the useful error.
      try {
        await _speech.cancel();
      } catch (_) {}
    }
  }

  /// Why the recogniser could not start, in words a learner can act on.
  ///
  /// Permission is the one cause they can fix themselves, and the one cloud
  /// speech does not work around — it needs the microphone too. Everything
  /// else means this device has no usable recogniser, which is precisely what
  /// the cloud path is for.
  SpeechServiceException _cannotStart() {
    final denied =
        _startupFailure?.toLowerCase().contains('permission') ?? false;
    return denied
        ? const SpeechServiceException(
          'Czechify needs permission to use the microphone before it can '
          'hear you. You can turn it on in your device settings.',
        )
        : const SpeechServiceException(
          'Speech recognition is not available on this phone, so this cannot '
          'be checked on the device.',
          cloudSpeechWouldFix: true,
        );
  }

  /// Stop listening.
  @override
  Future<void> stop() async {
    await _speech.stop();
  }
}
