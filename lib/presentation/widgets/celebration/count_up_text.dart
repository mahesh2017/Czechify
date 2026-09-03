import 'package:flutter/material.dart';

/// A number that arrives instead of appearing.
///
/// Counting up is the cheapest way to make earned XP feel earned: the same
/// figure, shown as a result rather than as a fact. Under reduce-motion it
/// simply shows the final value — the information is what matters, the ramp
/// is decoration.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 900),
    this.style,
    this.curve = Curves.easeOutCubic,
  });

  final int value;
  final String prefix;
  final String suffix;

  /// How long the number holds at zero before the count begins.
  ///
  /// This lets a result wait for its container to become visible without
  /// adding a timer or retaining an outgoing widget. Reduced motion ignores
  /// both [delay] and [duration].
  final Duration delay;
  final Duration duration;
  final TextStyle? style;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final instant = MediaQuery.disableAnimationsOf(context);
    final totalDuration = delay + duration;
    final delayFraction =
        totalDuration == Duration.zero
            ? 0.0
            : delay.inMicroseconds / totalDuration.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: instant ? Duration.zero : totalDuration,
      curve:
          delay == Duration.zero
              ? curve
              : Interval(delayFraction, 1, curve: curve),
      builder:
          (context, current, _) =>
              Text('$prefix${current.round()}$suffix', style: style),
    );
  }
}
