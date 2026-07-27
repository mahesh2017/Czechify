import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/domain/entities/learning_evidence.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/listening_comprehension_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

void main() {
  testWidgets('listening starts gist-first and records transcript support', (
    tester,
  ) async {
    ExerciseResult? result;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: ListeningComprehensionView(
                exercise: const Exercise(
                  id: 1,
                  lessonId: 1,
                  type: ExerciseType.listeningComprehension,
                  prompt: 'What is the speaker asking for?',
                  data: {
                    'transcript_cz': 'Prosím jedno kafe.',
                    'questions': [
                      {
                        'question_en': 'What do they want?',
                        'options': ['Coffee', 'Tea'],
                        'correct_index': 0,
                      },
                    ],
                  },
                ),
                onAnswered: (value) => result = value,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Prosím jedno kafe.'), findsNothing);
    await tester.tap(find.text('Reveal transcript'));
    await tester.pump();
    expect(find.text('Prosím jedno kafe.'), findsOneWidget);

    await tester.tap(find.text('Coffee'));
    await tester.pump();
    await tester.tap(find.text('Check Answers'));
    await tester.pump();

    expect(result?.isCorrect, isTrue);
    expect(result?.supports, contains(SupportKind.transcript));
  });
}
