import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A lesson used to pay a flat 10/15/20; it now pays the sum of its exercises'
/// XP, roughly six times more. A goal chosen under the old economy would be
/// met by half a lesson, so it is rescaled once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<int> loadedGoal() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).ready;
    return container.read(settingsProvider).dailyGoalXp;
  }

  test('a goal set under the old economy is rescaled once', () async {
    SharedPreferences.setMockInitialValues({'settings_daily_goal_xp': 50});

    expect(await loadedGoal(), 300);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('settings_daily_goal_xp'), 300);
    expect(prefs.getInt('settings_xp_economy_version'), kXpEconomyVersion);
  });

  test('a custom goal keeps the number of lessons it asked for', () async {
    // 100 was roughly seven lessons a day; it still is.
    SharedPreferences.setMockInitialValues({'settings_daily_goal_xp': 100});
    expect(await loadedGoal(), 600);
  });

  test('an already-migrated goal is left alone', () async {
    SharedPreferences.setMockInitialValues({
      'settings_daily_goal_xp': 50,
      'settings_xp_economy_version': kXpEconomyVersion,
    });

    expect(
      await loadedGoal(),
      50,
      reason: 'a goal deliberately set under the new economy is the '
          'learner\'s choice, however small',
    );
  });

  test('a fresh install starts at the new default', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await loadedGoal(), kDefaultDailyGoalXp);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('settings_xp_economy_version'), kXpEconomyVersion);
  });
}
