import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/error_correction_view.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// The explanation scrolls with the sentence rather than being pinned beneath
/// it, so a long one cannot push the exercise out of its box. This covers the
/// path that shows it.
void main() {
  Widget errorCorrection({required void Function(ExerciseResult) onAnswered}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: ErrorCorrectionView(
              exercise: const Exercise(
                id: 1,
                lessonId: 1,
                type: ExerciseType.errorCorrection,
                prompt: 'Find the mistake in this sentence.',
                data: {
                  'sentence_cz': 'Ty musí jít domů.',
                  'correct_sentence_cz': 'Ty musíš jít domů.',
                  'explanation': 'The 2nd person singular of muset is musíš.',
                },
              ),
              onAnswered: onAnswered,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping the wrong word explains the correction', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(
      errorCorrection(onAnswered: (value) => result = value),
    );

    // Tapping a word selects it; Check submits the selection.
    await tester.tap(find.text('musí'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.isCorrect, isTrue);
    expect(
      find.textContaining('musíš'),
      findsWidgets,
      reason: 'the explanation and correction should be on screen',
    );
  });

  testWidgets('tapping a correct word still explains the answer', (
    tester,
  ) async {
    ExerciseResult? result;
    await tester.pumpWidget(
      errorCorrection(onAnswered: (value) => result = value),
    );

    await tester.tap(find.text('domů.'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.isCorrect, isFalse);
    expect(find.textContaining('musíš'), findsWidgets);
  });
}
