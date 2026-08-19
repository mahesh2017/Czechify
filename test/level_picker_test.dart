import 'package:ceskina_pro/data/database/database.dart' hide Unit;
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/unit.dart';
import 'package:ceskina_pro/presentation/providers/curriculum_providers.dart';
import 'package:ceskina_pro/presentation/providers/database_providers.dart';
import 'package:ceskina_pro/presentation/providers/settings_providers.dart';
import 'package:ceskina_pro/presentation/screens/settings/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

const List<Unit> _units = [
  Unit(id: 1, title: 'a', description: '', phase: Phase.a1, orderIndex: 1),
  Unit(id: 2, title: 'b', description: '', phase: Phase.a1, orderIndex: 2),
  Unit(id: 16, title: 'c', description: '', phase: Phase.a2, orderIndex: 3),
];

/// Changing level unlocks curriculum, repitches the tutor and downloads a new
/// level's audio. It used to be a dropdown in a scrolling list — one stray
/// thumb from all of that, with nothing said about what you were choosing.
void main() {
  late AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() async => database.close());

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          allUnitsProvider.overrideWith((ref) async => _units),
        ],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The sheet scrolls on a short viewport, so both targets have to be
  /// brought on screen before they can be tapped.
  Future<void> chooseA2AndContinue(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Upper beginner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper beginner'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> openLevelSheet(WidgetTester tester) async {
    await openSettings(tester);
    await tester.scrollUntilVisible(find.text('Course level'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Course level'));
    await tester.pumpAndSettle();
  }

  testWidgets('the row opens a sheet rather than changing level on the spot', (
    tester,
  ) async {
    await openLevelSheet(tester);

    expect(find.text('Choose your course level'), findsOneWidget);
    // Both levels are explained in terms of what a learner will be able to do.
    expect(find.textContaining('Start from Czech sounds'), findsOneWidget);
    expect(find.textContaining('what happened and what you plan'), findsOneWidget);
    // Nothing has changed yet.
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(settingsProvider).startingLevel,
      isNot(CEFRLevel.a2),
    );
  });

  testWidgets('unit counts come from the curriculum, not a literal', (
    tester,
  ) async {
    await openLevelSheet(tester);

    // Two A1 units and one A2 unit in this fixture; hardcoded "17"/"14" would
    // survive a curriculum change silently.
    expect(find.text('2 units'), findsOneWidget);
    expect(find.text('1 units'), findsOneWidget);
  });

  testWidgets('choosing the level already held cannot be confirmed', (
    tester,
  ) async {
    await openLevelSheet(tester);
    expect(find.text('This is your level'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('This is your level'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('picking the other level asks before doing anything', (
    tester,
  ) async {
    await openLevelSheet(tester);

    await chooseA2AndContinue(tester);

    expect(find.text('Switch to A2?'), findsOneWidget);
    // The consequences are named, including the one that costs bandwidth.
    expect(find.textContaining('A2 audio will download'), findsOneWidget);
    expect(find.textContaining('stays open'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation leaves the level alone', (
    tester,
  ) async {
    await openLevelSheet(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final before = container.read(settingsProvider).startingLevel;

    await chooseA2AndContinue(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).startingLevel, before);
    expect(
      await database.select(database.placementProfiles).getSingleOrNull(),
      isNull,
      reason: 'nothing was written',
    );
  });
}
