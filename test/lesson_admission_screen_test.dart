import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/presentation/providers/course_admission_providers.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/lesson_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/lesson/lesson_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localized_app.dart';

/// A lesson that may not start says why, and never begins an attempt.
class _Session extends LessonSessionNotifier {
  int loads = 0;
  @override
  LessonSessionState build() => const LessonSessionState();
  @override
  Future<void> loadLesson(int lessonId) async => loads++;
}

class _Tts implements CzechTts {
  @override
  final usingFallbackVoice = ValueNotifier(false);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_Session> open(WidgetTester tester, LessonAdmission admission) async {
    SharedPreferences.setMockInitialValues({});
    final session = _Session();
    final router = GoRouter(
      initialLocation: '/lesson',
      routes: [
        GoRoute(
          path: '/lesson',
          builder: (_, _) => const LessonPlayerScreen(lessonId: 1),
        ),
        GoRoute(
          path: '/upgrade',
          builder:
              (_, state) => Scaffold(
                body: Text('Upgrade for ${state.uri.queryParameters['unit']}'),
              ),
        ),
        GoRoute(
          path: '/curriculum',
          builder: (_, _) => const Scaffold(body: Text('Course map')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lessonSessionProvider.overrideWith(() => session),
          lessonAdmissionProvider(1).overrideWith((_) async => admission),
          lessonProvider(1).overrideWith(
            (_) async => const Lesson(
              id: 1,
              unitId: 4,
              orderInUnit: 1,
              title: 'Lesson',
              description: '',
            ),
          ),
          czechTtsProvider.overrideWithValue(_Tts()),
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
    return session;
  }

  testWidgets('an unpaid lesson leads to the options for its unit', (
    tester,
  ) async {
    final session = await open(tester, LessonAdmission.paymentRequired);
    expect(find.text('Part of the full course'), findsOneWidget);
    expect(session.loads, 0);
    await tester.tap(find.text('See your options'));
    await tester.pumpAndSettle();
    expect(find.text('Upgrade for 4'), findsOneWidget);
  });

  testWidgets('offline past the lease asks to reconnect, not to pay', (
    tester,
  ) async {
    final session = await open(tester, LessonAdmission.reverificationRequired);
    expect(find.text('Connect to confirm your access'), findsOneWidget);
    expect(find.text('Part of the full course'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(session.loads, 0);
  });

  testWidgets('an unfinished prerequisite keeps the old message', (
    tester,
  ) async {
    await open(tester, LessonAdmission.prerequisiteRequired);
    expect(find.text('Not open yet'), findsOneWidget);
    await tester.tap(find.text('Back to curriculum'));
    await tester.pumpAndSettle();
    expect(find.text('Course map'), findsOneWidget);
  });

  testWidgets('an account switch in progress is its own state', (tester) async {
    await open(tester, LessonAdmission.accountTransition);
    expect(find.text('Switching accounts…'), findsOneWidget);
  });

  testWidgets('an admitted lesson loads', (tester) async {
    final session = await open(tester, LessonAdmission.allowed);
    expect(session.loads, 1);
  });
}
