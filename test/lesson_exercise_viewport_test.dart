import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:czechify/presentation/widgets/common/lesson_ui.dart';
import 'package:czechify/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';
import 'support/shipped_exercises.dart';

void main() {
  const boundedTypes = {
    ExerciseType.matching,
    ExerciseType.errorCorrection,
    ExerciseType.readingComprehension,
    ExerciseType.listeningComprehension,
    ExerciseType.writingTask,
  };

  test('only internally scrolling exercise types request bounded height', () {
    for (final type in ExerciseType.values) {
      expect(
        LessonExerciseViewport.usesBoundedHeight(type),
        boundedTypes.contains(type),
        reason: 'Unexpected lesson viewport behavior for ${type.name}',
      );
    }
  });

  testWidgets(
    'all shipped internally scrolling exercises render in the lesson viewport',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final exercises =
          loadShippedExercises()
              .where((exercise) => boundedTypes.contains(exercise.type))
              .toList();

      expect(exercises, hasLength(478));

      for (final exercise in exercises) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              theme: lightTheme(),
              home: Scaffold(
                body: LessonExerciseViewport(
                  exercise: exercise,
                  onAnswered: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'Exercise ${exercise.id} (${exercise.type.name}) failed in the '
              'production lesson viewport',
        );
      }
    },
  );

  testWidgets(
    'all shipped exercise assets render through the production viewport',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final exercises = loadShippedExercises();

      expect(exercises, hasLength(1392));

      for (final exercise in exercises) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              theme: lightTheme(),
              home: Scaffold(
                body: LessonExerciseViewport(
                  exercise: exercise,
                  onAnswered: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'Exercise ${exercise.id} (${exercise.type.name}) failed in the '
              'production lesson viewport',
        );
      }
    },
  );

  testWidgets('dialogue checks every blank against its own alternatives', (
    tester,
  ) async {
    ExerciseResult? result;
    const exercise = Exercise(
      id: 999001,
      lessonId: 999,
      type: ExerciseType.dialogue,
      prompt: 'Complete the dialogue',
      data: {
        'type': 'dialogue',
        'lines': [
          {'speaker': 'Clerk', 'text': 'Dobrý den.'},
          {'speaker': 'you', 'text': '___, ___ prosím.'},
        ],
        'blank_answers': [
          ['Dobrý den', 'Dobré ráno'],
          ['jedno kafe', 'jednu kávu'],
        ],
      },
      xpReward: 10,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          theme: lightTheme(),
          home: Scaffold(
            body: LessonExerciseViewport(
              exercise: exercise,
              onAnswered: (value) => result = value,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(2));
    // Check stays disabled until every blank has something in it.
    expect(tester.widget<KeyCta>(find.byType(KeyCta)).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'Dobré ráno');
    await tester.enterText(find.byType(TextField).at(1), 'jednu kávu');
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(result?.isCorrect, isTrue);
    expect(result?.correctAnswer, 'Dobrý den | jedno kafe');
  });

  testWidgets('fill blank checks independent alternatives for every blank', (
    tester,
  ) async {
    ExerciseResult? result;
    const exercise = Exercise(
      id: 999002,
      lessonId: 999,
      type: ExerciseType.fillBlank,
      prompt: 'Complete',
      data: {
        'type': 'fill_blank',
        'sentence': 'Ráno ___ a potom ___.',
        'blank_count': 2,
        'blank_answers': [
          ['vstávám'],
          ['snídám', 'posnídám'],
        ],
      },
      xpReward: 10,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          theme: lightTheme(),
          home: Scaffold(
            body: LessonExerciseViewport(
              exercise: exercise,
              onAnswered: (value) => result = value,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'vstávám');
    await tester.enterText(find.byType(TextField).at(1), 'posnídám');
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(result?.isCorrect, isTrue);
    expect(result?.correctAnswer, 'vstávám, snídám');
  });

  testWidgets('fill blank keyboard advances before submitting all blanks', (
    tester,
  ) async {
    ExerciseResult? result;
    const exercise = Exercise(
      id: 999003,
      lessonId: 999,
      type: ExerciseType.fillBlank,
      prompt: 'Complete',
      data: {
        'type': 'fill_blank',
        'sentence': 'Ráno ___ a potom ___.',
        'blank_count': 2,
        'blank_answers': [
          ['vstávám'],
          ['snídám'],
        ],
      },
      xpReward: 10,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          theme: lightTheme(),
          home: Scaffold(
            body: LessonExerciseViewport(
              exercise: exercise,
              onAnswered: (value) => result = value,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'vstávám');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    expect(result, isNull);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(
      tester.widget<TextField>(find.byType(TextField).last).focusNode?.hasFocus,
      isTrue,
    );

    await tester.enterText(find.byType(TextField).last, 'snídám');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(result?.isCorrect, isTrue);
  });
}
