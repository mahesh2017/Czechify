import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/celebration.dart';
import '../../core/feedback/feedback_service.dart';
import 'settings_providers.dart';

/// The sound backend. Overridden in tests with a recording fake.
final sfxPlayerProvider = Provider<SfxPlayer>((ref) {
  final player = JustAudioSfxPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// The haptic backend. Injectable for the same reason as the player: the real
/// one reaches for a platform channel, which no unit test has.
final hapticDriverProvider = Provider<HapticDriver>(
  (ref) => const PlatformHapticDriver(),
);

/// Sound and touch feedback. Reads the settings toggles live, so turning
/// sound off takes effect on the next answer rather than the next launch.
///
/// Deliberately does no work on construction. Warming the clips is an
/// app-startup concern, requested once from `main`; doing it here would spin
/// up nine audio players inside every widget test that happens to answer a
/// question.
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService(
    ref.watch(sfxPlayerProvider),
    () => ref.read(settingsProvider).soundEffectsEnabled,
    () => ref.read(settingsProvider).hapticsEnabled,
    ref.watch(hapticDriverProvider),
  );
});

/// What the celebration host is showing, and what is waiting behind it.
class CelebrationState {
  const CelebrationState({this.current, this.pending = const []});

  /// The ceremony holding the screen right now.
  final Celebration? current;

  /// Queued behind it, in the order they were fired.
  final List<Celebration> pending;

  bool get isIdle => current == null;
}

/// Serializes the ceremonies that own the screen.
///
/// Finishing the second lesson of a unit can complete the unit *and* earn a
/// badge in the same frame. Without a queue those draw over each other and
/// their sounds mix into noise; with one they escalate — lesson, then unit,
/// then badge — which is also the order the learner earned them in.
///
/// Per-answer feedback deliberately does not come through here. It fires ~790
/// times a course and must never wait for anything; queueing it would leave a
/// lesson completion stuck behind a dozen ticks.
class CelebrationQueue extends Notifier<CelebrationState> {
  @override
  CelebrationState build() => const CelebrationState();

  /// Enqueue a celebration, ignoring one that is already queued or showing.
  void fire(Celebration celebration) {
    if (state.current?.key == celebration.key) return;
    if (state.pending.any((queued) => queued.key == celebration.key)) return;

    if (state.current == null) {
      state = CelebrationState(current: celebration);
      return;
    }
    state = CelebrationState(
      current: state.current,
      pending: [...state.pending, celebration],
    );
  }

  /// Called by the host when the current ceremony is done, advancing to
  /// whatever was waiting behind it.
  void dismissCurrent() {
    if (state.current == null) return;
    if (state.pending.isEmpty) {
      state = const CelebrationState();
      return;
    }
    final next = state.pending.first;
    state = CelebrationState(current: next, pending: state.pending.sublist(1));
  }

  /// Drop everything — for leaving a lesson mid-ceremony.
  void clear() => state = const CelebrationState();
}

final celebrationQueueProvider =
    NotifierProvider<CelebrationQueue, CelebrationState>(CelebrationQueue.new);
