import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/pronunciation_result.dart';
import '../../domain/repositories/speech_ports.dart';
import 'curriculum_providers.dart';
import 'database_providers.dart';
import 'stt_providers.dart';

/// Curated starter phrases used when no curriculum vocabulary is available
/// yet (fresh install, unit with no example sentences).
const List<String> starterPronunciationPhrases = [
  'Ahoj, jak se máš?',
  'Dobrý den, těší mě.',
  'Děkuji, mám se dobře.',
  'Promiňte, nerozumím.',
  'Mluvíte anglicky?',
  'Na shledanou!',
  'Kolik to stojí?',
  'Kde je nádraží?',
  'Jmenuji se Petr.',
  'Dám si kávu, prosím.',
];

/// Practice deck for the Pronunciation Lab: Czech sentences (preferred) and
/// words drawn from the learner's current unit, with a curated fallback so
/// the lab always has material.
final pronunciationDeckProvider = FutureProvider<List<String>>((ref) async {
  final next = await ref.watch(nextLessonProvider.future);
  final unitId = next?.lesson.unitId ?? 1;

  final cards = await ref
      .read(vocabularyRepositoryProvider)
      .getCardsForUnit(unitId);

  final phrases = <String>{};
  // Example sentences first — richer practice than isolated words.
  for (final card in cards) {
    final example = card.exampleCz?.trim();
    if (example != null && example.isNotEmpty) phrases.add(example);
  }
  for (final card in cards) {
    final word = card.wordCz.trim();
    if (word.isNotEmpty) phrases.add(word);
  }

  return phrases.isEmpty
      ? starterPronunciationPhrases
      : phrases.take(30).toList();
});

/// State of a pronunciation practice session.
class PronunciationState {
  final String expectedText;
  final String? transcribedText;
  final PronunciationResult? result;
  final bool isRecording;
  final bool isProcessing;
  final String? error;

  /// True when [error] came from the speech service rather than the device —
  /// a spent allowance or an unreachable proxy. The UI uses it to avoid
  /// telling a learner to check microphone permissions that are fine.
  final bool errorIsServiceSide;

  /// True when [error] is one that enabling cloud speech would resolve, so the
  /// UI can offer that rather than describing it.
  final bool errorCloudSpeechWouldFix;

  final bool usedWhisper;
  final String? diagnostic;
  final int attemptId;

  const PronunciationState({
    required this.expectedText,
    this.transcribedText,
    this.result,
    this.isRecording = false,
    this.isProcessing = false,
    this.error,
    this.errorIsServiceSide = false,
    this.errorCloudSpeechWouldFix = false,
    this.usedWhisper = false,
    this.diagnostic,
    this.attemptId = 0,
  });

  PronunciationState copyWith({
    String? expectedText,
    String? transcribedText,
    PronunciationResult? result,
    bool? isRecording,
    bool? isProcessing,
    String? error,
    bool? errorIsServiceSide,
    bool? errorCloudSpeechWouldFix,
    bool? usedWhisper,
    String? diagnostic,
    int? attemptId,
  }) {
    return PronunciationState(
      expectedText: expectedText ?? this.expectedText,
      transcribedText: transcribedText ?? this.transcribedText,
      result: result ?? this.result,
      isRecording: isRecording ?? this.isRecording,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      // Cleared alongside [error], which is deliberately not `??`-defaulted:
      // a state with no error must not keep the previous one's provenance.
      errorIsServiceSide: errorIsServiceSide ?? false,
      // Cleared with [error] for the same reason: an offer that belongs to a
      // failure the learner has moved past would be nonsense.
      errorCloudSpeechWouldFix: errorCloudSpeechWouldFix ?? false,
      usedWhisper: usedWhisper ?? this.usedWhisper,
      diagnostic: diagnostic ?? this.diagnostic,
      attemptId: attemptId ?? this.attemptId,
    );
  }
}

/// Notifier that manages the pronunciation practice flow.
///
/// Uses the [PronunciationAssessor] which tries Whisper first (high-quality
/// transcription with word-level confidence) and falls back to OS-native
/// STT when the backend is unavailable.
class PronunciationNotifier extends Notifier<PronunciationState> {
  var _attemptSequence = 0;

  @override
  PronunciationState build() => const PronunciationState(expectedText: '');

  /// Set the expected text to practice.
  void setExpectedText(String text) {
    // Unconditional by design. This used to short-circuit when the text was
    // unchanged, which left the previous attempt's score on screen for an
    // exercise the learner had not yet spoken into — two consecutive exercises
    // can share a target. Bumping the attempt id also orphans any capture
    // still in flight, so its result is discarded rather than landing on the
    // exercise that replaced it.
    _attemptSequence++;
    state = PronunciationState(expectedText: text, attemptId: _attemptSequence);
  }

  /// Start recording and assess pronunciation.
  Future<void> startRecording({required String expectedText}) async {
    if (state.isRecording || state.isProcessing) return;

    final attemptId = ++_attemptSequence;
    state = PronunciationState(
      expectedText: expectedText,
      isRecording: true,
      attemptId: attemptId,
    );

    try {
      final assessor = ref.read(pronunciationAssessmentProvider);
      final assessment = await assessor.assess(
        expectedText: expectedText,
        // Recording ended (silence/max/manual) — switch to "analyzing" while
        // transcription runs.
        onCaptureComplete: () {
          if (ref.mounted && state.attemptId == attemptId) {
            state = state.copyWith(isRecording: false, isProcessing: true);
          }
        },
      );
      if (!ref.mounted || state.attemptId != attemptId) return;

      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        transcribedText: assessment.transcribedText,
        result: assessment.result,
        usedWhisper: assessment.usedWhisper,
        diagnostic: assessment.diagnostic,
      );
    } on SpeechServiceException catch (e) {
      // Already written for a learner to read, and it explains a real outcome
      // (allowance spent, service down) rather than a recognition failure.
      // Prefixing it would only make it sound like the microphone misheard.
      if (!ref.mounted || state.attemptId != attemptId) return;
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        error: e.message,
        errorIsServiceSide: true,
        errorCloudSpeechWouldFix: e.cloudSpeechWouldFix,
      );
    } catch (e) {
      if (!ref.mounted || state.attemptId != attemptId) return;
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        error: 'Speech recognition failed: $e',
      );
    }
  }

  /// Manually stop the current recording. This does NOT abandon the attempt:
  /// it signals the in-flight assessment to finish capturing and transcribe the
  /// audio already recorded, so the result still arrives under the same attempt
  /// id. The UI flips to "analyzing" immediately.
  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    state = state.copyWith(isRecording: false, isProcessing: true);
    await ref.read(pronunciationAssessmentProvider).stop();
  }

  /// Reset for a new attempt.
  void reset() {
    _attemptSequence++;
    state = PronunciationState(
      expectedText: state.expectedText,
      attemptId: _attemptSequence,
    );
  }
}

/// Provider for the pronunciation state.
final pronunciationProvider =
    NotifierProvider<PronunciationNotifier, PronunciationState>(
      PronunciationNotifier.new,
    );
