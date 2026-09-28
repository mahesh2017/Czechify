import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/widgets/common/lesson_ui.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/reading_comprehension_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';
import 'support/slides.dart';

/// The passage, then its questions on slides; these cover the answering path
/// through them.
OptionState stateOf(WidgetTester tester, String option) => tester
    .widget<QuizOptionTile>(
      find.ancestor(of: find.text(option), matching: find.byType(QuizOptionTile)),
    )
    .state;

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
    await tester.pumpAndSettle();

    expect(find.text('Dnes je hezky.'), findsOneWidget);
    await toLastSlide(tester);

    await tester.tap(find.text('Nice'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(result?.isCorrect, isTrue);
    expect(stateOf(tester, 'Nice'), OptionState.correct);
  });

  testWidgets('a wrong answer reports and shows the verdict', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(reading(onAnswered: (value) => result = value));
    await toLastSlide(tester);

    await tester.tap(find.text('Bad'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(result?.isCorrect, isFalse);
    // The learner's answer marked wrong, the right one shown.
    expect(stateOf(tester, 'Bad'), OptionState.wrong);
    expect(stateOf(tester, 'Nice'), OptionState.correct);
  });
}
