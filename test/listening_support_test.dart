import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/learning_evidence.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/listening_comprehension_view.dart';
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
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(result?.isCorrect, isTrue);
    expect(result?.supports, contains(SupportKind.transcript));
  });

  testWidgets('replaying the audio is recorded as support', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(_listening(onAnswered: (value) => result = value));

    // The first play is the learner's own; the second is the one that means
    // they needed to hear it again.
    await tester.tap(find.text('Listen'));
    await tester.pump();
    await tester.tap(find.text('Play it again'));
    await tester.pump();

    await tester.tap(find.text('Coffee'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(result?.supports, contains(SupportKind.replay));
  });

  testWidgets('the slower control also counts as a play', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(_listening(onAnswered: (value) => result = value));

    await tester.tap(find.text('Listen'));
    await tester.pump();
    await tester.tap(find.text('Slower'));
    await tester.pump();

    await tester.tap(find.text('Coffee'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(result?.supports, contains(SupportKind.replay));
  });

  testWidgets('needing the audio twice counts, even after autoplay', (
    tester,
  ) async {
    ExerciseResult? result;
    await tester.pumpWidget(_listening(onAnswered: (value) => result = value));

    // Let the automatic play happen — the learner has now heard it once,
    // without having chosen to.
    await tester.pump(kListenAutoPlayDelay);
    await tester.pump();

    // One chosen play after that is a second hearing, and that is exactly
    // what SupportKind.replay is evidence of. Counting only `_playCount > 1`
    // ignored the automatic play and filed this learner as unaided.
    await tester.tap(find.text('Play it again'));
    await tester.pump();

    await tester.tap(find.text('Coffee'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(result?.supports, contains(SupportKind.replay));
  });

  testWidgets('one play with no autoplay is not a replay', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(_listening(onAnswered: (value) => result = value));

    // No autoplay has run, so this is the learner's first hearing.
    await tester.tap(find.text('Listen'));
    await tester.pump();

    await tester.tap(find.text('Coffee'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(result?.supports, isNot(contains(SupportKind.replay)));
  });

  testWidgets('an exercise with no questions still shows its audio', (
    tester,
  ) async {
    await tester.pumpWidget(
      _listening(questions: const [], onAnswered: (_) {}),
    );

    // The header travels with the questions now, so the empty state has to
    // carry it too — otherwise the learner loses the prompt and the audio.
    expect(find.text('What is the speaker asking for?'), findsOneWidget);
    expect(find.text('Listen'), findsOneWidget);
    expect(find.textContaining('no questions'), findsOneWidget);
  });
}

/// One listening exercise, sized like a real lesson slot.
Widget _listening({
  required void Function(ExerciseResult) onAnswered,
  List<Map<String, Object>> questions = const [
    {
      'question_en': 'What do they want?',
      'options': ['Coffee', 'Tea'],
      'correct_index': 0,
    },
  ],
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(
        body: SizedBox(
          height: 700,
          child: ListeningComprehensionView(
            exercise: Exercise(
              id: 1,
              lessonId: 1,
              type: ExerciseType.listeningComprehension,
              prompt: 'What is the speaker asking for?',
              data: {
                'transcript_cz': 'Prosím jedno kafe.',
                'questions': questions,
              },
            ),
            onAnswered: onAnswered,
          ),
        ),
      ),
    ),
  );
}
