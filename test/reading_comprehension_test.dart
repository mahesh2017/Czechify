import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/reading_comprehension_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// The passage, the questions and the verdict all share one scrollable, with
/// only the Check action pinned. These cover the answering path through it.
void main() {
  Widget reading({required void Function(ExerciseResult) onAnswered}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: ReadingComprehensionView(
              exercise: const Exercise(
                id: 1,
                lessonId: 1,
                type: ExerciseType.readingComprehension,
                prompt: 'Read the passage.',
                data: {
                  'text_cz': 'Dnes je hezky.',
                  'questions': [
                    {
                      'question_en': 'What is the weather?',
                      'options': ['Nice', 'Bad'],
                      'correct_index': 0,
                    },
                  ],
                },
              ),
              onAnswered: onAnswered,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('answering correctly reports and shows the verdict', (
    tester,
  ) async {
    ExerciseResult? result;
    await tester.pumpWidget(reading(onAnswered: (value) => result = value));

    expect(find.text('Dnes je hezky.'), findsOneWidget);

    await tester.tap(find.text('Nice'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(result?.isCorrect, isTrue);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('a wrong answer reports and shows the verdict', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(reading(onAnswered: (value) => result = value));

    await tester.tap(find.text('Bad'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(result?.isCorrect, isFalse);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
