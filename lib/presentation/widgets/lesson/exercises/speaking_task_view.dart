import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../providers/stt_providers.dart';
import '../../common/lesson_ui.dart';
import '../../common/record_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'exercise_shared.dart';

/// Speaking task exercise — record yourself speaking Czech in response to
/// a prompt. The recording is transcribed and compared to expected phrases.
class SpeakingTaskView extends ConsumerStatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const SpeakingTaskView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  ConsumerState<SpeakingTaskView> createState() => _SpeakingTaskViewState();
}

class _SpeakingTaskViewState extends ConsumerState<SpeakingTaskView> {
  bool isRecording = false;
  bool hasRecorded = false;
  String? transcription;
  String? feedback;

  /// Guards against the stale [Future.delayed] callback when the user
  /// taps re-record during the 2-second auto-submit delay.
  bool _autoSubmitPending = false;

  /// Cancellation flag — when true, the current recognition session is
  /// abandoned (stopped) and its results should be discarded.
  bool _sessionCancelled = false;

  String get _prompt {
    return (widget.exercise.data['prompt_en'] ?? widget.exercise.prompt)
        as String;
  }

  String? get _promptCz => widget.exercise.data['prompt_cz'] as String?;

  List<String> get _expectedPhrases {
    final raw = widget.exercise.data['expected_phrases'];
    if (raw is List) return raw.cast<String>();
    if (widget.exercise.answerKey != null) return [widget.exercise.answerKey!];
    return [];
  }

  Future<void> _toggleRecording() async {
    // If recording, stop and process the result.
    if (isRecording) {
      final stt = ref.read(sttServiceProvider) as NativeSttService;
      await stt.stop();
      // listenFor()'s completer will resolve on stop — the awaiting code
      // below continues normally.
      return;
    }

    // If a previous result is showing and we're not in the auto-submit
    // delay, this is a re-record. Cancel any pending auto-submit first.
    if (_autoSubmitPending) {
      _autoSubmitPending = false;
    }

    // Start a fresh session.
    _sessionCancelled = false;
    setState(() {
      isRecording = true;
      hasRecorded = false;
      transcription = null;
      feedback = null;
    });

    try {
      final stt = ref.read(sttServiceProvider) as NativeSttService;
      final recorded =
          (await stt.listenFor(timeout: const Duration(seconds: 15))).trim();

      // If the user cancelled (re-recorded or stopped without processing),
      // discard the result entirely.
      if (_sessionCancelled) return;

      var score = 0.0;

      // Compare against expected phrases
      for (final phrase in _expectedPhrases) {
        if (matchAnswer([phrase], recorded) != AnswerMatch.none) {
          score = 1.0;
          break;
        }
      }

      // Partial match: check if transcription contains key words
      if (score < 1.0 && recorded.isNotEmpty) {
        final words = recorded.toLowerCase().split(RegExp(r'\s+'));
        final expectedWords =
            _expectedPhrases
                .expand((p) => p.toLowerCase().split(RegExp(r'\s+')))
                .toSet();
        final matched = words.where((w) => expectedWords.contains(w)).length;
        if (expectedWords.isNotEmpty) {
          score = matched / expectedWords.length;
        }
        if (score > 1.0) score = 1.0;
      }

      // The widget can be gone by the time the recogniser returns, and reading
      // localisations off a dead context is what the async-gap lint is warning
      // about.
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final currentFeedback =
          score >= 0.5
              ? l10n.speakingFeedbackGood
              : l10n.speakingFeedbackRetry(_expectedPhrases.join(', '));

      setState(() {
        hasRecorded = true;
        isRecording = false;
        transcription = recorded;
        feedback = currentFeedback;
      });

      // Auto-submit after a short delay so the user can see their result.
      // Guard with a flag so a re-record tap cancels this stale callback.
      _autoSubmitPending = true;
      Future.delayed(const Duration(seconds: 2), () {
        if (!_autoSubmitPending || !mounted) return;
        _autoSubmitPending = false;
        widget.onAnswered(
          ExerciseResult(
            isCorrect: score >= 0.5,
            explanation: currentFeedback,
            correctAnswer: _expectedPhrases.join('; '),
          ),
        );
      });
    } catch (e) {
      if (_sessionCancelled) return;
      setState(() {
        isRecording = false;
        feedback = AppLocalizations.of(context).recordingFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: _prompt, czech: _promptCz),
          const SizedBox(height: 16),

          // What to aim for, stated before they speak.
          if (_expectedPhrases.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(24),
                boxShadow: t.shadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LessonKicker(l10n.speakingTryToSay),
                  const SizedBox(height: 10),
                  for (final (i, p) in _expectedPhrases.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.record_voice_over_outlined,
                            size: 16,
                            color: t.pri,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          Center(
            child: Column(
              children: [
                RecordButton(
                  isRecording: isRecording,
                  onPressed: _toggleRecording,
                ),
                Text(
                  isRecording
                      ? l10n.speakingRecordingTapToStop
                      : hasRecorded
                      ? l10n.speakingTapToRerecord
                      : l10n.speakingTapToSpeak,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isRecording ? t.redInk : t.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // What was heard, then what to make of it.
          if (transcription != null && transcription!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.elev,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LessonKicker(l10n.speakingYouSaid),
                  const SizedBox(height: 6),
                  Text(
                    transcription!,
                    style: TextStyle(fontSize: 16, height: 1.45, color: t.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (feedback != null)
            Text(
              feedback!,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w600,
                // Amber means streak and XP, never a verdict — a speaking
                // result that is not clearly good is neutral, not a warning.
                color: feedback!.contains('Good') ? t.greenInk : t.ink,
              ),
            ),
        ],
      ),
    );
  }
}
