import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../common/pronunciation_tip_text.dart';
import '../../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/score_colors.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../providers/pronunciation_providers.dart';
import '../../../providers/tts_providers.dart';
import '../../common/cloud_speech_consent.dart';
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

/// Pass mark when the exercise does not set its own `min_score`.
const double _kDefaultMinScore = 0.65;

class _PronunciationViewState extends ConsumerState<PronunciationView> {
  double? score;
  String? feedback;
  bool hasRecorded = false;

  /// Attempts below the pass mark on this exercise.
  ///
  /// Drives escalation rather than a counter shown to the learner: repeating
  /// the same screen at someone who has now failed three times is the app
  /// declining to help. Each attempt changes what it offers — a slower model
  /// to copy, then the sounds they are missing, then a way out that guarantees
  /// the word comes back.
  int _failedAttempts = 0;

  /// Set after a second miss so the next "Hear it" plays slowly without the
  /// learner having to discover the speed control mid-struggle.
  bool _offerSlowModel = false;

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
      _failedAttempts = 0;
      _offerSlowModel = false;
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
    final minScore =
        (data['min_score'] as num?)?.toDouble() ?? _kDefaultMinScore;
    final passed = (score ?? 0) >= minScore;

    widget.onAnswered(
      ExerciseResult(
        isCorrect: passed,
        explanation:
            data['note'] as String? ??
            (passed
                ? AppLocalizations.of(context).pronFeedbackGood
                : AppLocalizations.of(context).pronFeedbackRetry),
        correctAnswer: data['target_text'] as String?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
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
      feedback = localizedTips(result.tips, AppLocalizations.of(context));
      hasRecorded = true;

      // Counted here because this is the one place an attempt is adopted, and
      // it is guarded by `score == null` so it runs once per attempt.
      final threshold =
          (data['min_score'] as num?)?.toDouble() ?? _kDefaultMinScore;
      if (result.overallScore < threshold) {
        _failedAttempts++;
        if (_failedAttempts >= 2) _offerSlowModel = true;
      }
    }

    // Scoped to this view's attempt for the same reason the result is: the
    // provider outlives the widget and still holds the previous exercise's
    // outcome on the first build after navigation.
    final attemptFailed =
        pronState.error != null &&
        _awaitingAttemptId != null &&
        pronState.attemptId == _awaitingAttemptId;

    final minScore =
        (data['min_score'] as num?)?.toDouble() ?? _kDefaultMinScore;
    final passed = (score ?? 0) >= minScore;
    final showResult =
        hasRecorded && score != null && !isRecording && !isProcessing;

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
                  onPlay: () {
                    final tts = ref.read(czechTtsProvider);
                    // After a second miss the model plays slowly by default.
                    // Someone who cannot hear the difference is unlikely to go
                    // looking for a speed control mid-struggle, and this is
                    // exactly when a slower model is worth copying.
                    if (_offerSlowModel) {
                      tts.speakSlow(targetText);
                    } else {
                      tts.speak(targetText);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Recording and its result occupy the same space rather than
          // stacking. Appending the score pushed the Continue button below the
          // fold, so finishing an attempt meant scrolling to do anything with
          // it — and the thing you most want to see after a poor score, the
          // word itself, was the thing scrolled away.
          if (showResult)
            _ResultBlock(
              score: score!,
              passed: passed,
              feedback: feedback,
              failedAttempts: _failedAttempts,
              onRetry: _toggleRecording,
              onContinue: _submitResult,
              onMoveOn: _submitResult,
            )
          else
            Column(
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
                const SizedBox(height: 8),
                Text(
                  isRecording
                      ? l10n.pronListeningTapToStop
                      : isProcessing
                      ? l10n.pronAnalysing
                      : l10n.pronTapToRecord,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isRecording ? t.redInk : t.muted,
                  ),
                ),
                // A recording that could not be checked says so. Without this
                // the exercise showed nothing at all on failure — the spinner
                // simply stopped — and the learner had no way to tell a
                // service outage from having said the phrase wrong.
                if (attemptFailed) ...[
                  const SizedBox(height: 10),
                  Text(
                    pronState.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: t.redInk,
                    ),
                  ),
                  // When there is a switch that fixes it, offer the switch.
                  // Telling a learner mid-exercise to go and add a language
                  // pack in their phone's system settings is a dead end: they
                  // came here to practise, not to administer their device.
                  if (pronState.errorCloudSpeechWouldFix) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        final granted = await requestCloudSpeechConsent(
                          context,
                          ref,
                        );
                        if (granted && mounted) await _toggleRecording();
                      },
                      icon: const Icon(Icons.cloud_outlined, size: 18),
                      label: const Text('Check it in the cloud instead'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sends this recording for transcription. You can turn '
                      'it off again in Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: t.muted,
                      ),
                    ),
                  ],
                ],
              ],
            ),

          // Escape hatch: pronunciation should never hard-block progress.
          // Below the actions now — it used to sit between the microphone and
          // the score, so the order read skip-then-result.
          if (!isProcessing && !showResult)
            TextButton(
              onPressed:
                  () => widget.onAnswered(
                    ExerciseResult.skipped(
                      explanation: l10n.pronSkippedNote,
                      correctAnswer: targetText,
                    ),
                  ),
              style: TextButton.styleFrom(
                foregroundColor: t.muted,
                minimumSize: const Size(0, 44),
              ),
              child: Text(
                hasRecorded && (score ?? 0) == 0
                    ? l10n.pronMicNotWorkingSkip
                    : l10n.pronCantRecordSkip,
              ),
            ),
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
          caption: AppLocalizations.of(context).captionMatch,
          color: color,
          showBadge: score >= 0.8,
          size: 104,
          animateOnMount: true,
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

