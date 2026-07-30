import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
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
import '../../widgets/common/lesson_ui.dart';
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
        backgroundColor: context.tokens.bg,
        appBar: AppBar(
          backgroundColor: context.tokens.bg,
          leading: IconButton(
            tooltip: AppLocalizations.of(context).a11yClose,
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_locked) {
      final t = context.tokens;
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          backgroundColor: t.bg,
          leading: IconButton(
            tooltip: AppLocalizations.of(context).a11yClose,
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
                IconTile(
                  icon: Icons.lock_outline,
                  tint: t.elev,
                  fg: t.muted,
                  size: 64,
                  radius: 24,
                  iconSize: 28,
                ),
                const SizedBox(height: 18),
                const DisplayText(
                  'Not open yet',
                  size: 26,
                  weight: FontWeight.w800,
                ),
                const SizedBox(height: 8),
                Text(
                  'Finish the lessons before this one and it unlocks.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: t.muted),
                ),
                const SizedBox(height: 22),
                KeyCta(
                  label: 'Back to curriculum',
                  onPressed: () => context.go('/curriculum'),
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

    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Lesson chrome: leave, position in the lesson, hearts. Replaces an
            // AppBar because none of the three is a title, and the pips need
            // the full width.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.close,
                    tooltip: AppLocalizations.of(context).a11yClose,
                    onTap: () => _showExitConfirm(context),
                  ),
                  const SizedBox(width: 12),
                  if (session.isExamMode || session.lesson?.isReview == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: PillChip(
                        label: session.isExamMode ? 'Exam' : 'Review',
                        bg: session.isExamMode ? t.redSoft : t.priSoft,
                        fg: session.isExamMode ? t.redInk : t.priInk,
                      ),
                    ),
                  Expanded(
                    // A bare progress bar announces nothing useful; state the
                    // position in the lesson instead.
                    child: Semantics(
                      label: AppLocalizations.of(context).a11yLessonProgress(
                        session.currentIndex + 1,
                        session.totalExercises,
                      ),
                      excludeSemantics: true,
                      child: SegmentPips(
                        count: session.totalExercises,
                        currentIndex: session.currentIndex,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Exam timer or hearts
                  if (session.isExamMode)
                    _ExamTimer(initialSeconds: session.remainingSeconds)
                  else
                    Semantics(
                      container: true,
                      label: AppLocalizations.of(
                        context,
                      ).a11yHearts(session.hearts),
                      excludeSemantics: true,
                      child: HeartsChip(hearts: session.hearts),
                    ),
                ],
              ),
            ),
            // Shown only while a substitute is in use — silent otherwise.
            const DegradedModeBanner(),
            // What kind of task this is, and the streak riding on it.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Flexible(
                    child: LessonKicker(
                      session.currentExercise?.type == ExerciseType.teaching
                          ? 'Introduction'
                          : session.inMistakeReview
                          ? 'Missed questions'
                          : AppLocalizations.of(context).lessonQuestionOf(
                            session.currentIndex + 1,
                            session.totalExercises,
                          ),
                      color: session.inMistakeReview ? t.amberInk : t.faint,
                    ),
                  ),
                  if (session.answerStreak >= 3) ...[
                    const SizedBox(width: 9),
                    ComboChip(label: '${session.answerStreak} in a row'),
                  ],
                  const Spacer(),
                  // The running total flies up out of the header on each
                  // award, then settles back into the quiet count.
                  if (session.totalXp > 0) _XpCounter(totalXp: session.totalXp),
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
    final t = context.tokens;
    // Skipped is its own voice: the learner asked to see the answer rather
    // than getting it wrong, so it is neither green nor coral.
    final tone =
        session.lastWasSkipped
            ? FeedbackTone.neutral
            : session.lastWasCorrect
            ? FeedbackTone.correct
            : FeedbackTone.incorrect;

    final title = switch (tone) {
      FeedbackTone.correct => 'Správně!',
      FeedbackTone.incorrect => 'Not quite',
      FeedbackTone.neutral => 'Answer shown',
    };

    // The prompt for the current feedback step leads, then the explanation —
    // the step is an instruction, the explanation is the content.
    final prompt =
        session.feedbackStep == null
            ? null
            : _feedbackPrompt(session.feedbackStep!);
    final explanation = session.lastExplanation?.trim();
    final body = [
      if (prompt != null) prompt,
      if (explanation != null && explanation.isNotEmpty) explanation,
    ].join('\n\n');

    return FeedbackSheet(
      tone: tone,
      title: title,
      body: body.isEmpty ? null : body,
      // Only worth stating when they did not produce it themselves.
      correctAnswer: session.lastWasCorrect ? null : session.lastCorrectAnswer,
      busy: session.isCompleting,
      continueLabel:
          session.isCompleting
              ? 'Saving…'
              : session.isExamMode
              ? 'Next question'
              : session.currentIndex + 1 < session.totalExercises
              ? 'Continue'
              : (session.mistakeQueue.isNotEmpty && !session.mistakesAppended)
              ? 'Review mistakes'
              : 'Finish lesson',
      onContinue:
          () async => ref.read(lessonSessionProvider.notifier).nextExercise(),
      extra: _feedbackExtra(context, session, t),
    );
  }

  /// The grammar-rule link and any save error — nothing, on the common path.
  Widget? _feedbackExtra(
    BuildContext context,
    LessonSessionState session,
    AppTokens t,
  ) {
    final ruleId = session.lastGrammarRuleId;
    final error = session.completionError;
    if (ruleId == null && error == null) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ruleId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/grammar?rule=$ruleId'),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('View grammar rule'),
              style: TextButton.styleFrom(
                foregroundColor: t.ink,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: t.redInk),
            ),
          ),
      ],
    );
  }

  void _showExitConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context).lessonLeaveTitle),
            content: Text(AppLocalizations.of(context).lessonLeaveBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).reviewStay),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: Text(AppLocalizations.of(context).lessonLeave),
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
                  RoundIconButton(
                    icon: Icons.close,
                    tooltip: AppLocalizations.of(context).a11yClose,
                    onTap: onExit,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LessonKicker('New words'),
                        const SizedBox(height: 2),
                        Text(
                          session.lesson?.title ?? 'New words',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${cards.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.faint,
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
              child: KeyCta(label: 'Start practice', onPressed: onStart),
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
    final pill = card.gender == null ? null : genderPill(context, card.gender!);
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
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTile(
                icon: Icons.heart_broken_outlined,
                tint: t.redSoft,
                fg: t.redInk,
                size: 72,
                radius: 24,
                iconSize: 34,
              ),
              const SizedBox(height: 20),
              const DisplayText(
                'Out of hearts',
                size: 30,
                weight: FontWeight.w800,
              ),
              const SizedBox(height: 8),
              Text(
                'Hearts refill on their own — one every 30 minutes. '
                'A review session of five or more cards earns one back now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.5, color: t.muted),
              ),
              const SizedBox(height: 26),
              KeyCta(
                label: 'Review to earn a heart',
                onPressed: () => context.go('/review'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(AppLocalizations.of(context).tryAgain),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onExit,
                child: const Text('Back to curriculum'),
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
                                  label:
                                      passed
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
              builder:
                  (context, _) => CustomPaint(
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

  /// The score, on the divided three-up strip the handoff uses for results.
  ///
  /// The figures still count up — the strip is the container, not a
  /// replacement for the reveal.
  Widget _scoreboard(
    AppTokens tokens,
    Color accent,
    double accuracy,
    bool instant,
  ) {
    final session = widget.session;
    return Opacity(
      opacity: instant ? 1 : _slice(0.42, 0.7),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tokens.line,
          border: Border.all(color: tokens.line),
          borderRadius: BorderRadius.circular(24),
        ),
        // IntrinsicHeight: a stretching Row needs a bounded height, and this
        // sits inside the completion screen's scroll view.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _bigStat(
                tokens,
                CountUpText(
                  value: (accuracy * 100).round(),
                  suffix: '%',
                  duration: const Duration(milliseconds: 1100),
                  style: _statStyle(accent),
                ),
                'Accuracy',
              ),
              const SizedBox(width: 1),
              _bigStat(
                tokens,
                CountUpText(
                  value: session.totalXp,
                  prefix: '+',
                  duration: const Duration(milliseconds: 1100),
                  // Ink, not the raw hue: this is a glyph, not a fill.
                  style: _statStyle(tokens.amberInk),
                ),
                'XP earned',
              ),
              const SizedBox(width: 1),
              _bigStat(
                tokens,
                Text(
                  '${session.correctCount}/${session.totalExercises}',
                  style: _statStyle(tokens.greenInk),
                ),
                'Correct',
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _statStyle(Color color) => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: color,
  );

  Widget _bigStat(AppTokens tokens, Widget value, String label) {
    return Expanded(
      // 1px of the wrapper's own colour showing between cells is the divider.
      child: Container(
        color: tokens.card,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            value,
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.muted,
              ),
            ),
          ],
        ),
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
          if (session.bestAnswerStreak >= 3)
            PillChip(
              label: '${session.bestAnswerStreak} in a row',
              bg: tokens.amberSoft,
              fg: tokens.amberInk,
              icon: Icons.local_fire_department_rounded,
            ),
          PillChip(
            label: '${session.hearts}/$maxHearts hearts',
            bg: tokens.redSoft,
            fg: tokens.redInk,
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

/// The lesson's running XP. Each award flies up out of the header once, showing
/// what was just earned, then the quiet total stays put.
class _XpCounter extends StatefulWidget {
  const _XpCounter({required this.totalXp});

  final int totalXp;

  @override
  State<_XpCounter> createState() => _XpCounterState();
}

class _XpCounterState extends State<_XpCounter> {
  /// The most recent increase, and a counter that makes each one a fresh key
  /// even when two awards happen to be the same size.
  int? _award;
  int _awardSeq = 0;

  @override
  void didUpdateWidget(covariant _XpCounter old) {
    super.didUpdateWidget(old);
    final delta = widget.totalXp - old.totalXp;
    if (delta > 0) {
      setState(() {
        _award = delta;
        _awardSeq++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: t.amberInk, size: 16),
            const SizedBox(width: 3),
            Text(
              '${widget.totalXp} XP',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.amberInk,
              ),
            ),
          ],
        ),
        // The flown label sits above the counter without taking layout space.
        if (_award case final award?)
          Positioned(
            top: -6,
            child: IgnorePointer(
              child: XpFlyUp(key: ValueKey(_awardSeq), label: '+$award XP'),
            ),
          ),
      ],
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
                      ? context.tokens.amberInk
                      : context.tokens.muted,
            ),
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _expired || isLow ? context.tokens.amberInk : null,
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
    final t = context.tokens;
    final accuracy = (session.accuracy * 100).round();
    final passed = accuracy >= 60;
    final hue = passed ? t.greenInk : t.violetInk;

    // Unit context labels the course track, not an attained CEFR level.
    final unitId = session.lesson?.unitId ?? 0;
    final cefrLevel = unitId == 29 ? 'A2' : 'A1';

    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScoreRing(
                fraction: accuracy / 100,
                label: '$accuracy%',
                caption: 'accuracy',
                color: hue,
                showBadge: passed,
              ),
              const SizedBox(height: 20),
              DisplayText(
                passed ? 'Practice target met' : 'Practice complete',
                size: 30,
                weight: FontWeight.w800,
                height: 1.1,
              ),
              const SizedBox(height: 6),
              Text(
                'Course track $cefrLevel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: t.muted,
                ),
              ),
              const SizedBox(height: 22),
              StatStrip(
                cells: [
                  StatCell(
                    value: '${session.correctCount}',
                    label: 'Correct',
                    color: t.greenInk,
                  ),
                  StatCell(
                    value: '${session.totalExercises - session.correctCount}',
                    label: 'Missed',
                    color: t.redInk,
                  ),
                  StatCell(
                    value: '${session.totalXp}',
                    label: 'XP earned',
                    color: t.amberInk,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // The caveat sits below the learner's own figures, not above
              // them — accurate, but it does not outrank their result.
              Text(
                'Lesson exercise accuracy only. This is not an official exam '
                'result or CEFR certification.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.45, color: t.faint),
              ),
              const SizedBox(height: 26),
              KeyCta(
                label: passed ? 'Continue' : 'Back to curriculum',
                onPressed: onExit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
