import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/engines/daily_arrival_engine.dart';
import 'package:czechify/presentation/providers/daily_arrival_providers.dart';
import 'package:czechify/presentation/screens/arrival/daily_arrival_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const reviewState = DailyArrivalState(
    kind: DailyArrivalKind.reviewsReady,
    learnerName: 'Mahesh',
    streak: 6,
    dailyXp: 10,
    dailyGoalXp: 50,
    dueReviews: 8,
    lessonId: 101,
    lessonTitle: 'Greetings and introductions',
    unitTitle: 'Unit 1 · First conversations',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(WidgetTester tester, {bool reduceMotion = false}) async {
    final router = GoRouter(
      initialLocation: '/arrival',
      routes: [
        GoRoute(
          path: '/arrival',
          builder:
              (_, __) => MediaQuery(
                data: MediaQueryData(disableAnimations: reduceMotion),
                child: const DailyArrivalScreen(),
              ),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home destination')),
        ),
        GoRoute(
          path: '/review',
          builder: (_, __) => const Scaffold(body: Text('Review destination')),
        ),
        GoRoute(
          path: '/lesson/:id',
          builder:
              (_, state) =>
                  Scaffold(body: Text('Lesson ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyArrivalStateProvider.overrideWith((_) async => reviewState),
          dailyArrivalClockProvider.overrideWithValue(
            () => DateTime(2026, 8, 2, 8),
          ),
        ],
        child: MaterialApp.router(theme: lightTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders personalized action and records today’s impression', (
    tester,
  ) async {
    await mount(tester, reduceMotion: true);

    expect(find.text('8 words are ready for you, Mahesh'), findsOneWidget);
    expect(find.text('Review now'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(dailyArrivalShownDayKey), '2026-08-02');
  });

  testWidgets('primary review action opens the review flow', (tester) async {
    await mount(tester);

    await tester.ensureVisible(find.text('Review now'));
    await tester.tap(find.text('Review now'));
    await tester.pumpAndSettle();

    expect(find.text('Review destination'), findsOneWidget);
  });

  testWidgets('secondary action always offers a direct route to Home', (
    tester,
  ) async {
    await mount(tester);

    await tester.ensureVisible(find.text('Go to Home'));
    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home destination'), findsOneWidget);
  });

  testWidgets('fits a compact phone without layout overflow', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await mount(tester, reduceMotion: true);

    expect(tester.takeException(), isNull);
    expect(find.text('Review now'), findsOneWidget);
  });
}
