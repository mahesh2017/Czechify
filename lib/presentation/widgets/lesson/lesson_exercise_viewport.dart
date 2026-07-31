import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/answer_streak.dart';
import '../../../core/feedback/sfx.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/exercise_outcome.dart';
import '../../providers/feedback_providers.dart';
import '../celebration/burst_painter.dart';
import 'exercise_widget.dart';

/// Composes an exercise inside the lesson player's available viewport, and
/// reacts when it is answered.
///
/// The reaction lives here rather than in each exercise view because there are
/// seventeen of those, and a reward the learner meets ~790 times over the
/// course must not depend on seventeen separate implementations staying in
/// step with each other.
///
/// Most exercises are intrinsically sized and rely on the lesson player for
/// scrolling. A smaller set owns an internal scrollable or an expanding input
/// area; those exercises must receive bounded height or their root [Expanded]
/// widgets fail under a [SingleChildScrollView].
class LessonExerciseViewport extends ConsumerStatefulWidget {
  const LessonExerciseViewport({
    super.key,
    required this.exercise,
    required this.onAnswered,
    this.answerStreak = 0,
  });

  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  /// Correct answers in a row *before* this one, so the reward can escalate.
  final int answerStreak;

  /// Exercise views that manage their own vertical space and scrolling.
  static bool usesBoundedHeight(ExerciseType type) => switch (type) {
    ExerciseType.matching ||
    ExerciseType.errorCorrection ||
    ExerciseType.readingComprehension ||
    ExerciseType.listeningComprehension ||
    ExerciseType.writingTask => true,
    _ => false,
  };

  @override
  ConsumerState<LessonExerciseViewport> createState() =>
      _LessonExerciseViewportState();
}

