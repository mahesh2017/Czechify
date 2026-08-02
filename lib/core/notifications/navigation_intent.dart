import 'dart:async';

/// Where a notification tap should send the learner.
enum NavigationTarget { curriculum, review }

/// In-process bridge between a notification tap and the UI's navigator.
///
/// Notification callbacks fire from isolate/native side and cannot touch the
/// navigator directly, so they push a target onto the broadcast [pending]
/// controller; the widget tree listens on [stream] and performs the actual
/// navigation.
class NavigationIntent {
  NavigationIntent._();

  /// Broadcast controller holding the most recent navigation request.
  static final StreamController<NavigationTarget> pending =
      StreamController<NavigationTarget>.broadcast();

  /// Enqueues [target] for the UI to react to.
  static void queue(NavigationTarget target) {
    if (!pending.isClosed) pending.add(target);
  }

  /// Stream the widget tree listens on to receive navigation requests.
  static Stream<NavigationTarget> get stream => pending.stream;

  /// Releases the controller. Call only on app teardown.
  static void dispose() {
    if (!pending.isClosed) pending.close();
  }
}