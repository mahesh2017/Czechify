import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/widgets/lesson/exercise_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// The exercise views gained motion for the states a learner actually drives:
/// a pair snapping together, an order being checked. Rendering them is not
/// enough to know those states still work, so these drive the interaction.
void main() {
  Future<List<ExerciseResult>> pump(
    WidgetTester tester,
    ExerciseType type,
    Map<String, dynamic> data, {
    bool reduceMotion = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final answers = <ExerciseResult>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(
              body: ExerciseWidget(
                exercise: Exercise(
                  id: 1,
                  lessonId: 1,
                  type: type,
                  prompt: 'Prompt',
                  data: data,
                ),
                onAnswered: answers.add,
              ),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return answers;
  }

  const matchingData = {
    'pairs': [
      {'left': 'ahoj', 'right': 'hello'},
      {'left': 'nazdar', 'right': 'hi'},
    ],
  };

  const wordOrderData = {
    'words': ['Já', 'jsem', 'student'],
    'correct_order': [0, 1, 2],
  };

  testWidgets('a completed pair is badged with its number', (tester) async {
    await pump(tester, ExerciseType.matching, matchingData);

    await tester.tap(find.text('ahoj'));
    await tester.pump();
    await tester.tap(find.text('hello'));
    await tester.pumpAndSettle();

    // Both halves carry the same badge, which is what tells the learner which
    // pair they just made rather than merely that something happened.
    expect(
      find.byKey(const ValueKey('match-badge-left-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('match-badge-right-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pair badge appears immediately with reduced motion', (
    tester,
  ) async {
    await pump(
      tester,
      ExerciseType.matching,
      matchingData,
      reduceMotion: true,
    );

    await tester.tap(find.text('nazdar'));
    await tester.pump();
    await tester.tap(find.text('hi'));
    await tester.pump();

    // One pump, no settling: the badge is there as soon as the pair is made
    // rather than arriving on the far side of an entrance.
    expect(find.byKey(const ValueKey('match-badge-left-1')), findsOneWidget);
  });

  testWidgets('a full word order is checked as correct', (tester) async {
    final answers = await pump(
      tester,
      ExerciseType.wordOrder,
      wordOrderData,
    );

    for (final word in const ['Já', 'jsem', 'student']) {
      await tester.tap(find.text(word).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(answers.single.isCorrect, isTrue);
  });

  testWidgets('a wrong word order is checked as wrong', (tester) async {
    final answers = await pump(
      tester,
      ExerciseType.wordOrder,
      wordOrderData,
    );

    for (final word in const ['student', 'jsem', 'Já']) {
      await tester.tap(find.text(word).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(answers.single.isCorrect, isFalse);
  });

  testWidgets('a partly wrong comprehension answer reports the score', (
    tester,
  ) async {
    final answers = await pump(
      tester,
      ExerciseType.listeningComprehension,
      const {
        'text_cz': 'Dnes je hezky.',
        'questions': [
          {
            'question_en': 'How is the weather?',
            'options': ['Nice', 'Bad'],
            'correct_index': 0,
          },
        ],
      },
    );

    await tester.tap(find.text('Bad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check answers'));
    await tester.pumpAndSettle();

    // Getting it wrong has to say how many were right, not just that the set
    // was not perfect.
    expect(find.textContaining('0/1'), findsWidgets);
    expect(answers.single.isCorrect, isFalse);
  });

  // The illustrated teacher rides on the intro block, so the card needs an
  // intro before there is a teacher to animate at all.
  const illustratedTeaching = {
    'heading': 'The Czech Alphabet',
    'intro': 'Czech spelling is regular: each letter keeps one sound.',
    'items': [
      {'symbol': 'a', 'sound': 'like u in cup', 'example': 'matka'},
    ],
  };

  testWidgets('the illustrated teacher bobs while it is on screen', (
    tester,
  ) async {
    await pump(
      tester,
      ExerciseType.teaching,
      illustratedTeaching,
      settle: false,
    );

    // The bob repeats for as long as the card is shown, so it is still
    // scheduling frames rather than settling.
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 650));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('the illustrated teacher holds still with reduced motion', (
    tester,
  ) async {
    await pump(
      tester,
      ExerciseType.teaching,
      illustratedTeaching,
      reduceMotion: true,
      settle: false,
    );

    // Parked at the midpoint of the bob, which is its rest position, and not
    // costing a frame for a learner who asked for less movement.
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 650));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
