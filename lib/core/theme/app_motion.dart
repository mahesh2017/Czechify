import 'package:flutter/material.dart';

/// Shared motion language for Czechify.
///
/// Durations describe the meaning of a transition rather than the widget that
/// happens to use it. Keeping them here prevents small interactions from
/// drifting into a mix of unrelated timings as the app grows.
abstract final class AppMotion {
  /// Direct manipulation feedback, such as a pressed button.
  static const press = Duration(milliseconds: 120);

  /// A selection, icon, border, or colour state changing in place.
  static const selection = Duration(milliseconds: 160);

  /// One local piece of content replacing or revealing another.
  static const content = Duration(milliseconds: 220);

  /// A larger screen or stage entering.
  static const reveal = Duration(milliseconds: 300);

  /// A result the learner has earned and should have time to read.
  static const reward = Duration(milliseconds: 600);

  /// How long non-moving feedback remains readable with reduced motion.
  static const reducedFeedbackHold = Duration(milliseconds: 700);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeOutBack;

  /// Returns [duration], or no duration when the platform has requested less
  /// motion. This is useful for implicit animations; controller-driven motion
  /// should additionally avoid starting its ticker at all.
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

extension AppMotionContext on BuildContext {
  bool get motionDisabled => MediaQuery.disableAnimationsOf(this);

  Duration motionDuration(Duration duration) =>
      AppMotion.resolve(this, duration);
}
