import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/writing_task_view.dart';
import 'package:czechify/presentation/widgets/common/lesson_ui.dart';
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

    expect(find.text('0 words'), findsOneWidget);
    expect(tester.widget<KeyCta>(find.byType(KeyCta)).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Dobrý den');
    await tester.pump();
    expect(find.text('2 words'), findsOneWidget);
    expect(tester.widget<KeyCta>(find.byType(KeyCta)).onPressed, isNotNull);
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

  /// Writing is never scored, so the "correct" branch of the old feedback
  /// panel was unreachable and every learner finished every task on a red
  /// failure card. With an answer key present — as all 97 shipped writing
  /// tasks have — it also announced "Key phrases not found", a check no code
  /// ever ran: submitting the answer key verbatim still produced it.
  testWidgets('a task with an answer key ends neutrally, not as a failure', (
    tester,
  ) async {
    const answerKey = 'Dobrý den, potřebuji pomoc.';

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
              answerKey: answerKey,
              data: {'min_words': 2},
            ),
            onAnswered: (_) {},
          ),
        ),
      ),
    );

    // The answer key itself — the strongest possible submission.
    await tester.enterText(find.byType(TextField).first, answerKey);
    await tester.pump();
    await tester.tap(find.text('Review draft'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, answerKey);
    await tester.tap(find.text('Submit revision'));
    await tester.pump();

    expect(find.text('Writing cycle complete'), findsOneWidget);
    expect(find.text('Key phrases not found'), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(
      find.textContaining('Automatic keyword check'),
      findsNothing,
      reason: 'no keyword check runs, so nothing may claim one did',
    );
  });
}
