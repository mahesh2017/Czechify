import 'package:czechify/core/feedback/celebration.dart';
import 'package:czechify/core/feedback/sfx.dart';
import 'package:czechify/presentation/providers/feedback_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finishing the second lesson of a unit can complete the unit *and* earn a
/// badge in the same frame. These pin what happens when celebrations collide.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late CelebrationQueue queue;

  /// Read fresh each time — the notifier replaces the state object.
  CelebrationState state() => container.read(celebrationQueueProvider);

  setUp(() {
    container = ProviderContainer();
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

  test('the feedback recipe escalates with what was earned', () {
    // A unit is the payoff; a badge rides alongside it. If both landed as the
    // same bump, the bigger achievement would not read as bigger.
    expect(recipeFor(unit).haptic, Haptic.double);
    expect(recipeFor(badge).haptic, Haptic.light);
  });

  test('a queued celebration stays pending until it reaches the screen', () {
    queue.fire(lesson);
    queue.fire(unit);
    expect(state().current, lesson);
    expect(state().pending, [unit]);
  });

  group('duplicates', () {
    test('re-firing the one on screen is ignored', () {
      // A widget rebuilding in its initState would otherwise make the learner
      // sit through the same ceremony twice.
      queue.fire(lesson);
      queue.fire(lesson);
      expect(state().pending, isEmpty);
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
  });
}
