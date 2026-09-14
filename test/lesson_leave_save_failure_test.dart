import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/services/lesson_checkpoint_store.dart';
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

/// Leave saves the lesson's place first. When this phone cannot store it,
/// the learner is told — and still has a way out.
void main() {
  testWidgets('a failed save says so and still lets the learner leave', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: '/',
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
          lessonCheckpointStoreProvider.overrideWithValue(_FullStorage()),
        ],
        child: MaterialApp.router(
          theme: lightTheme(),
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
        ),
      ),
    );
    router.push('/lesson');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsNothing, reason: 'not left silently');
    expect(find.text('Couldn’t save your place on this phone.'), findsWidgets);

    await tester.tap(find.text('Leave without saving'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

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

class _FullStorage extends LessonCheckpointStore {
  @override
  Future<void> write(int lessonId, Map<String, dynamic>? checkpoint) async {
    throw StateError('No space left on device');
  }
}

class _Tts implements CzechTts {
  @override
  final usingFallbackVoice = ValueNotifier(false);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
