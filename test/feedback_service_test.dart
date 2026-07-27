import 'dart:io';

import 'package:ceskina_pro/core/feedback/celebration.dart';
import 'package:ceskina_pro/core/feedback/feedback_service.dart';
import 'package:ceskina_pro/core/feedback/sfx.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what was asked for. Whether a speaker actually made a noise is not
/// something a test can observe, and a test that pretends otherwise passes
/// happily while the app is silent.
class RecordingSfxPlayer implements SfxPlayer {
  final played = <Sfx>[];
  final preloaded = <Sfx>[];

  @override
  Future<void> preload(Iterable<Sfx> sounds) async => preloaded.addAll(sounds);

  @override
  Future<void> play(Sfx sound) async => played.add(sound);

  @override
  Future<void> dispose() async {}
}

class RecordingHaptics implements HapticDriver {
  final fired = <Haptic>[];

  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

void main() {
  late RecordingSfxPlayer player;
  late RecordingHaptics haptics;

  FeedbackService serviceWith({bool sound = true, bool haptic = true}) =>
      FeedbackService(player, () => sound, () => haptic, haptics);

  setUp(() {
    player = RecordingSfxPlayer();
    haptics = RecordingHaptics();
  });

  group('settings gate each channel independently', () {
    test('both fire when both are on', () {
      serviceWith().play(Sfx.correct1, haptic: Haptic.light);
      expect(player.played, [Sfx.correct1]);
      expect(haptics.fired, [Haptic.light]);
    });

    test('sound off still leaves haptics', () {
      // Someone in a quiet room wants the app silent, not inert.
      serviceWith(sound: false).play(Sfx.correct1, haptic: Haptic.light);
      expect(player.played, isEmpty);
      expect(haptics.fired, [Haptic.light]);
    });

    test('haptics off still leaves sound', () {
      serviceWith(haptic: false).play(Sfx.correct1, haptic: Haptic.light);
      expect(player.played, [Sfx.correct1]);
      expect(haptics.fired, isEmpty);
    });

    test('a toggle takes effect immediately, not at next launch', () {
      var enabled = true;
      final service = FeedbackService(
        player,
        () => enabled,
        () => true,
        haptics,
      );
      service.play(Sfx.correct1);
      enabled = false;
      service.play(Sfx.correct2);
      expect(player.played, [Sfx.correct1]);
    });
  });

  group('recording suppression', () {
    test('nothing plays while the microphone is live', () {
      // Pronunciation exercises record the learner speaking. A sound effect
      // during that is captured by the mic and scored as part of their
      // speech — a failure that is silent and very hard to trace.
      final service = serviceWith()..micActive = true;
      service.play(Sfx.correct1, haptic: Haptic.light);
      service.haptic(Haptic.medium);
      expect(player.played, isEmpty);
      expect(haptics.fired, isEmpty);
    });

    test('feedback resumes once recording stops', () {
      final service = serviceWith()..micActive = true;
      service.play(Sfx.correct1);
      service.micActive = false;
      service.play(Sfx.correct2);
      expect(player.played, [Sfx.correct2]);
    });
  });

  group('correct-answer escalation', () {
    test('the note rises with a run of right answers', () {
      expect(Sfx.correctForStreak(1), Sfx.correct1);
      expect(Sfx.correctForStreak(2), Sfx.correct2);
      expect(Sfx.correctForStreak(3), Sfx.correct3);
    });

    test('it saturates instead of climbing forever', () {
      // ~790 correct answers a course. An escalation with no ceiling stops
      // being a reward and becomes a siren.
      expect(Sfx.correctForStreak(9), Sfx.correct3);
      expect(Sfx.correctForStreak(400), Sfx.correct3);
    });

    test('a broken streak returns to the bottom step', () {
      expect(Sfx.correctForStreak(0), Sfx.correct1);
    });
  });

  group('the sound pack matches what the code asks for', () {
    test('latency-critical clips are uncompressed', () {
      // MP3 decoders prepend ~26 ms of silence, which reads as lag on a sound
      // meant to land with the tap. Anything the learner triggers directly
      // has to stay WAV.
      for (final sound in Sfx.latencyCritical) {
        expect(
          sound.file,
          endsWith('.wav'),
          reason: '${sound.name} fires mid-interaction',
        );
      }
    });

    test('every sound resolves to a bundled asset path', () {
      for (final sound in Sfx.values) {
        expect(sound.asset, startsWith('assets/sfx/'));
      }
    });

    test('every named clip actually exists', () {
      // The player swallows a missing asset by design, so a renamed or
      // ungenerated file would ship as silence with nothing in the logs.
      for (final sound in Sfx.values) {
        expect(
          File(sound.asset).existsSync(),
          isTrue,
          reason: '${sound.asset} is missing — run tool/generate_sfx.py',
        );
      }
    });

    test('no clip is heavy enough to bloat the bundle', () {
      final total = Sfx.values
          .map((s) => File(s.asset).lengthSync())
          .reduce((a, b) => a + b);
      expect(total, lessThan(400 * 1024), reason: '${total ~/ 1024} KB of SFX');
    });
  });

  group('celebration recipes', () {
    test('a perfect lesson does not sound like an ordinary one', () {
      const ordinary = LessonCompleted(
        lessonId: 1,
        xp: 30,
        correct: 9,
        total: 12,
      );
      const perfect = LessonCompleted(
        lessonId: 1,
        xp: 40,
        correct: 12,
        total: 12,
      );
      expect(ordinary.isPerfect, isFalse);
      expect(perfect.isPerfect, isTrue);
      expect(recipeFor(perfect).sound, isNot(recipeFor(ordinary).sound));
    });

    test('a unit waits for the learner rather than sliding away', () {
      // It names the unit that was just unlocked. Dismissing that on a timer
      // wastes the one moment the app has to say what comes next.
      const unit = UnitCompleted(
        unitId: 5,
        unitNumber: 5,
        unitTitle: 'At the Café',
      );
      expect(recipeFor(unit).autoDismiss, isNull);
    });

    test('smaller moments dismiss themselves', () {
      const badge = BadgeEarned(
        badgeId: 'streak_7',
        name: 'Week Warrior',
        icon: '🔥',
        xpReward: 20,
      );
      expect(recipeFor(badge).autoDismiss, isNotNull);
    });

    test('every fifth unit is the milestone', () {
      UnitCompleted at(int n) =>
          UnitCompleted(unitId: n, unitNumber: n, unitTitle: 'Unit $n');
      expect(at(5).isMilestone, isTrue);
      expect(at(30).isMilestone, isTrue);
      expect(at(4).isMilestone, isFalse);
      expect(at(31).isMilestone, isFalse);
    });

    test('streaks are only marked at milestones', () {
      // Congratulating someone on day four devalues day seven.
      expect(StreakExtended.isMilestone(7), isTrue);
      expect(StreakExtended.isMilestone(30), isTrue);
      expect(StreakExtended.isMilestone(4), isFalse);
      expect(StreakExtended.isMilestone(8), isFalse);
    });
  });
}
