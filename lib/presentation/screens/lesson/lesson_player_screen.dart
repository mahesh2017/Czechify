import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/flashcard.dart';
import '../../../domain/engines/learning_loop_engine.dart';
import '../../providers/lesson_providers.dart';
import '../../providers/gamification_providers.dart';
import '../../providers/curriculum_providers.dart';
import '../../widgets/lesson/exercise_widget.dart';
import '../../widgets/lesson/lesson_exercise_viewport.dart';
import '../../widgets/common/grammar_tip_card.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/stat_row.dart';

/// Maps a flashcard `gender` string to a short pill label + token colors.
({String label, Color bg, Color fg}) _genderPill(
  BuildContext context,
  String g,
) {
  final t = context.tokens;
  final v = g.toLowerCase();
  if (v.startsWith('fem')) return (label: 'fem', bg: t.redSoft, fg: t.red);
  if (v.startsWith('neut')) {
    return (label: 'neut', bg: t.amberSoft, fg: t.amber);
  }
  if (v.contains('inanimate')) {
    return (label: 'masc inan', bg: t.violetSoft, fg: t.violet);
  }
  if (v.startsWith('masc')) {
    return (label: 'masc anim', bg: t.priSoft, fg: t.priInk);
  }
  return (label: g, bg: t.chipBg, fg: t.muted);
}

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
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'EXAM',
                  style: TextStyle(
                    color: Colors.white,
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
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'REVIEW',
                  style: TextStyle(
                    color: Colors.white,
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
                        session.hearts > 0 ? Colors.red : Colors.grey.shade400,
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
                              ? Colors.orange.shade700
                              : Colors.grey,
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
                          color: Colors.amber.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '+${session.totalXp} XP',
                          style: TextStyle(
                            color: Colors.amber.shade700,
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
        card.gender == null ? null : _genderPill(context, card.gender!);
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
              Icon(Icons.heart_broken, size: 80, color: Colors.red.shade300),
              const SizedBox(height: 24),
              Text(
                'Out of hearts!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Hearts refill over time — one every 30 minutes.\n'
                'Or review vocabulary now: finishing a review session\n'
                'of 5+ cards earns a heart back.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
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
class _LessonCompleteScreen extends ConsumerWidget {
  final LessonSessionState session;
  final VoidCallback onExit;
  final VoidCallback onRetry;

  const _LessonCompleteScreen({
    required this.session,
    required this.onExit,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accuracy = (session.accuracy * 100).round();
    final isPerfect = session.correctCount == session.totalExercises;
    final gamification = ref.watch(gamificationProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Trophy / star icon
              Icon(
                isPerfect ? Icons.emoji_events : Icons.check_circle,
                size: 80,
                color: isPerfect ? Colors.amber : Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                isPerfect ? 'Perfektní! Perfect!' : 'Výborně! Well done!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),

              // Stats
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      StatRow(
                        icon: Icons.check,
                        label: 'Correct',
                        value:
                            '${session.correctCount}/${session.totalExercises}',
                        color: Colors.green,
                      ),
                      const Divider(),
                      StatRow(
                        icon: Icons.percent,
                        label: 'Accuracy',
                        value: '$accuracy%',
                        color:
                            accuracy >= 80
                                ? Colors.green
                                : accuracy >= 60
                                ? Colors.orange
                                : Colors.red,
                      ),
                      const Divider(),
                      StatRow(
                        icon: Icons.star,
                        label: 'XP Earned',
                        value: '+${session.totalXp}',
                        color: Colors.amber,
                      ),
                      const Divider(),
                      StatRow(
                        icon: Icons.favorite,
                        label: 'Hearts Remaining',
                        value: '${session.hearts}/${gamification.maxHearts}',
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.school),
                label: const Text('Continue Learning'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: const Text('Practice Again'),
              ),
            ],
          ),
        ),
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
                  _expired
                      ? Colors.orange.shade800
                      : isLow
                      ? Colors.orange.shade600
                      : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color:
                    _expired
                        ? Colors.orange.shade800
                        : isLow
                        ? Colors.orange.shade700
                        : null,
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
                  color: passed ? Colors.green : Colors.red.shade400,
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
                            color: passed ? Colors.green : Colors.red.shade400,
                          ),
                        ),
                        Text(
                          passed ? 'TARGET MET' : 'KEEP PRACTICING',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: passed ? Colors.green : Colors.red.shade400,
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
