import 'package:czechify/data/database/database.dart' show AppDatabase;
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Day-boundary behaviour of the streak and daily XP.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String daysAgo(int days) =>
      DateTime(today.year, today.month, today.day - days).toIso8601String();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> seed({
    required int streak,
    required String lastOpen,
    bool freeze = true,
    int dailyXp = 0,
    String? resetDate,
  }) => db.gamificationDao.mergeRemote(
    hearts: 5,
    maxHearts: 5,
    currentStreak: streak,
    longestStreak: streak,
    totalXp: 100,
    dailyXp: dailyXp,
    dailyGoalXp: 50,
    gems: 0,
    earnedBadgesJson: '[]',
    streakFreezeAvailable: freeze,
    lastOpenDate: lastOpen,
    dailyXpResetDate: resetDate,
    updatedAt: DateTime.now(),
  );

  ProviderContainer open() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a spent streak freeze survives the next launch', () async {
    // Spending the freeze left the two-day gap in place, so the second launch
    // found it again, with no freeze left, and reset the streak.
    await seed(streak: 10, lastOpen: daysAgo(2));

    final first = open();
    await first.read(gamificationProvider.notifier).ready;
    expect(first.read(gamificationProvider).currentStreak, 10);
    expect(first.read(gamificationProvider).streakFreezeAvailable, isFalse);
    first.dispose();

    final second = open();
    await second.read(gamificationProvider.notifier).ready;
    expect(second.read(gamificationProvider).currentStreak, 10);

    // Studying today continues it.
    expect(
      await second.read(gamificationProvider.notifier).recordStudyDay(),
      isTrue,
    );
    expect(second.read(gamificationProvider).currentStreak, 11);
  });

  test('a process alive across days rolls the day over', () async {
    await seed(
      streak: 10,
      lastOpen: daysAgo(0),
      dailyXp: 40,
      resetDate: daysAgo(0),
    );
    final container = open();
    final notifier = container.read(gamificationProvider.notifier);
    await notifier.ready;

    // Five days pass with the process alive.
    await seed(
      streak: 10,
      lastOpen: daysAgo(5),
      dailyXp: 40,
      resetDate: daysAgo(5),
    );
    await notifier.reload();
    await notifier.refreshForNewDay();
    expect(container.read(gamificationProvider).dailyXp, 0);
    expect(container.read(gamificationProvider).currentStreak, 0);
  });

  test('a study day after a long gap restarts the streak', () async {
    await seed(streak: 10, lastOpen: daysAgo(0));
    final container = open();
    final notifier = container.read(gamificationProvider.notifier);
    await notifier.ready;

    // The process outlives the gap; the lesson commit is the next thing.
    await seed(streak: 10, lastOpen: daysAgo(5));
    await notifier.recordStudyDay();
    expect(container.read(gamificationProvider).currentStreak, 1);
  });

  test('a study day counts once per day', () async {
    await seed(streak: 3, lastOpen: daysAgo(1));
    final container = open();
    final notifier = container.read(gamificationProvider.notifier);
    await notifier.ready;

    expect(await notifier.recordStudyDay(), isTrue);
    expect(await notifier.recordStudyDay(), isFalse);
    expect(container.read(gamificationProvider).currentStreak, 4);
  });

  test('losing a heart from a full pool starts the regen clock', () async {
    // The clock kept the last refill's time, often days old, so the next
    // regen check handed the lost heart straight back.
    await db.gamificationDao.mergeRemote(
      hearts: 5,
      maxHearts: 5,
      currentStreak: 1,
      longestStreak: 1,
      totalXp: 0,
      dailyXp: 0,
      dailyGoalXp: 50,
      gems: 0,
      earnedBadgesJson: '[]',
      lastHeartRefill: now.subtract(const Duration(days: 3)),
      streakFreezeAvailable: true,
      lastOpenDate: daysAgo(0),
      dailyXpResetDate: daysAgo(0),
      updatedAt: now,
    );
    final container = open();
    final notifier = container.read(gamificationProvider.notifier);
    await notifier.ready;

    expect(await notifier.onWrongAnswer(), 4);
    expect(await notifier.onWrongAnswer(), 3);
    await notifier.refreshHearts();
    expect(container.read(gamificationProvider).hearts, 3);
  });

  test('the providers survive being invalidated', () async {
    // Account deletion and switching invalidate both. Riverpod rebuilds the
    // same notifier instance, and a `late final` assigned in build() threw
    // on the second assignment: Home showed an error screen after deletion.
    await seed(streak: 2, lastOpen: daysAgo(0));
    final container = open();
    await container.read(gamificationProvider.notifier).ready;
    await container.read(settingsProvider.notifier).ready;

    container.invalidate(gamificationProvider);
    container.invalidate(settingsProvider);

    await container.read(gamificationProvider.notifier).ready;
    await container.read(settingsProvider.notifier).ready;
    expect(container.read(gamificationProvider).currentStreak, 2);
  });
}
