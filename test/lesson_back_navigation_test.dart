import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/lesson.dart';
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

class _Session extends LessonSessionNotifier {
  @override
  LessonSessionState build() => const LessonSessionState(
    lesson: Lesson(
      id: 1,
      unitId: 1,
      orderInUnit: 1,
      title: 'Practice',
      description: '',
    ),
    exercises: [
      Exercise(
        id: 1,
        lessonId: 1,
        type: ExerciseType.multipleChoice,
        prompt: 'Choose a greeting',
        data: {
          'options': ['Ahoj', 'Dům'],
          'correct_index': 0,
        },
      ),
    ],
  );

  @override
  Future<void> loadLesson(int lessonId) async {}
}

class _Tts implements CzechTts {
  @override
  final usingFallbackVoice = ValueNotifier(false);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final pushed in [false, true]) {
    testWidgets('system Back requires a decision (pushed: $pushed)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final router = GoRouter(
        initialLocation: pushed ? '/' : '/lesson',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/lesson',
            builder: (_, _) => const LessonPlayerScreen(lessonId: 1),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonSessionProvider.overrideWith(_Session.new),
            lessonUnlockedProvider(1).overrideWith((ref) async => true),
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
      if (pushed) router.push('/lesson');
      await tester.pumpAndSettle();
      expect(find.text('Choose a greeting'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Leave lesson?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a greeting'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
