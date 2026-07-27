import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../widgets/common/degraded_mode_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/feedback/celebration.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/flashcard.dart';
import '../../../domain/engines/learning_loop_engine.dart';
import '../../../domain/engines/lesson_rating.dart';
import '../../providers/lesson_providers.dart';
import '../../providers/gamification_providers.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/feedback_providers.dart';
import '../../widgets/celebration/burst_painter.dart';
import '../../widgets/celebration/count_up_text.dart';
import '../../widgets/celebration/stars_reveal.dart';
import '../../widgets/lesson/exercise_widget.dart';
import '../../widgets/lesson/lesson_exercise_viewport.dart';
import '../../widgets/common/gender_pill.dart';
import '../../widgets/common/grammar_tip_card.dart';
import '../../widgets/common/soft_ui.dart';

/// Lesson player — loads exercises from DB, cycles through them one by one.
/// Shows progress bar, hearts, and feedback after each answer.
class LessonPlayerScreen extends ConsumerStatefulWidget {
  final int lessonId;

  const LessonPlayerScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  bool _loaded = false;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    // Load lesson data on first build
    Future.microtask(() async {
      final unlocked = await ref.read(
        lessonUnlockedProvider(widget.lessonId).future,
      );
      if (!unlocked) {
        if (mounted) {
          setState(() {
            _locked = true;
            _loaded = true;
          });
        }
        return;
      }
      await ref
          .read(lessonSessionProvider.notifier)
          .loadLesson(widget.lessonId);
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(lessonSessionProvider);

    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_locked) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Complete the prerequisite lessons first.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/curriculum'),
                  child: const Text('Back to curriculum'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Game over screen
    if (session.isGameOver) {
      return _GameOverScreen(
        onRetry: () {
          ref.read(lessonSessionProvider.notifier).retry();
        },
        onExit: () => context.pop(),
      );
    }

    // Lesson complete screen — show exam results or normal completion.
    if (session.isComplete) {
      if (session.isExamMode) {
        return _ExamCompleteScreen(
          session: session,
          onExit: () => context.go('/curriculum'),
        );
      }
      return _LessonCompleteScreen(
        session: session,
        onExit: () => context.go('/curriculum'),
        onRetry: () {
          ref.read(lessonSessionProvider.notifier).retry();
        },
      );
    }

    // Teach phase — present the lesson's new words before testing them.
    if (session.isTeaching) {
      return _TeachPhaseScreen(
        session: session,
        onStart: () {
          ref.read(lessonSessionProvider.notifier).startExercises();
        },
        onExit: () => context.pop(),
      );
    }

    // Active exercise
    final exercise = session.currentExercise;
    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No exercises found for this lesson.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirm(context),
        ),
        title: Row(
          children: [
            // Mode badge (exam / review)
            if (session.isExamMode)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.tokens.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'EXAM',
                  style: TextStyle(
                    color: context.tokens.onFill,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              )
            else if (session.lesson?.isReview == true)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.tokens.pri,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'REVIEW',
                  style: TextStyle(
                    color: context.tokens.onFill,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: session.progress,
                  minHeight: 8,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Exam timer or hearts
            if (session.isExamMode)
              _ExamTimer(initialSeconds: session.remainingSeconds)
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite,
                    color:
                        session.hearts > 0
                            ? context.tokens.red
                            : context.tokens.faint,
                    size: 20,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${session.hearts}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Shown only while a substitute is in use — silent otherwise.
            const DegradedModeBanner(),
            // Exercise counter
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    session.currentExercise?.type == ExerciseType.teaching
                        ? 'Introduction'
                        : session.inMistakeReview
                        ? 'Reviewing missed questions'
                        : 'Question ${session.currentIndex + 1} of ${session.totalExercises}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          session.inMistakeReview
                              ? context.tokens.amber
                              : context.tokens.muted,
                      fontWeight:
                          session.inMistakeReview ? FontWeight.bold : null,
                    ),
                  ),
                  if (session.totalXp > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: context.tokens.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '+${session.totalXp} XP',
                          style: TextStyle(
                            color: context.tokens.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // The exercise stays visible while the feedback banner is shown,
            // so the learner can study their answer at their own pace —
            // no timed auto-advance.
            Expanded(
              child: LessonExerciseViewport(
                // Key by position so widget state (selected answers) resets
                // for each exercise, including mistake re-asks of the same
                // exercise id.
                key: ValueKey(session.currentIndex),
                exercise: exercise,
                answerStreak: session.answerStreak,
                onAnswered: (result) {
                  // Teaching cards are presentations, not questions: advance
                  // straight to the next exercise with no grading banner,
                  // heart, or XP.
                  if (exercise.type == ExerciseType.teaching) {
                    ref.read(lessonSessionProvider.notifier).nextExercise();
                    return;
                  }
                  ref
                      .read(lessonSessionProvider.notifier)
                      .onExerciseAnswered(
                        outcome: result.outcome,
                        explanation: result.explanation,
                        correctAnswer: result.correctAnswer,
                        supports: result.supports,
                        xpEarned: exercise.xpReward,
                      );
                },
              ),
            ),

            // Feedback banner — appears under the answered exercise.
            if (session.showFeedback) _buildFeedbackBanner(context, session),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner(
    BuildContext context,
    LessonSessionState session,
  ) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cap the banner height so long explanations scroll instead
              // of pushing the exercise off screen.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (session.feedbackStep case final step?) ...[
                        Text(
                          _feedbackPrompt(step),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                      ],
                      GrammarTipCard(
                        isCorrect: session.lastWasCorrect,
                        isSkipped: session.lastWasSkipped,
                        explanation: session.lastExplanation,
                        correctAnswer: session.lastCorrectAnswer,
                        grammarRuleId: session.lastGrammarRuleId,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (session.completionError != null) ...[
                Text(
                  session.completionError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed:
                    session.isCompleting
                        ? null
                        : () async {
                          await ref
                              .read(lessonSessionProvider.notifier)
                              .nextExercise();
                        },
                icon:
                    session.isCompleting
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.arrow_forward),
                label: Text(
                  session.isCompleting
                      ? 'Saving…'
                      : session.isExamMode
                      ? 'Next Question'
                      : session.currentIndex + 1 < session.totalExercises
                      ? 'Continue'
                      : (session.mistakeQueue.isNotEmpty &&
                          !session.mistakesAppended)
                      ? 'Review Mistakes'
                      : 'Finish Lesson',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Leave lesson?'),
            content: const Text(
              'Your progress in this lesson will be lost. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: const Text('Leave'),
              ),
            ],
          ),
    );
  }
}

/// Teach phase — the lesson's new vocabulary with audio, browsed before
/// the exercises start.
class _TeachPhaseScreen extends ConsumerWidget {
  final LessonSessionState session;
  final VoidCallback onStart;
  final VoidCallback onExit;

  const _TeachPhaseScreen({
    required this.session,
    required this.onStart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final cards = session.teachCards;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: onExit,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.chipBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 18, color: t.ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.lesson?.title ?? 'New words',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                        Text(
                          '${cards.length} new words · tap to hear',
                          style: TextStyle(fontSize: 14, color: t.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _TeachWordCard(card: cards[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: PrimaryButton(
                label: 'Start practice',
                icon: Icons.play_arrow_rounded,
                onPressed: onStart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeachWordCard extends ConsumerWidget {
  final Flashcard card;

  const _TeachWordCard({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final pill =
        card.gender == null ? null : genderPill(context, card.gender!);
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        card.wordCz,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (pill != null) ...[
                      const SizedBox(width: 8),
                      PillChip(
                        label: pill.label,
                        bg: pill.bg,
                        fg: pill.fg,
                        fontSize: 15,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  card.wordEn,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: t.pri,
                  ),
                ),
                if (card.exampleCz != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    card.exampleCz!,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: t.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(color: t.priSoft, shape: BoxShape.circle),
            child: TtsButton(text: card.wordCz),
          ),
        ],
      ),
    );
  }
}

/// Screen shown when the user runs out of hearts.
class _GameOverScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const _GameOverScreen({required this.onRetry, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.heart_broken, size: 80, color: context.tokens.red),
              const SizedBox(height: 24),
              Text(
                'Out of hearts!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Hearts refill over time — one every 30 minutes.\n'
                'Or review vocabulary now: finishing a review session\n'
                'of 5+ cards earns a heart back.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.tokens.muted),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.go('/review'),
                icon: const Icon(Icons.style),
                label: const Text('Review to Earn a Heart'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onExit,
                child: const Text('Back to Curriculum'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen shown when the lesson is completed successfully.
class _LessonCompleteScreen extends ConsumerStatefulWidget {
  final LessonSessionState session;
  final VoidCallback onExit;
  final VoidCallback onRetry;

  const _LessonCompleteScreen({
    required this.session,
    required this.onExit,
    required this.onRetry,
  });

  @override
  ConsumerState<_LessonCompleteScreen> createState() =>
      _LessonCompleteScreenState();
}
class _LessonCompleteScreenState extends ConsumerState<_LessonCompleteScreen>
    with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late final AnimationController _rays;

  /// The frame the trophy lands on. The burst, the rays and everything below
  /// are timed off it, so the screen reads as one event rather than a list of
  /// things that happen to be animating.
  static const _impact = 0.30;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
    // Slow and endless. Fast rotation reads as a loading spinner.
    _rays = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();

    // After the first frame, so the queue is not mutated while the tree that
    // watches it is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = widget.session;
      final queue = ref.read(celebrationQueueProvider.notifier);
      queue.fire(
        LessonCompleted(
          lessonId: session.lesson?.id ?? 0,
          xp: session.totalXp,
          correct: session.correctCount,
          total: session.totalExercises,
        ),
      );
      // Badges and streaks queue behind, so they arrive as a bonus on top of
      // the lesson rather than in place of it.
      session.pendingRewards.forEach(queue.fire);
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    _rays.dispose();
    super.dispose();
  }

  double _slice(double start, double end, [Curve curve = Curves.easeOut]) {
    final t = ((_reveal.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final tokens = context.tokens;
    final accuracy = session.accuracy;
    final grade = LessonRating.grade(accuracy);
    final passed = LessonRating.passed(grade);
    final gamification = ref.watch(gamificationProvider);
    final instant = MediaQuery.disableAnimationsOf(context);

    final accent = switch (grade) {
      LessonGrade.perfect => tokens.amber,
      LessonGrade.great => tokens.green,
      LessonGrade.good => tokens.pri,
      LessonGrade.practice => tokens.violet,
    };

    return Scaffold(
      backgroundColor: tokens.bg,
      body: AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) {
          final landed = instant ? 1.0 : _slice(_impact, 0.5);
          return Stack(
            children: [
              // A wash of the grade's colour behind everything, so the whole
              // screen changes rather than one badge in the middle of it.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.55),
                      radius: 1.1,
                      colors: [
                        accent.withValues(alpha: 0.22 * landed),
                        tokens.bg,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _trophy(accent, grade, instant),
                        const SizedBox(height: 18),
                        if (passed)
                          StarsReveal(
                            earned: LessonRating.stars(grade),
                            feedback: ref.read(feedbackServiceProvider),
                          ),
                        SizedBox(height: passed ? 18 : 0),
                        Opacity(
                          opacity: instant ? 1 : _slice(_impact, 0.55),
                          child: Column(
                            children: [
                              Text(
                                LessonRating.title(grade),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppFonts.display,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                LessonRating.subtitle(grade),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: tokens.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _scoreboard(tokens, accent, accuracy, instant),
                        const SizedBox(height: 14),
                        _chips(tokens, gamification.maxHearts, instant),
                        const SizedBox(height: 26),
                        Opacity(
                          opacity: instant ? 1 : _slice(0.7, 0.95),
                          child: Column(
                            children: [
                              if (session.unitJustCompleted case final unit?)
                                // When this lesson finished a unit, the button
                                // leads into that ceremony instead of past it.
                                // Queueing the unit behind the lesson would
                                // take the screen away mid-sentence.
                                _PrimaryAction(
                                  label: 'Finish Unit ${unit.unitNumber}',
                                  icon: Icons.workspace_premium,
                                  color: accent,
                                  onPressed: () {
                                    ref
                                        .read(celebrationQueueProvider.notifier)
                                        .fire(unit);
                                    // Onto the curriculum first, so dismissing
                                    // the ceremony leaves them looking at the
                                    // unit it just unlocked.
                                    widget.onExit();
                                  },
                                )
                              else
                                _PrimaryAction(
                                  label: passed
                                      ? 'Continue learning'
                                      : 'Back to curriculum',
                                  icon: Icons.school,
                                  color: accent,
                                  onPressed: widget.onExit,
                                ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: widget.onRetry,
                                child: Text(
                                  passed ? 'Practice again' : 'Try again',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Drops in, lands with a burst, and keeps a slow fan of rays behind it.
  Widget _trophy(Color accent, LessonGrade grade, bool instant) {
    final approach = instant ? 1.0 : _slice(0, _impact, Curves.easeInCubic);
    final settle = instant ? 0.0 : 1 - _slice(_impact, 0.48);
    final scale = instant ? 1.0 : (2.4 - 1.4 * approach) + 0.15 * settle;
    final landed = instant ? 1.0 : _slice(_impact, 0.6);

    return SizedBox(
      width: 240,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!instant && grade != LessonGrade.practice)
            AnimatedBuilder(
              animation: _rays,
              builder: (context, _) => CustomPaint(
                size: const Size(240, 200),
                painter: RaysPainter(
                  rotation: _rays.value * 2 * math.pi,
                  color: accent,
                  scale: landed,
                ),
              ),
            ),
          if (!instant)
            CustomPaint(
              size: const Size(240, 200),
              painter: RadialBurstPainter(
                progress: instant ? 1 : _slice(_impact, 0.85),
                colors: [accent, context.tokens.onFill],
                count: 20,
                maxRadius: 150,
              ),
            ),
          Opacity(
            opacity: instant ? 1 : math.min(1, approach * 1.8),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  switch (grade) {
                    LessonGrade.perfect => Icons.emoji_events_rounded,
                    LessonGrade.great => Icons.military_tech_rounded,
                    LessonGrade.good => Icons.check_rounded,
                    LessonGrade.practice => Icons.refresh_rounded,
                  },
                  size: 62,
                  color: context.tokens.onFill,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The score, large enough to be the second thing you see.
  Widget _scoreboard(
    AppTokens tokens,
    Color accent,
    double accuracy,
    bool instant,
  ) {
    return Opacity(
      opacity: instant ? 1 : _slice(0.42, 0.7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _bigStat(
            tokens,
            accent,
            CountUpText(
              value: (accuracy * 100).round(),
              suffix: '%',
              duration: const Duration(milliseconds: 1100),
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            'Accuracy',
          ),
          Container(width: 1, height: 46, color: tokens.line),
          _bigStat(
            tokens,
            accent,
            CountUpText(
              value: widget.session.totalXp,
              prefix: '+',
              duration: const Duration(milliseconds: 1100),
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: tokens.amber,
              ),
            ),
            'XP earned',
          ),
        ],
      ),
    );
  }

  Widget _bigStat(
    AppTokens tokens,
    Color accent,
    Widget value,
    String label,
  ) {
    return Expanded(
      child: Column(
        children: [
          value,
          Text(label, style: TextStyle(fontSize: 13, color: tokens.muted)),
        ],
      ),
    );
  }

  Widget _chips(AppTokens tokens, int maxHearts, bool instant) {
    final session = widget.session;
    return Opacity(
      opacity: instant ? 1 : _slice(0.55, 0.82),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          PillChip(
            label: '${session.correctCount}/${session.totalExercises} correct',
            bg: tokens.greenSoft,
            fg: tokens.green,
            icon: Icons.check_rounded,
          ),
          if (session.bestAnswerStreak >= 3)
            PillChip(
              label: '${session.bestAnswerStreak} in a row',
              bg: tokens.amberSoft,
              fg: tokens.amber,
              icon: Icons.local_fire_department_rounded,
            ),
          PillChip(
            label: '${session.hearts}/$maxHearts hearts',
            bg: tokens.redSoft,
            fg: tokens.red,
            icon: Icons.favorite_rounded,
          ),
        ],
      ),
    );
  }
}

/// The main action, sized so it reads as the obvious next step.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: context.tokens.onFill,
        minimumSize: const Size(240, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _feedbackPrompt(FeedbackStep step) => switch (step) {
  FeedbackStep.signal => 'Something needs attention. Try to notice what.',
  FeedbackStep.selfRepair => 'Try again before asking for more help.',
  FeedbackStep.cue => 'Use the explanation as a cue, then repair your answer.',
  FeedbackStep.explanation => 'Study the answer, then retrieve it once more.',
  FeedbackStep.immediateVariant => 'Now apply the same idea to a variation.',
  FeedbackStep.spacedAnalogue => 'A related task will return later.',
  FeedbackStep.novelTask => 'Use what you remember in this new situation.',
};

/// A suggested pace target for exam practice.
///
/// This deliberately does not end or submit the practice attempt. The label
/// and semantics make that non-enforcement explicit to learners.
class _ExamTimer extends StatefulWidget {
  final int initialSeconds;

  const _ExamTimer({required this.initialSeconds});

  @override
  State<_ExamTimer> createState() => _ExamTimerState();
}

class _ExamTimerState extends State<_ExamTimer> {
  late int _remaining;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.initialSeconds;
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) {
          _remaining--;
          _startTimer();
        } else {
          _expired = true;
        }
      });
    });
  }

  String get _formatted {
    final min = _remaining ~/ 60;
    final sec = _remaining % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isLow = _remaining < 60;
    final status = _expired ? 'Over pace target' : 'Pace target $_formatted';
    return Semantics(
      label: '$status. Practice continues after the target time.',
      child: Tooltip(
        message: 'Suggested pace only — practice continues when time runs out',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _expired ? Icons.timer_off : Icons.timer,
              size: 18,
              color:
                  _expired || isLow
                      ? context.tokens.amber
                      : context.tokens.muted,
            ),
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _expired || isLow ? context.tokens.amber : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen shown when an exam-prep lesson is completed.
class _ExamCompleteScreen extends ConsumerWidget {
  final LessonSessionState session;
  final VoidCallback onExit;

  const _ExamCompleteScreen({required this.session, required this.onExit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accuracy = (session.accuracy * 100).round();
    final passed = accuracy >= 60;
    final theme = Theme.of(context);

    // Unit context labels the course track, not an attained CEFR level.
    final unitId = session.lesson?.unitId ?? 0;
    final cefrLevel = unitId == 29 ? 'A2' : 'A1';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Result icon
                Icon(
                  passed ? Icons.check_circle : Icons.error_outline,
                  size: 80,
                  color: passed ? context.tokens.green : context.tokens.red,
                ),
                const SizedBox(height: 16),

                // Exam result title
                Text(
                  passed ? 'Practice Target Met' : 'Practice Complete',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Course track: $cefrLevel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),

                // Score card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Overall score
                        Text(
                          '$accuracy%',
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: passed ? context.tokens.green : context.tokens.red,
                          ),
                        ),
                        Text(
                          passed ? 'TARGET MET' : 'KEEP PRACTICING',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: passed ? context.tokens.green : context.tokens.red,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lesson exercise accuracy only. This is not an '
                          'official exam result or CEFR certification.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: onExit,
                  icon: const Icon(Icons.school),
                  label: Text(passed ? 'Continue' : 'Back to Curriculum'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
