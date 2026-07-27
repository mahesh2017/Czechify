import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import 'sfx.dart';

final _log = Logger('Feedback');

/// Plays a short sound.
///
/// An interface rather than a direct `just_audio` call so tests can assert on
/// what the app *asked* to play. Asserting on what came out of the speaker is
/// not something a test can do, and pretending otherwise produces tests that
/// pass while the app is silent.
abstract interface class SfxPlayer {
  Future<void> preload(Iterable<Sfx> sounds);
  Future<void> play(Sfx sound);
  Future<void> dispose();
}

/// One preloaded [AudioPlayer] per sound.
///
/// A single player swapping assets costs 50–100 ms per switch, which is
/// plainly audible on a sound meant to coincide with a tap. Nine players hold
/// well under a megabyte between them, so the trade is one-sided.
class JustAudioSfxPlayer implements SfxPlayer {
  final _players = <Sfx, AudioPlayer>{};
  bool _disposed = false;

  @override
  Future<void> preload(Iterable<Sfx> sounds) async {
    for (final sound in sounds) {
      if (_disposed) return;
      await _ensureLoaded(sound);
    }
  }

  Future<AudioPlayer?> _ensureLoaded(Sfx sound) async {
    final existing = _players[sound];
    if (existing != null) return existing;
    try {
      final player = AudioPlayer();
      await player.setAsset(sound.asset);
      if (_disposed) {
        await player.dispose();
        return null;
      }
      return _players[sound] = player;
    } catch (error, stack) {
      // A missing or undecodable clip must never take down a lesson.
      _log.fine('Could not load ${sound.asset}', error, stack);
      return null;
    }
  }

  @override
  Future<void> play(Sfx sound) async {
    if (_disposed) return;
    final player = await _ensureLoaded(sound);
    if (player == null || _disposed) return;
    try {
      // Restart rather than ignore: a learner answering quickly should hear
      // every answer land, not have the second one swallowed by the first.
      await player.seek(Duration.zero);
      await player.play();
    } catch (error, stack) {
      _log.fine('Could not play ${sound.asset}', error, stack);
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

/// Fires the platform's haptic engine.
abstract interface class HapticDriver {
  void fire(Haptic haptic);
}

class PlatformHapticDriver implements HapticDriver {
  const PlatformHapticDriver();

  @override
  void fire(Haptic haptic) {
    switch (haptic) {
      case Haptic.none:
        return;
      case Haptic.light:
        HapticFeedback.lightImpact();
      case Haptic.medium:
        HapticFeedback.mediumImpact();
      case Haptic.heavy:
        HapticFeedback.heavyImpact();
      case Haptic.double:
        HapticFeedback.heavyImpact();
        Future.delayed(
          const Duration(milliseconds: 130),
          HapticFeedback.mediumImpact,
        );
    }
  }
}

/// Sound and touch feedback, in one place.
///
/// This is the reflex layer: it fires immediately and returns immediately.
/// Ceremonies that own the screen go through the celebration queue instead —
/// putting correct answers in a queue would leave a lesson-completion
/// celebration stuck behind a dozen queued ticks.
class FeedbackService {
  FeedbackService(
    this._player,
    this._soundEnabled,
    this._hapticsEnabled, [
    this._haptics = const PlatformHapticDriver(),
  ]);

  final SfxPlayer _player;
  final ValueGetter<bool> _soundEnabled;
  final ValueGetter<bool> _hapticsEnabled;
  final HapticDriver _haptics;

  /// True while the microphone is recording.
  ///
  /// Pronunciation exercises record the learner speaking; a sound effect
  /// played during that would be captured by the mic and scored as part of
  /// their speech. Suppression lives here rather than at each call site
  /// because forgetting it once corrupts a recording silently.
  bool micActive = false;

  /// Load the sounds that fire mid-interaction, where loading on first use
  /// would be audible. Safe to call more than once.
  Future<void> preload() => _player.preload(Sfx.values);

  /// Play a sound and fire a haptic. Fire-and-forget by design: nothing in
  /// the UI should ever await feedback.
  void play(Sfx sound, {Haptic haptic = Haptic.none}) {
    if (micActive) return;
    if (haptic != Haptic.none && _hapticsEnabled()) {
      _haptics.fire(haptic);
    }
    if (_soundEnabled()) {
      unawaited(_player.play(sound));
    }
  }

  /// Fire a haptic on its own — for moments that should be felt but not
  /// heard, like a selection changing.
  void haptic(Haptic haptic) {
    if (micActive || haptic == Haptic.none) return;
    if (_hapticsEnabled()) _haptics.fire(haptic);
  }

  Future<void> dispose() => _player.dispose();
}

/// `unawaited` without importing dart:async at every call site.
void unawaited(Future<void> future) {
  future.catchError((Object error, StackTrace stack) {
    _log.fine('Feedback failed', error, stack);
  });
}
