import 'package:czechify/data/database/database.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:czechify/presentation/screens/settings/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// The daily goal is offered in two places — the onboarding goal step and this
/// dropdown — and DropdownButton asserts when its `value` is not among its
/// `items`. While the two lists disagreed, onboarding wrote 50, the rescaled
/// dropdown offered 120/300/600/900, and opening Settings threw:
///
///   There should be exactly one item with [DropdownButton]'s value: 50.
///
/// Every install hit it on the default path. The unit tests around the goal
/// all passed: they asserted the stored number, never that anything could
/// render it.
void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() async => database.close());

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('settings opens on a goal that is not one of the presets', (
    tester,
  ) async {
    // Already migrated, so the rescale will not run and the number stays as
    // it is — the state of anyone who onboarded on a build whose goal step
    // still offered the old economy's numbers.
    SharedPreferences.setMockInitialValues({
      'settings_daily_goal_xp': 50,
      'settings_xp_economy_version': kXpEconomyVersion,
    });

    await openSettings(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.text('50 XP'),
      findsOneWidget,
      reason: 'an off-preset goal is shown as itself, not silently snapped to '
          'a preset the learner never chose',
    );
  });

  // One test per preset — SharedPreferences keeps its mock values for the
  // life of a test body, so looping inside one would keep reading the first.
  for (final (xp, label, _) in kDailyGoalPresets) {
    testWidgets('settings opens on the $label preset', (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings_daily_goal_xp': xp,
        'settings_xp_economy_version': kXpEconomyVersion,
      });

      await openSettings(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(label), findsOneWidget);
    });
  }

  test('the goal presets include the default', () {
    expect(
      kDailyGoalPresets.map((p) => p.$1),
      contains(kDefaultDailyGoalXp),
      reason: 'a fresh install starts on kDefaultDailyGoalXp, so the dropdown '
          'must have an item for it',
    );
  });
}
