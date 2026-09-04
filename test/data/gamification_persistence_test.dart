import 'package:czechify/data/database/database.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy SharedPreferences state migrates once and persists in Drift',
    () async {
      SharedPreferences.setMockInitialValues({
        'gamification_hearts': 3,
        'gamification_max_hearts': 6,
        'gamification_current_streak': 2,
        'gamification_longest_streak': 5,
        'gamification_total_xp': 140,
        'gamification_daily_xp': 15,
        'gamification_daily_goal_xp': 50,
        'gamification_gems': 9,
        'gamification_earned_badges': '["first"]',
        'gamification_streak_freeze': false,
        'gamification_last_open_date': DateTime.now().toIso8601String(),
        'gamification_daily_xp_reset_date': DateTime.now().toIso8601String(),
      });
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      await database.customSelect('SELECT 1').get();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final notifier = container.read(gamificationProvider.notifier);
      await notifier.setDailyGoal(75);

      final state = container.read(gamificationProvider);
      expect(state.hearts, 3);
      expect(state.maxHearts, 6);
      expect(state.totalXp, 140);
      expect(state.gems, 9);
      expect(state.earnedBadges, {'first'});
      expect(state.dailyGoalXp, 75);

      final row = await database.gamificationDao.load();
      expect(row?.hearts, 3);
      expect(row?.dailyGoalXp, 75);
      expect(await database.syncDao.pendingCount(), greaterThanOrEqualTo(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('gamification_hearts'), isFalse);
      expect(prefs.containsKey('gamification_total_xp'), isFalse);
    },
  );
}
