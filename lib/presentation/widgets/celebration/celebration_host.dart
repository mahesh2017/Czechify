import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/celebration.dart';
import '../../../core/theme/app_motion.dart';
import '../../../domain/engines/lesson_rating.dart';
import '../../providers/feedback_providers.dart';
import '../common/motion_widgets.dart';
import 'confetti_layer.dart';
import 'reward_toast.dart';
import 'unit_complete_overlay.dart';

/// Draws whatever ceremony is currently holding the screen.
///
/// Mounted above the router rather than inside a screen, because finishing a
/// lesson navigates away from the lesson player: a celebration owned by that
/// screen would be torn down at the exact moment it was meant to play.
class CelebrationHost extends ConsumerStatefulWidget {
  const CelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CelebrationHost> createState() => _CelebrationHostState();
}

class _CelebrationHostState extends ConsumerState<CelebrationHost> {
  Timer? _dismiss;
  Timer? _feedback;
  String? _timedKey;
  String? _feedbackKey;
  bool? _feedbackMotionDisabled;

  @override
  void dispose() {
    _dismiss?.cancel();
    _feedback?.cancel();
    super.dispose();
  }

  /// Land sound and touch on the visible impact, not the first build frame.
  void _scheduleFeedback(Celebration? current) {
    if (current == null) {
      _feedback?.cancel();
      _feedbackKey = null;
      _feedbackMotionDisabled = null;
      return;
    }
    final motionDisabled = MediaQuery.disableAnimationsOf(context);
    if (_feedbackKey == current.key &&
        _feedbackMotionDisabled == motionDisabled) {
      return;
    }

    _feedback?.cancel();
    _feedbackKey = current.key;
    _feedbackMotionDisabled = motionDisabled;
    final recipe = recipeFor(current);
    final delay = motionDisabled ? Duration.zero : recipe.visualImpactDelay;
    _feedback = Timer(delay, () {
      if (!mounted) return;
      final visible = ref.read(celebrationQueueProvider).current;
      if (visible?.key != current.key) return;
      ref
          .read(feedbackServiceProvider)
          .play(recipe.sound, haptic: recipe.haptic);
    });
  }

  /// Start the clock for a self-dismissing ceremony, once per ceremony.
  void _scheduleDismiss(Celebration? current) {
    if (current == null) {
      _dismiss?.cancel();
      _timedKey = null;
      return;
    }
    if (_timedKey == current.key) return;

    _dismiss?.cancel();
    _timedKey = current.key;
    final after = recipeFor(current).autoDismiss;
    if (after == null) return;
    _dismiss = Timer(after, () {
      if (!mounted) return;
      ref.read(celebrationQueueProvider.notifier).dismissCurrent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(
      celebrationQueueProvider.select((state) => state.current),
    );
    // Scheduling during build is safe here: it only ever arms a timer, and the
    // guard on `_timedKey` means a rebuild cannot restart one already running.
    _scheduleDismiss(current);
    _scheduleFeedback(current);

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: MotionSwap(
            duration: AppMotion.content,
            offset: const Offset(0, 0.015),
            child:
                current == null
                    ? const SizedBox.shrink(key: ValueKey('celebration-idle'))
                    : KeyedSubtree(
                      key: ValueKey(current.key),
                      child: _visual(current),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _visual(Celebration celebration) => switch (celebration) {
    // The lesson completion screen owns the trophy, stars and stats; all this
    // adds is the confetti over the top of it. A lesson that fell short of
    // passing gets none — confetti for a result the learner is about to be
    // asked to retry would read as mockery.
    LessonCompleted() => ConfettiLayer(
      delay: recipeFor(celebration).visualImpactDelay,
      duration: _confettiDuration(recipeFor(celebration)),
      pieces: switch (LessonRating.grade(celebration.accuracy)) {
        LessonGrade.perfect => 160,
        LessonGrade.great => 120,
        LessonGrade.good => 80,
        LessonGrade.practice => 0,
      },
    ),
    UnitCompleted() => UnitCompleteOverlay(
      key: ValueKey(celebration.key),
      celebration: celebration,
      onDismiss:
          () => ref.read(celebrationQueueProvider.notifier).dismissCurrent(),
    ),
    BadgeEarned() || StreakExtended() => RewardToast(
      key: ValueKey(celebration.key),
      celebration: celebration,
    ),
  };

  Duration _confettiDuration(CelebrationRecipe recipe) {
    final total = recipe.autoDismiss ?? const Duration(milliseconds: 2600);
    final remaining = total - recipe.visualImpactDelay;
    return remaining > Duration.zero ? remaining : AppMotion.reward;
  }
}
