import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/listening_comprehension_view.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/matching_view.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/writing_task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// Once an exercise has handed its answer to the lesson, a second attempt is
/// the lesson's to offer: its Try again costs a heart and follows the feedback
/// ladder. These views used to carry their own Retry or Try again after
/// submitting, which cleared the answer for a re-answer the lesson ignored —
/// never recorded, never costing anything — and sat right beside the lesson's
/// own Try again.
void main() {
  Widget host(Widget child) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(body: SizedBox(height: 700, child: child)),
    ),
  );

  testWidgets('a checked listening question offers no retry of its own', (
    tester,
  ) async {
    ExerciseResult? result;
    await tester.pumpWidget(
      host(
        ListeningComprehensionView(
          exercise: const Exercise(
            id: 1,
            lessonId: 1,
            type: ExerciseType.listeningComprehension,
            prompt: 'Which order did you hear?',
            data: {
              'transcript_cz': 'káva, čaj',
              'questions': [
                {
                  'question_en': 'What was the order?',
                  'options': ['coffee — tea', 'tea — coffee'],
                  'correct_index': 0,
                },
              ],
            },
          ),
          onAnswered: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.text('tea — coffee'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(result?.isCorrect, isFalse, reason: 'the miss reached the lesson');
    expect(find.text('0/1 correct'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a listening task with no questions offers no retry either', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ListeningComprehensionView(
          exercise: const Exercise(
            id: 2,
            lessonId: 1,
            type: ExerciseType.listeningComprehension,
            prompt: 'Listen',
            data: {'transcript_cz': 'Dobrý den.', 'questions': []},
          ),
          onAnswered: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('wrongly submitted pairs offer no retry of their own', (
    tester,
  ) async {
    ExerciseResult? result;
    await tester.pumpWidget(
      host(
        MatchingView(
          exercise: const Exercise(
            id: 3,
            lessonId: 1,
            type: ExerciseType.matching,
            prompt: 'Match the words',
            data: {
              'pairs': [
                {'left': 'káva', 'right': 'coffee'},
                {'left': 'čaj', 'right': 'tea'},
              ],
            },
          ),
          onAnswered: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.text('káva'));
    await tester.pump();
    await tester.tap(find.text('tea'));
    await tester.pump();
    await tester.tap(find.text('čaj'));
    await tester.pump();
    await tester.tap(find.text('coffee'));
    await tester.pump();

    expect(result?.isCorrect, isFalse, reason: 'the miss reached the lesson');
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a submitted writing task offers no rewrite of its own', (
    tester,
  ) async {
    ExerciseResult? result;
    await tester.pumpWidget(
      host(
        WritingTaskView(
          exercise: const Exercise(
            id: 4,
            lessonId: 1,
            type: ExerciseType.writingTask,
            prompt: 'Write to your landlord.',
            answerKey: 'Dobrý den, potřebuji pomoc.',
            data: {'min_words': 2},
          ),
          onAnswered: (value) => result = value,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Dobrý den');
    await tester.pump();
    await tester.tap(find.text('Review draft'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField).first,
      'Dobrý den, potřebuji pomoc.',
    );
    await tester.tap(find.text('Submit revision'));
    await tester.pump();

    expect(result?.outcome, ExerciseOutcome.skipped);
    expect(find.text('Writing cycle complete'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });
}
