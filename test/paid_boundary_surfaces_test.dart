import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/database/database.dart' show AppDatabase;
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:czechify/presentation/models/curriculum_path_item.dart';
import 'package:czechify/presentation/providers/course_admission_providers.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:czechify/presentation/providers/referral_providers.dart';
import 'package:czechify/presentation/providers/review_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/curriculum/curriculum_screen.dart';
import 'package:czechify/presentation/screens/home/home_screen.dart';
import 'package:czechify/presentation/screens/lesson/delayed_transfer_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lesson_session_harness.dart';
import 'support/localized_app.dart';

/// Where learning reaches content the account has not paid for, Home and the
/// course map say so and lead to the options, instead of showing nothing.
const _boundary = Lesson(
  id: 40,
  unitId: 4,
  orderInUnit: 1,
  title: 'At the market',
  description: '',
);

Unit _unit(int id, Phase phase) => Unit(
  id: id,
  title: 'Unit $id',
  description: 'About unit $id',
  phase: phase,
  orderIndex: id,
);

CurriculumPathItem _item(Unit unit, CurriculumPathState state) =>
    CurriculumPathItem(
      unit: unit,
      lessons: const [],
      state: state,
      section: unit.phase == Phase.a1 ? 'A1' : 'A2',
      payoff: '',
      durationMinutes: 10,
    );

void main() {
  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Lesson? boundary,
    bool referrals = true,
    Set<int> unlocked = const {1, 4, 16},
    CurriculumPathState state = CurriculumPathState.available,
    Set<int> accessible = const {1},
    CEFRLevel level = CEFRLevel.a1,
  }) async {
    // The course map shows the learner's level only.
    SharedPreferences.setMockInitialValues({
      'settings_starting_level': level.index,
    });
    final units = [_unit(1, Phase.a1), _unit(4, Phase.a1), _unit(16, Phase.a2)];
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(
          path: '/upgrade',
          builder:
              (_, state) => Scaffold(
                body: Text('Upgrade for ${state.uri.queryParameters['unit']}'),
              ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          gamificationProvider.overrideWith(TestGamificationNotifier.new),
          continueLessonProvider.overrideWith((_) async => null),
          nextLessonProvider.overrideWith((_) async => null),
          revisitLessonProvider.overrideWith((_) async => null),
          dueCardCountProvider.overrideWith((_) async => 0),
          dueTransferProvider.overrideWith((_) async => []),
          czechTtsAvailableProvider.overrideWith((_) async => true),
          paidBoundaryLessonProvider.overrideWith((_) async => boundary),
          referralsEnabledProvider.overrideWith((_) async => referrals),
          allUnitsProvider.overrideWith((_) async => units),
          unlockedUnitIdsProvider.overrideWith((_) async => unlocked),
          curriculumPathItemsProvider.overrideWith(
            (_) async => [for (final unit in units) _item(unit, state)],
          ),
          commerciallyAccessibleUnitIdsProvider.overrideWith(
            (_) async => accessible,
          ),
        ],
        child: MaterialApp.router(
          theme: lightTheme(),
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Home', () {
    testWidgets('at the paid boundary it offers the options, not "done"', (
      tester,
    ) async {
      await pump(tester, const HomeScreen(), boundary: _boundary);
      expect(find.text('Ready for the next unit?'), findsOneWidget);
      expect(find.textContaining('invite friends'), findsOneWidget);
      expect(find.text('All caught up!'), findsNothing);
      await tester.tap(find.text('Ready for the next unit?'));
      await tester.pumpAndSettle();
      expect(find.text('Upgrade for 4'), findsOneWidget);
    });

    testWidgets('closed invitations mention only Core', (tester) async {
      await pump(
        tester,
        const HomeScreen(),
        boundary: _boundary,
        referrals: false,
      );
      expect(find.textContaining('Subscribe to Czechify Core'), findsOneWidget);
      expect(find.textContaining('invite friends'), findsNothing);
    });

    testWidgets('with nothing paid ahead it is still all caught up', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      expect(find.text('All caught up!'), findsOneWidget);
      expect(find.text('Ready for the next unit?'), findsNothing);
    });
  });

  group('course map', () {
    Future<void> settle(WidgetTester tester) async {
      // Let the in-memory database's streams close before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('an unpaid A1 unit offers both ways to open it', (
      tester,
    ) async {
      await pump(tester, const CurriculumScreen());
      expect(find.text('Part of the full course'), findsOneWidget);
      expect(find.textContaining('invite friends to unlock'), findsOneWidget);
      await tester.tap(find.text('See your options'));
      await tester.pumpAndSettle();
      expect(find.text('Upgrade for 4'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('an unpaid A2 unit mentions only Core', (tester) async {
      await pump(tester, const CurriculumScreen(), level: CEFRLevel.a2);
      expect(find.text('Part of the full course'), findsOneWidget);
      expect(find.text('Included with Czechify Core.'), findsOneWidget);
      expect(find.textContaining('invite friends'), findsNothing);
      await settle(tester);
    });

    testWidgets('closed invitations mention only Core for A1 too', (
      tester,
    ) async {
      await pump(tester, const CurriculumScreen(), referrals: false);
      expect(find.text('Included with Czechify Core.'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('nothing is marked while every unit is accessible', (
      tester,
    ) async {
      await pump(tester, const CurriculumScreen(), accessible: {1, 4, 16});
      expect(find.text('Part of the full course'), findsNothing);
      await settle(tester);
    });

    testWidgets('a locked unit says what opens it', (tester) async {
      await pump(tester, const CurriculumScreen(), unlocked: {1});
      expect(find.text('· Unlocks after unit 1'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('finishing A1 offers the next level', (tester) async {
      await pump(
        tester,
        const CurriculumScreen(),
        accessible: {1, 4, 16},
        state: CurriculumPathState.completed,
      );
      expect(find.text('That is all of A1. Ready for A2?'), findsOneWidget);
      await settle(tester);
    });
  });
}
