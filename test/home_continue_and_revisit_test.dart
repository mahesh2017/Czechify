import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/engines/learning_router.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:czechify/presentation/providers/review_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/home/home_screen.dart';
import 'package:czechify/presentation/screens/lesson/delayed_transfer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lesson_session_harness.dart';
import 'support/localized_app.dart';

/// Home and Daily Arrival name the same next lesson: the one after the lesson
/// last finished. What the learner's answers flag for repair appears beside
/// it on Home as "Worth revisiting", never in its place.
void main() {
  const next = NextLessonInfo(
    lesson: Lesson(
      id: 5,
      unitId: 1,
      orderInUnit: 5,
      title: 'Numbers and prices',
      description: '',
    ),
    unitTitle: 'Everyday Czech',
  );
  const repair = NextLessonInfo(
    lesson: Lesson(
      id: 3,
      unitId: 1,
      orderInUnit: 3,
      title: 'Ordering a coffee',
      description: '',
    ),
    unitTitle: 'Everyday Czech',
    kind: LearningRouteKind.independentRepair,
    completed: true,
  );

  group('revisitLessonProvider', () {
    Future<NextLessonInfo?> revisit({
      required NextLessonInfo? pick,
      required NextLessonInfo? continuing,
    }) async {
      final container = ProviderContainer(
        overrides: [
          nextLessonProvider.overrideWith((ref) async => pick),
          continueLessonProvider.overrideWith((ref) async => continuing),
        ],
      );
      addTearDown(container.dispose);
      return container.read(revisitLessonProvider.future);
    }

    test('a finished lesson marked for repair is worth revisiting', () async {
      expect((await revisit(pick: repair, continuing: next))?.lesson.id, 3);
    });

    test('never the lesson that is already next', () async {
      expect(await revisit(pick: repair, continuing: repair), isNull);
    });

    test('not new work — that is what continuing is for', () async {
      expect(await revisit(pick: next, continuing: null), isNull);
    });

    test('not an unfinished lesson, even when marked for repair', () async {
      const unfinished = NextLessonInfo(
        lesson: Lesson(
          id: 4,
          unitId: 1,
          orderInUnit: 4,
          title: 'Asking the way',
          description: '',
        ),
        unitTitle: 'Everyday Czech',
        kind: LearningRouteKind.supportRepair,
      );
      expect(await revisit(pick: unfinished, continuing: next), isNull);
    });

    test('not a finished lesson that is simply being kept fresh', () async {
      const maintained = NextLessonInfo(
        lesson: Lesson(
          id: 2,
          unitId: 1,
          orderInUnit: 2,
          title: 'Greetings',
          description: '',
        ),
        unitTitle: 'Everyday Czech',
        kind: LearningRouteKind.maintain,
        completed: true,
      );
      expect(await revisit(pick: maintained, continuing: next), isNull);
    });
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    required NextLessonInfo? revisit,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gamificationProvider.overrideWith(TestGamificationNotifier.new),
          continueLessonProvider.overrideWith((ref) async => next),
          revisitLessonProvider.overrideWith((ref) async => revisit),
          nextLessonProvider.overrideWith((ref) async => repair),
          dueCardCountProvider.overrideWith((ref) async => 0),
          dueTransferProvider.overrideWith((ref) async => []),
          czechTtsAvailableProvider.overrideWith((ref) async => true),
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

  testWidgets('Home continues with the next lesson, not the repair pick', (
    tester,
  ) async {
    await pumpHome(tester, revisit: null);

    expect(find.text('Numbers and prices'), findsOneWidget);
    expect(find.text('Ordering a coffee'), findsNothing);
    expect(find.textContaining('Worth revisiting'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a weak spot shows as its own card beside the next lesson', (
    tester,
  ) async {
    await pumpHome(tester, revisit: repair);

    expect(find.text('Numbers and prices'), findsOneWidget);
    expect(find.text('Ordering a coffee'), findsOneWidget);
    expect(
      find.text('Worth revisiting · some answers were missed without help'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