class _LessonExerciseViewportState extends ConsumerState<LessonExerciseViewport>
    with TickerProviderStateMixin {
  // Built in initState, not lazily: a `late final` controller that was never
  // touched gets *created* by dispose(), which asks a deactivated element for
  // its TickerMode and throws on the way out.
  late final AnimationController _reaction;
  late final AnimationController _combo;

  ExerciseOutcome? _outcome;
  int _comboStreak = 0;

  @override
  void initState() {
    super.initState();
    _reaction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _combo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
  }

  @override
  void dispose() {
    _reaction.dispose();
    _combo.dispose();
    super.dispose();
  }

  bool get _wasCorrect => _outcome == ExerciseOutcome.correct;

  void _handleAnswered(ExerciseResult result) {
    // Teaching cards are presentations, not questions. Congratulating someone
    // for reading a card would devalue the sound that means "you got it right".
    if (widget.exercise.type != ExerciseType.teaching) {
      _react(result.outcome);
    }
    // Always last: this drives the lesson forward, and feedback must already
    // have fired so nothing is waiting on a database write to be heard.
    widget.onAnswered(result);
  }

  void _react(ExerciseOutcome outcome) {
    final feedback = ref.read(feedbackServiceProvider);

    if (outcome == ExerciseOutcome.skipped) {
      // Skipping is not a verdict, so it gets acknowledgement and no judgement.
      feedback.haptic(Haptic.light);
      return;
    }

    final correct = outcome == ExerciseOutcome.correct;
    final streak = correct ? widget.answerStreak + 1 : 0;
    final isMilestone = correct && AnswerStreak.isMilestone(streak);

    if (correct) {
      // A milestone replaces the note rather than stacking on top of it —
      // two clips firing together mix into mud instead of reading as bigger.
      feedback.play(
        isMilestone ? Sfx.combo : Sfx.correctForStreak(streak),
        haptic: isMilestone ? Haptic.medium : Haptic.light,
      );
    } else {
      feedback.play(Sfx.wrong, haptic: Haptic.medium);
    }

    setState(() => _outcome = outcome);
    _reaction.forward(from: 0);
    if (isMilestone) {
      _comboStreak = streak;
      _combo.forward(from: 0);
    }
  }

  /// Horizontal shake for a wrong answer — decaying oscillations, big enough
  /// to feel like a "no" without becoming a punishment.
  double get _shake {
    if (_outcome != ExerciseOutcome.incorrect) return 0;
    final t = _reaction.value;
    if (t >= 0.40) return 0;
    final progress = t / 0.40;
    return math.sin(progress * math.pi * 4) * 15 * (1 - progress);
  }

  /// A wash of colour across the whole exercise. Strong enough to be the
  /// thing you notice, gone before it can get in the way of reading.
  double get _tintOpacity {
    final t = _reaction.value;
    if (t >= 0.62) return 0;
    return (t < 0.10 ? t / 0.10 : 1 - (t - 0.10) / 0.52).clamp(0.0, 1.0) * 0.30;
  }

  /// The correct-answer glyph gets a hard pop and hangs on. The scale runs
  /// past 1 and settles, which is what makes it land rather than fade in.
  double get _glyphScale {
    final t = Curves.elasticOut.transform(
      (_reaction.value / 0.5).clamp(0.0, 1.0),
    );
    return 0.3 + 0.85 * t;
  }

  double get _glyphOpacity {
    final t = _reaction.value;
    if (t < 0.08) return t / 0.08;
    if (t < 0.62) return 1;
    return (1 - (t - 0.62) / 0.38).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final exerciseWidget = ExerciseWidget(
      key: ValueKey(widget.exercise.id),
      exercise: widget.exercise,
      onAnswered: _handleAnswered,
    );

    final composed =
        LessonExerciseViewport.usesBoundedHeight(widget.exercise.type)
            ? SizedBox.expand(child: exerciseWidget)
            : SingleChildScrollView(child: exerciseWidget);

    // Someone who has asked the OS to reduce motion still gets the sound, the
    // haptic and the colour change — they asked for less movement, not for a
    // less rewarding app.
    if (MediaQuery.disableAnimationsOf(context)) return composed;

    final tokens = context.tokens;
    final accent = _wasCorrect ? tokens.green : tokens.red;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _reaction,
          builder:
              (context, child) =>
                  Transform.translate(offset: Offset(_shake, 0), child: child),
          child: composed,
        ),
        if (_outcome != null && _outcome != ExerciseOutcome.skipped)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _reaction,
                builder: (context, _) {
                  // Stop painting a full-screen layer once it has faded out;
                  // otherwise every answered exercise leaves an invisible one
                  // behind for as long as it stays on screen.
                  if (_reaction.isCompleted) return const SizedBox.shrink();
                  return DecoratedBox(
                    // Brightest at the point of impact and falling away to
                    // the edges, so the eye is pulled to the middle rather
                    // than the whole panel just changing colour.
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [
                          accent.withValues(alpha: _tintOpacity),
                          accent.withValues(alpha: _tintOpacity * 0.25),
                        ],
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_wasCorrect)
                          CustomPaint(
                            size: Size.infinite,
                            painter: RadialBurstPainter(
                              progress: _reaction.value,
                              colors: [tokens.green, tokens.amber, tokens.pri],
                            ),
                          ),
                        _glyph(accent),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(child: _comboChip(tokens)),
        ),
      ],
    );
  }

  Widget _glyph(Color accent) {
    return Opacity(
      opacity: _glyphOpacity,
      child: Transform.scale(
        scale: _glyphScale,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.55),
                blurRadius: 40,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Icon(
            _wasCorrect ? Icons.check_rounded : Icons.close_rounded,
            size: 84,
            color: context.tokens.onFill,
          ),
        ),
      ),
    );
  }

  Widget _comboChip(AppTokens tokens) {
    return AnimatedBuilder(
      animation: _combo,
      builder: (context, child) {
        if (_combo.isDismissed) return const SizedBox.shrink();
        final t = _combo.value;
        final entry = Curves.easeOutBack.transform((t / 0.16).clamp(0.0, 1.0));
        final exit = ((t - 0.84) / 0.16).clamp(0.0, 1.0);
        return Opacity(
          opacity: (1 - exit) * entry.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -34 * (1 - entry)),
            child: child,
          ),
        );
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: tokens.amberSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.amber.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: tokens.amber,
              ),
              const SizedBox(width: 6),
              Text(
                AnswerStreak.label(_comboStreak),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: tokens.amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