/// The result of an attempt, in the space the microphone occupied.
///
/// Everything a learner needs after speaking is here — how they did, what to
/// do about it, and a way onward — so the word and its "Hear it" button stay
/// on screen above rather than being scrolled away at the moment they become
/// useful.
class _ResultBlock extends StatelessWidget {
  const _ResultBlock({
    required this.score,
    required this.passed,
    required this.feedback,
    required this.failedAttempts,
    required this.onRetry,
    required this.onContinue,
    required this.onMoveOn,
  });

  final double score;
  final bool passed;
  final String? feedback;

  /// Misses on this exercise so far, which decides how much help is offered.
  final int failedAttempts;

  final VoidCallback onRetry;
  final VoidCallback onContinue;

  /// Submits the attempt as it stands. Distinct from [onContinue] only in what
  /// the button says: after three misses "Continue" would be claiming a pass
  /// that did not happen.
  final VoidCallback onMoveOn;

  /// What to say after a miss, escalating rather than repeating.
  ///
  /// Saying "not quite, try again" a third time is the app declining to help.
  String? _coaching() {
    if (passed) return null;
    return switch (failedAttempts) {
      0 || 1 => 'Not quite. Listen once more, then try again.',
      2 =>
        'Still not matching. Play it again — it will come out slower now — and '
            'copy the highlighted sounds.',
      _ =>
        'This one is hard to hear. Move on and we will bring it back later in '
            'the lesson, when it will be easier to hear the difference.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final coaching = _coaching();
    final exhausted = !passed && failedAttempts >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: ScoreDisplay(score: score)),
        if (feedback != null) ...[
          const SizedBox(height: 8),
          Text(
            feedback!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.45, color: t.ink),
          ),
        ],
        if (coaching != null) ...[
          const SizedBox(height: 8),
          Text(
            coaching,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: t.muted),
          ),
        ],
        const SizedBox(height: 16),
        if (passed)
          KeyCta(label: l10n.continueLabel, onPressed: onContinue)
        else if (exhausted) ...[
          // Submitted as it stands, which is a miss — so the lesson's own
          // mistake queue re-asks it and the evidence row records a speaking
          // miss. "Bring it back" is a promise the app already keeps.
          KeyCta(label: 'Move on for now', onPressed: onMoveOn),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: t.muted,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Try once more'),
          ),
        ] else ...[
          KeyCta(label: 'Try again', onPressed: onRetry),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onContinue,
            style: TextButton.styleFrom(
              foregroundColor: t.muted,
              minimumSize: const Size(0, 44),
            ),
            child: Text(l10n.continueLabel),
          ),
        ],
      ],
    );
  }
}
