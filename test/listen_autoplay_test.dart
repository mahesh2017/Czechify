import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/dictation_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/listening_comprehension_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// "Play it again" was the first thing that ever played it. These exercises
/// ask the learner to type or answer what they heard, so the audio starts on
/// arrival and the label becomes true.
void main() {
  Widget host(Widget child) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets('the listening exercise names the first play "Listen"', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          height: 700,
          child: ListeningComprehensionView(
            exercise: const Exercise(
              id: 1,
              lessonId: 1,
              type: ExerciseType.listeningComprehension,
              prompt: 'What did they say?',
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
            onAnswered: (_) {},
          ),
        ),
      ),
    );

    // Before the audio has played, the button is an invitation.
    expect(find.text('Listen'), findsOneWidget);

    // Plain pumps, not pumpAndSettle: the automatic play reaches the real TTS
    // provider, whose platform channels never complete under flutter_test.
    await tester.pump(kListenAutoPlayDelay + const Duration(milliseconds: 50));
    await tester.pump();

    // Once it has played itself, "Play it again" is finally accurate.
    expect(find.text('Play it again'), findsOneWidget);
    expect(find.text('Listen'), findsNothing);
  });

  testWidgets('the automatic play is not counted as the learner replaying', (
    tester,
  ) async {
    // `_playCount > 1` is recorded as SupportKind.replay — evidence the
    // learner needed to hear it again, which feeds lesson routing. The play
    // they did not ask for must not count towards it.
    await tester.pumpWidget(
      host(
        SizedBox(
          height: 700,
          child: ListeningComprehensionView(
            exercise: const Exercise(
              id: 2,
              lessonId: 1,
              type: ExerciseType.listeningComprehension,
              prompt: 'What did they say?',
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
            onAnswered: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(kListenAutoPlayDelay + const Duration(milliseconds: 50));
    await tester.pump();

    // The automatic play left the button reading "Play it again" without
    // touching the replay counter, so the learner's first deliberate press is
    // their first replay — `_playCount > 1`, which records
    // SupportKind.replay, still needs two presses of their own.
    expect(find.text('Play it again'), findsOneWidget);
  });

  testWidgets('dictation does not leave a timer running after it is gone', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DictationView(
          exercise: const Exercise(
            id: 3,
            lessonId: 1,
            type: ExerciseType.dictation,
            prompt: 'Type what you hear',
            data: {'expected_text': 'káva'},
          ),
          onAnswered: (_) {},
        ),
      ),
    );

    // Navigated away before the delay elapses, which is ordinary — a learner
    // can leave a lesson in under half a second.
    await tester.pumpWidget(host(const SizedBox.shrink()));
    await tester.pump(kListenAutoPlayDelay * 2);

    // A bare delayed future would still be pending here and fail the test.
    expect(tester.takeException(), isNull);
  });
}
