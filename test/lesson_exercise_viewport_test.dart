import 'dart:convert';
import 'dart:io';

import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:ceskina_pro/presentation/widgets/common/lesson_ui.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

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
          _loadShippedExercises()
              .where((exercise) => boundedTypes.contains(exercise.type))
              .toList();

      expect(exercises, hasLength(68));

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

      final exercises = _loadShippedExercises();

      expect(exercises, hasLength(772));

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
}

List<Exercise> _loadShippedExercises() {
  const supportedAssetTypes = {
    'multiple_choice',
    'fill_blank',
    'translation',
    'dictation',
    'pronunciation',
    'dialogue',
    'matching',
    'error_correction',
    'reading_comprehension',
    'listening_comprehension',
    'writing_task',
    'speaking_task',
    'declension_table',
    'word_order',
    'teaching',
  };
  final lessonFiles =
      Directory('assets/curriculum/lessons')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  return [
    for (final file in lessonFiles)
      for (final raw
          in (jsonDecode(file.readAsStringSync())
                  as Map<String, dynamic>)['exercises']
              as List<dynamic>)
        if (supportedAssetTypes.contains((raw as Map)['type']))
          _exerciseFromAsset(Map<String, dynamic>.from(raw)),
  ];
}

Exercise _exerciseFromAsset(Map<String, dynamic> json) {
  return Exercise(
    id: json['id'] as int,
    lessonId: json['lesson_id'] as int,
    type: switch (json['type'] as String) {
      'multiple_choice' => ExerciseType.multipleChoice,
      'fill_blank' => ExerciseType.fillBlank,
      'translation' => ExerciseType.translation,
      'dictation' => ExerciseType.dictation,
      'pronunciation' => ExerciseType.pronunciation,
      'dialogue' => ExerciseType.dialogue,
      'matching' => ExerciseType.matching,
      'error_correction' => ExerciseType.errorCorrection,
      'reading_comprehension' => ExerciseType.readingComprehension,
      'listening_comprehension' => ExerciseType.listeningComprehension,
      'writing_task' => ExerciseType.writingTask,
      'speaking_task' => ExerciseType.speakingTask,
      'declension_table' => ExerciseType.declensionTable,
      'word_order' => ExerciseType.wordOrder,
      'teaching' => ExerciseType.teaching,
      final unsupported =>
        throw FormatException('Unsupported exercise type: $unsupported'),
    },
    prompt: json['prompt'] as String,
    data: Map<String, dynamic>.from(json['data'] as Map),
    answerKey: switch (json['answer_key']) {
      null => null,
      final String value => value,
      final value => jsonEncode(value),
    },
    grammarRuleId: json['grammar_rule_id'] as String?,
    xpReward: json['xp_reward'] as int? ?? 10,
  );
}
