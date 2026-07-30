import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/score_colors.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../providers/pronunciation_providers.dart';
import '../../../providers/tts_providers.dart';
import '../../common/lesson_ui.dart';
import '../../common/record_button.dart';
import '../../common/soft_ui.dart';
import 'exercise_shared.dart';

/// Pronunciation exercise view: record and get feedback.
///
/// Uses the [pronunciationAssessmentProvider] which tries Whisper first
/// (high-quality Czech transcription with word-level confidence) and falls
/// back to OS-native STT when unavailable.
class PronunciationView extends ConsumerStatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const PronunciationView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  ConsumerState<PronunciationView> createState() => _PronunciationViewState();
}

class _PronunciationViewState extends ConsumerState<PronunciationView> {
  double? score;
  String? feedback;
  bool hasRecorded = false;

  /// The attempt this view is waiting on. [pronunciationProvider] outlives the
  /// widget, so without this the first build of a new exercise reads the
  /// previous exercise's result and shows a score before the learner has
  /// spoken. Clearing the provider is not enough on its own: that happens in a
  /// microtask, one build too late.
  int? _awaitingAttemptId;

  @override
  void initState() {
    super.initState();
    _scopeTargetToExercise();
  }

  @override
  void didUpdateWidget(covariant PronunciationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id) {
      score = null;
      feedback = null;
      hasRecorded = false;
      _awaitingAttemptId = null;
      _scopeTargetToExercise();
    }
  }

  void _scopeTargetToExercise() {
    final exerciseId = widget.exercise.id;
    final targetText = widget.exercise.data['target_text'] as String;
    Future.microtask(() {
      if (!mounted || widget.exercise.id != exerciseId) return;
      ref.read(pronunciationProvider.notifier).setExpectedText(targetText);
    });
  }

  Future<void> _toggleRecording() async {
    if (ref.read(pronunciationProvider).isProcessing) return;

    final notifier = ref.read(pronunciationProvider.notifier);
    final currentState = ref.read(pronunciationProvider);

    if (currentState.isRecording) {
      await notifier.stopRecording();
      return;
    }

    // Reset state
    setState(() {
      score = null;
      feedback = null;
      hasRecorded = false;
    });

    await notifier.startRecording(
      expectedText: widget.exercise.data['target_text'] as String,
    );
    if (mounted) {
      setState(
        () => _awaitingAttemptId = ref.read(pronunciationProvider).attemptId,
      );
    }
  }

  void _submitResult() {
    final data = widget.exercise.data;
    final minScore = (data['min_score'] as num?)?.toDouble() ?? 0.65;
    final passed = (score ?? 0) >= minScore;

    widget.onAnswered(
      ExerciseResult(
        isCorrect: passed,
        explanation:
            data['note'] as String? ??
            (passed
                ? 'Good pronunciation!'
                : 'Try again — focus on the highlighted sounds.'),
        correctAnswer: data['target_text'] as String?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final data = widget.exercise.data;
    final targetText = data['target_text'] as String;
    final translation = data['translation_en'] as String?;
    final focusSounds = (data['focus_sounds'] as List<dynamic>?) ?? [];

    final pronState = ref.watch(pronunciationProvider);
    final isRecording = pronState.isRecording;
    final isProcessing = pronState.isProcessing;
    final result = pronState.result;

    // Adopt a result only when it belongs to the attempt this view started.
    // A result from the previous exercise is still sitting in the provider on
    // the first build after navigation.
    if (result != null &&
        score == null &&
        _awaitingAttemptId != null &&
        pronState.attemptId == _awaitingAttemptId) {
      score = result.overallScore;
      feedback = result.feedback;
      hasRecorded = true;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: widget.exercise.prompt),
          const SizedBox(height: 18),

          // What to say, on the hero surface — it is the whole exercise.
          TeachingHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  targetText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: t.ink,
                  ),
                ),
                if (translation != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    translation,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.4, color: t.muted),
                  ),
                ],
                if (focusSounds.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final sound in focusSounds)
                        PillChip(
                          label: sound as String,
                          bg: t.card,
                          fg: t.priInk,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                AudioPairButtons(
                  onPlay: () => ref.read(czechTtsProvider).speak(targetText),
                  onSlow:
                      () => ref.read(czechTtsProvider).speakSlow(targetText),
                  slowLabel: 'Slower',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          Center(
            child: Column(
              children: [
                if (isProcessing)
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(t.pri),
                      ),
                    ),
                  )
                else
                  RecordButton(
                    isRecording: isRecording,
                    onPressed: _toggleRecording,
                  ),
                Text(
                  isRecording
                      ? 'Listening — tap to stop'
                      : isProcessing
                      ? 'Analysing…'
                      : hasRecorded
                      ? 'Recorded — tap to try again'
                      : 'Tap to record',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isRecording ? t.redInk : t.muted,
                  ),
                ),
                if (pronState.usedWhisper && hasRecorded) ...[
                  const SizedBox(height: 6),
                  PillChip(
                    label: 'Whisper AI',
                    bg: t.greenSoft,
                    fg: t.greenInk,
                    icon: Icons.check,
                  ),
                ],
              ],
            ),
          ),

          // Escape hatch: pronunciation should never hard-block progress.
          if (!isProcessing)
            TextButton(
              onPressed:
                  () => widget.onAnswered(
                    ExerciseResult.skipped(
                      explanation:
                          'Skipped — keep practising this one aloud with '
                          'the listen button.',
                      correctAnswer: targetText,
                    ),
                  ),
              style: TextButton.styleFrom(
                foregroundColor: t.muted,
                minimumSize: const Size(0, 44),
              ),
              child: Text(
                hasRecorded && (score ?? 0) == 0
                    ? 'Mic not working? Skip'
                    : "Can't record right now? Skip",
              ),
            ),

          if (hasRecorded && score != null) ...[
            const SizedBox(height: 18),
            ScoreDisplay(score: score!),
            if (feedback != null) ...[
              const SizedBox(height: 10),
              Text(
                feedback!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.5, color: t.ink),
              ),
            ],
            const SizedBox(height: 18),
            KeyCta(
              label: AppLocalizations.of(context).continueLabel,
              onPressed: _submitResult,
            ),
          ],
        ],
      ),
    );
  }
}

/// The pronunciation score: a ring rather than a bar, matching how every other
/// accuracy figure in the app is drawn.
class ScoreDisplay extends StatelessWidget {
  final double score;

  const ScoreDisplay({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final percentage = (score * 100).round();
    final color = ScoreColors.of(context, score);

    return Column(
      children: [
        ScoreRing(
          fraction: score,
          label: '$percentage%',
          caption: 'match',
          color: color,
          showBadge: score >= 0.8,
          size: 104,
        ),
        const SizedBox(height: 10),
        Text(
          ScoreColors.label(score),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
