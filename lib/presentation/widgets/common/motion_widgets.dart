import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

/// Animates a numeric value only after it changes.
///
/// The first frame renders [value] exactly as supplied, which keeps restored
/// progress and persisted stats still on screen load. If the platform asks for
/// reduced motion, an in-flight change snaps to its destination and the
/// controller is stopped instead of scheduling more frames.
class MotionValueBuilder extends StatefulWidget {
  const MotionValueBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.initialValue,
    this.duration = AppMotion.content,
    this.curve = AppMotion.enter,
    this.child,
  });

  final double value;
  final ValueWidgetBuilder<double> builder;
  final double? initialValue;
  final Duration duration;
  final Curve curve;
  final Widget? child;

  @override
  State<MotionValueBuilder> createState() => _MotionValueBuilderState();
}

class _MotionValueBuilderState extends State<MotionValueBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.initialValue == null ? 1 : 0,
  );
  late double _from = widget.initialValue ?? widget.value;
  late double _to = widget.value;
  bool _initialAnimationHandled = false;

  double get _value =>
      _from + (_to - _from) * widget.curve.transform(_controller.value);

  @override
  void didUpdateWidget(covariant MotionValueBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.value == _to) return;

    _from = _value;
    _to = widget.value;
    if (context.motionDisabled) {
      _controller.stop();
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motionDisabled) {
      _controller.stop();
      _controller.value = 1;
      _initialAnimationHandled = true;
    } else if (!_initialAnimationHandled) {
      _initialAnimationHandled = true;
      if (_from != _to) _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => widget.builder(context, _value, child),
    );
  }
}

/// A compact integer label backed by [MotionValueBuilder].
class MotionNumberText extends StatelessWidget {
  const MotionNumberText(
    this.value, {
    super.key,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = AppMotion.content,
    this.textAlign,
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return MotionValueBuilder(
      value: value.toDouble(),
      duration: duration,
      builder:
          (context, animated, _) => Text(
            '$prefix${animated.round()}$suffix',
            textAlign: textAlign,
            style: style,
          ),
    );
  }
}

/// Fades and lifts one incoming subtree without retaining the previous one.
///
/// Key this widget by the content identity. When the key changes Flutter
/// disposes the old subtree immediately, then only the new subtree animates.
/// This is the safe screen-level transition for exercises that may own a
/// microphone, TTS playback, timers, or other resources that must not survive
/// behind an exit animation.
class MotionEntrance extends StatefulWidget {
  const MotionEntrance({
    super.key,
    required this.child,
    this.duration = AppMotion.reveal,
    this.offset = const Offset(0, 0.025),
    this.animateOnMount = true,
  });

  final Widget child;
  final Duration duration;
  final Offset offset;
  final bool animateOnMount;

  @override
  State<MotionEntrance> createState() => _MotionEntranceState();
}

class _MotionEntranceState extends State<MotionEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.animateOnMount ? 0 : 1,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motionDisabled) {
      _controller.stop();
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      if (widget.animateOnMount) _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MotionEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = AppMotion.enter.transform(_controller.value);
        return Opacity(
          opacity: value,
          child: FractionalTranslation(
            translation: widget.offset * (1 - value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

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
    this.offset = const Offset(0, 0.025),
  });

  final bool visible;
  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;
  final Offset offset;

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
            offset: offset,
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
    required this.offset,
    required this.child,
  });

  final Animation<double> animation;
  final AlignmentGeometry alignment;
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
            child: ClipRect(
              child: Align(
                alignment: alignment,
                heightFactor: value,
                child: Opacity(
                  opacity: value,
                  child: FractionalTranslation(
                    translation: offset * (1 - value),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
