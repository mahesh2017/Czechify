import 'dart:async';

/// Where a notification tap should send the learner.
enum NavigationTarget { curriculum, review }

/// In-process bridge between a notification tap and the UI's navigator.
///
/// A cold-launch tap can arrive before the widget tree subscribes. The latest
/// target is therefore retained until the first listener consumes it; later
/// taps are delivered by the broadcast controller.
class NavigationIntent {
  NavigationIntent._();

  static final StreamController<NavigationTarget> _controller =
      StreamController<NavigationTarget>.broadcast();
  static NavigationTarget? _pendingTarget;

  /// Enqueues [target] for the UI to react to.
  static void queue(NavigationTarget target) {
    if (_controller.isClosed) return;
    if (_controller.hasListener) {
      _controller.add(target);
    } else {
      _pendingTarget = target;
    }
  }

  /// Delivers a retained cold-start target first, then all subsequent taps.
  static Stream<NavigationTarget> get stream async* {
    final pending = _pendingTarget;
    _pendingTarget = null;
    if (pending != null) yield pending;
    yield* _controller.stream;
  }

  /// Releases the controller. Call only on app teardown.
  static void dispose() {
    if (!_controller.isClosed) _controller.close();
  }
}
