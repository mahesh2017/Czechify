import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/domain/entities/exercise_outcome.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/writing_task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

void main() {
  testWidgets('open writing requires draft and revision and stays unscored', (
    tester,
  ) async {
    ExerciseResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: WritingTaskView(
            exercise: const Exercise(
              id: 1,
              lessonId: 1,
              type: ExerciseType.writingTask,
              prompt: 'Write to your landlord.',
              data: {
                'min_words': 2,
                'key_vocab': ['prosím'],
              },
            ),
            onAnswered: (value) => result = value,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Dobrý den');
    await tester.tap(find.text('Review draft'));
    await tester.pump();
    expect(find.textContaining('Revise:'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Dobrý den, potřebuji pomoc.',
    );
    await tester.tap(find.text('Submit revision'));
    await tester.pump();

    expect(result?.outcome, ExerciseOutcome.skipped);
    expect(result?.isCorrect, isFalse);
    expect(result?.explanation, contains('You wrote 4 words.'));
    expect(find.text('Writing cycle complete'), findsOneWidget);
  });
}
