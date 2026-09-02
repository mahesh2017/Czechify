import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

/// Replaces one keyed piece of local UI with a short fade and vertical shift.
///
/// Give [child] a key that represents its state. Outgoing content is removed
/// from hit testing and the semantics tree as soon as its exit begins, so a
/// fading control cannot still be tapped or announced by a screen reader.
///
/// Keep resource-owning views such as microphone and TTS exercises out of
/// this helper: an [AnimatedSwitcher] retains its outgoing child during exit.
class MotionSwap extends StatelessWidget {
  const MotionSwap({
    super.key,
    required this.child,
    this.duration = AppMotion.content,
    this.offset = const Offset(0, 0.035),
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Duration duration;
  final Offset offset;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final resolved = context.motionDuration(duration);
    return AnimatedSwitcher(
      duration: resolved,
      reverseDuration: resolved,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder:
          (current, previous) => Stack(
            alignment: alignment,
            children: [...previous, if (current != null) current],
          ),
      transitionBuilder:
          (child, animation) => _GuardedMotionTransition(
            animation: animation,
            offset: offset,
            child: child,
          ),
      child: child,
    );
  }
}

/// Reveals or hides a small local section with clipped size and opacity.
///
/// Like [MotionSwap], the outgoing section immediately stops receiving input
/// and semantics focus. This is intended for hints, banners and supporting
/// copy—not whole screens or widgets that own external resources.
class MotionDisclosure extends StatelessWidget {
  const MotionDisclosure({
    super.key,
    required this.visible,
    required this.child,
    this.duration = AppMotion.content,
    this.alignment = Alignment.topCenter,
  });

  final bool visible;
  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final resolved = context.motionDuration(duration);
    return AnimatedSwitcher(
      duration: resolved,
      reverseDuration: resolved,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder:
          (child, animation) => _GuardedSizeTransition(
            animation: animation,
            alignment: alignment,
            child: child,
          ),
      child:
          visible
              ? KeyedSubtree(key: const ValueKey(true), child: child)
              : const SizedBox.shrink(key: ValueKey(false)),
    );
  }
}

class _GuardedMotionTransition extends StatelessWidget {
  const _GuardedMotionTransition({
    required this.animation,
    required this.offset,
    required this.child,
  });

  final Animation<double> animation;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final outgoing = animation.status == AnimationStatus.reverse;
        final value = animation.value.clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: outgoing,
          child: ExcludeSemantics(
            excluding: outgoing,
            child: Opacity(
              opacity: value,
              child: FractionalTranslation(
                translation: offset * (1 - value),
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _GuardedSizeTransition extends StatelessWidget {
  const _GuardedSizeTransition({
    required this.animation,
    required this.alignment,
    required this.child,
  });

  final Animation<double> animation;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final outgoing = animation.status == AnimationStatus.reverse;
        final value = animation.value.clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: outgoing,
          child: ExcludeSemantics(
            excluding: outgoing,
            child: ClipRect(
              child: Align(
                alignment: alignment,
                heightFactor: value,
                child: Opacity(opacity: value, child: child),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
