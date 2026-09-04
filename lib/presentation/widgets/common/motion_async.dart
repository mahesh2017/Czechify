import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion_widgets.dart';

/// Crossfades between the three states of an [AsyncValue].
///
/// A bare `value.when(...)` replaces a spinner with a whole screen of content
/// in a single frame. The learner meets that cut on the first visit to a tab
/// every launch, which is the worst possible moment for the app to look
/// abrupt.
///
/// This is a crossfade rather than the sliding [MotionSwap] default: a
/// full-screen body that slides reads as a navigation event, and no navigation
/// happened — the same screen simply finished loading.
///
/// Reduced motion is inherited from [MotionSwap], which resolves its duration
/// to zero and restores the single-frame swap. That is the correct behaviour
/// here: the cut was never the accessibility problem, only the polish one.
class MotionAsync<T> extends StatelessWidget {
  const MotionAsync({
    super.key,
    required this.value,
    required this.data,
    required this.loading,
    required this.error,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final Widget Function() loading;
  final Widget Function(Object error, StackTrace stackTrace) error;

  @override
  Widget build(BuildContext context) {
    return MotionSwap(
      offset: Offset.zero,
      child: value.when(
        // Keyed by state, not by content: a rebuild that keeps the screen in
        // the same state must not restart the fade.
        loading:
            () =>
                KeyedSubtree(key: const ValueKey('loading'), child: loading()),
        error:
            (e, stack) => KeyedSubtree(
              key: const ValueKey('error'),
              child: error(e, stack),
            ),
        data: (v) => KeyedSubtree(key: const ValueKey('data'), child: data(v)),
      ),
    );
  }
}
