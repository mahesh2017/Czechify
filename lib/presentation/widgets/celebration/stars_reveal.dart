import 'package:flutter/material.dart';

import '../../../core/feedback/celebration.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/feedback/sfx.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';

/// Three stars, landing one at a time with a rising note each.
///
/// The score used to arrive as a percentage, which asks the learner to work
/// out for themselves whether that was good. Stars answer it instantly, and
/// arriving in sequence turns one fact into three beats of payoff.
class StarsReveal extends StatefulWidget {
  const StarsReveal({
    super.key,
    required this.earned,
    required this.feedback,
    this.size = 56,
    this.initialDelay = Duration.zero,
    this.announceLandings = true,
  });

  /// 0 to 3.
  final int earned;
  final FeedbackService feedback;
  final double size;

  /// Holds the first landing until the surrounding ceremony has made room.
  final Duration initialDelay;

  /// Whether each star adds its own sound and haptic.
  ///
  /// Standalone stars use the rising notes. A larger ceremony can turn them
  /// off when it already owns a signature impact sound.
  final bool announceLandings;

  @override
  State<StarsReveal> createState() => _StarsRevealState();
}

class _StarsRevealState extends State<StarsReveal> {
  static const _total = 3;
  static const _step = CelebrationTimeline.starStep;

  int _landed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _landed = widget.earned);
      return;
    }
    if (widget.initialDelay > Duration.zero) {
      await Future<void>.delayed(widget.initialDelay);
      if (!mounted) return;
    }
    for (var i = 0; i < widget.earned; i++) {
      await Future<void>.delayed(_step);
      if (!mounted) return;
      setState(() => _landed = i + 1);
      // The same three rising notes a run of correct answers uses, so the
      // reward vocabulary stays consistent across the whole app.
      if (widget.announceLandings) {
        widget.feedback.play(
          Sfx.correctForStreak(i + 1),
          haptic: i == widget.earned - 1 ? Haptic.heavy : Haptic.medium,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _Star(
              index: i,
              filled: i < _landed,
              size: widget.size,
              // The middle star sits higher, the way a podium does.
              lift: i == 1 ? 10 : 0,
              // A filled star is a graphic, not a glyph on a tint, so the
              // raw hue is correct here.
              color: tokens.amber,
              empty: tokens.line,
            ),
          ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({
    required this.index,
    required this.filled,
    required this.size,
    required this.lift,
    required this.color,
    required this.empty,
  });

  final int index;
  final bool filled;
  final double size;
  final double lift;
  final Color color;
  final Color empty;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -lift),
      child: TweenAnimationBuilder<double>(
        // The target changes from 0 to 1 when the star fills. Keeping the end
        // value fixed at 1 was the old bug: Flutter correctly saw no change,
        // so the intended landing animation never ran.
        tween: Tween(end: filled ? 1 : 0),
        duration: context.motionDuration(AppMotion.reward),
        builder:
            (context, landing, child) => Transform.scale(
              key: ValueKey('star-scale-$index'),
              // Overshoot on landing: a star that simply appears has no weight.
              scale:
                  filled
                      ? 0.5 + 0.5 * AppMotion.emphasis.transform(landing)
                      : 1,
              child: child,
            ),
        child: Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled ? color : empty,
          shadows:
              filled
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 18,
                    ),
                  ]
                  : null,
        ),
      ),
    );
  }
}
