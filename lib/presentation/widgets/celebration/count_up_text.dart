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
    this.duration = const Duration(milliseconds: 900),
    this.style,
    this.curve = Curves.easeOutCubic,
  });

  final int value;
  final String prefix;
  final String suffix;
  final Duration duration;
  final TextStyle? style;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final instant = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: instant ? Duration.zero : duration,
      curve: curve,
      builder:
          (context, current, _) =>
              Text('$prefix${current.round()}$suffix', style: style),
    );
  }
}
