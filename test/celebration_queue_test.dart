import 'package:ceskina_pro/core/feedback/celebration.dart';
import 'package:ceskina_pro/core/feedback/sfx.dart';
import 'package:ceskina_pro/presentation/providers/feedback_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feedback_service_test.dart' show RecordingHaptics, RecordingSfxPlayer;

/// Finishing the second lesson of a unit can complete the unit *and* earn a
/// badge in the same frame. These pin what happens when celebrations collide.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late RecordingSfxPlayer player;
  late RecordingHaptics haptics;
  late CelebrationQueue queue;

  /// Read fresh each time — the notifier replaces the state object.
  CelebrationState state() => container.read(celebrationQueueProvider);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = RecordingSfxPlayer();
    haptics = RecordingHaptics();
    container = ProviderContainer(
      overrides: [
        sfxPlayerProvider.overrideWithValue(player),
        hapticDriverProvider.overrideWithValue(haptics),
      ],
    );
    queue = container.read(celebrationQueueProvider.notifier);
  });

  tearDown(() => container.dispose());

  const lesson = LessonCompleted(lessonId: 7, xp: 30, correct: 9, total: 12);
  const unit = UnitCompleted(
    unitId: 4,
    unitNumber: 4,
    unitTitle: 'Numbers',
    nextUnitTitle: 'At the Café',
  );
  const badge = BadgeEarned(
    badgeId: 'streak_7',
    name: 'Week Warrior',
    icon: '🔥',
    xpReward: 20,
  );

  test('the first celebration takes the screen immediately', () {
    queue.fire(lesson);
    expect(state().current, lesson);
    expect(state().pending, isEmpty);
  });

  test('later ones wait rather than drawing over it', () {
    queue.fire(lesson);
    queue.fire(unit);
    queue.fire(badge);

    expect(state().current, lesson);
    expect(state().pending, [unit, badge]);
  });

  test('they play in the order they were earned', () {
    queue.fire(lesson);
    queue.fire(unit);
    queue.fire(badge);

    queue.dismissCurrent();
    expect(state().current, unit);
    queue.dismissCurrent();
    expect(state().current, badge);
    queue.dismissCurrent();
    expect(state().isIdle, isTrue);
  });

  test('each celebration is announced exactly once', () {
    queue.fire(lesson);
    queue.fire(unit);
    queue.dismissCurrent();
    queue.dismissCurrent();

    expect(player.played, [Sfx.lessonComplete, Sfx.unitComplete]);
  });

  test('what you feel escalates with what you earned', () {
    // A unit is the payoff; a badge rides alongside it. If both landed as the
    // same bump, the bigger achievement would not read as bigger.
    queue.fire(unit);
    queue.fire(badge);
    queue.dismissCurrent();

    expect(haptics.fired, [Haptic.double, Haptic.light]);
  });

  test('a queued celebration stays silent until it reaches the screen', () {
    // Otherwise three sounds fire at once and mix into noise, which is the
    // whole reason these are serialized.
    queue.fire(lesson);
    queue.fire(unit);
    expect(player.played, [Sfx.lessonComplete]);
  });

  group('duplicates', () {
    test('re-firing the one on screen is ignored', () {
      // A widget rebuilding in its initState would otherwise make the learner
      // sit through the same ceremony twice.
      queue.fire(lesson);
      queue.fire(lesson);
      expect(state().pending, isEmpty);
      expect(player.played, hasLength(1));
    });

    test('re-firing one already queued is ignored', () {
      queue.fire(lesson);
      queue.fire(unit);
      queue.fire(unit);
      expect(state().pending, [unit]);
    });

    test('identity is the event, not the object', () {
      queue.fire(lesson);
      // A provider refresh rebuilds the value; it is still the same lesson.
      queue.fire(
        const LessonCompleted(lessonId: 7, xp: 30, correct: 9, total: 12),
      );
      expect(state().pending, isEmpty);
    });

    test('different units are different celebrations', () {
      queue.fire(unit);
      queue.fire(
        const UnitCompleted(unitId: 5, unitNumber: 5, unitTitle: 'At the Café'),
      );
      expect(state().pending, hasLength(1));
    });
  });

  test('dismissing an empty queue is harmless', () {
    queue.dismissCurrent();
    expect(state().isIdle, isTrue);
    expect(player.played, isEmpty);
  });

  test('clearing drops everything, for leaving mid-ceremony', () {
    queue.fire(lesson);
    queue.fire(unit);
    queue.clear();
    expect(state().isIdle, isTrue);
    expect(state().pending, isEmpty);
  });

  test('the queue is reusable after it drains', () {
    queue.fire(lesson);
    queue.dismissCurrent();
    queue.fire(unit);
    expect(state().current, unit);
    expect(player.played, [Sfx.lessonComplete, Sfx.unitComplete]);
  });
}
