import 'package:czechify/core/feedback/answer_streak.dart';
import 'package:czechify/core/feedback/sfx.dart';
import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/providers/feedback_providers.dart';
import 'package:czechify/presentation/widgets/common/lesson_ui.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:czechify/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feedback_service_test.dart' show RecordingHaptics, RecordingSfxPlayer;
import 'support/localized_app.dart';

/// The reward the learner meets ~790 times a course. These pin the two things
/// that would ruin it: adding a wait before they can continue, and paying out
/// the same way every time until it stops registering at all.
void main() {
  late RecordingSfxPlayer player;
  late RecordingHaptics haptics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = RecordingSfxPlayer();
    haptics = RecordingHaptics();
  });

  const question = Exercise(
    id: 1,
    lessonId: 1,
    type: ExerciseType.multipleChoice,
    prompt: 'Pick one',
    data: {
      'type': 'multiple_choice',
      'question_en': 'How do you say hello?',
      'options': ['Ahoj', 'Kočka'],
      'correct_index': 0,
    },
    xpReward: 10,
  );

  Future<ExerciseResult?> answer(
    WidgetTester tester, {
    int streak = 0,
    bool correctly = true,
    Exercise exercise = question,
    bool reduceMotion = false,
    bool invokeDirectly = false,
  }) async {
    ExerciseResult? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sfxPlayerProvider.overrideWithValue(player),
          hapticDriverProvider.overrideWithValue(haptics),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          theme: lightTheme(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(
              body: LessonExerciseViewport(
                exercise: exercise,
                answerStreak: streak,
                onAnswered: (value) => result = value,
              ),
            ),
          ),
        ),
      ),
    );
    if (invokeDirectly) {
      tester
          .widget<QuizOptionTile>(
            find.byType(QuizOptionTile).at(correctly ? 0 : 1),
          )
          .onTap!();
    } else {
      await tester.tap(find.text(correctly ? 'Ahoj' : 'Kočka'));
    }
    // Deliberately no settle: everything asserted below must already be true.
    await tester.pump();
    return result;
  }

  group('the answer is never held up by its own celebration', () {
    testWidgets('the lesson is told immediately, not after the animation', (
      tester,
    ) async {
      // A 700 ms reaction fired ~790 times would add nine minutes of waiting
      // across the course if the learner had to sit through it.
      final result = await answer(tester);
      expect(result, isNotNull);
      expect(result!.isCorrect, isTrue);
    });

    testWidgets('the reaction clears itself without being dismissed', (
      tester,
    ) async {
      await answer(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion leaves no invisible reaction ticker', (
      tester,
    ) async {
      // Invoke the option directly so InkWell's platform ripple does not get
      // mistaken for an exercise-reaction ticker.
      await answer(tester, reduceMotion: true, invokeDirectly: true);

      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('the reward escalates with a run', () {
    testWidgets('the first correct answer plays the lowest note', (
      tester,
    ) async {
      await answer(tester, streak: 0);
      expect(player.played, [Sfx.correct1]);
    });

    testWidgets('the second steps up', (tester) async {
      await answer(tester, streak: 1);
      expect(player.played, [Sfx.correct2]);
    });

    testWidgets('a milestone replaces the note instead of stacking on it', (
      tester,
    ) async {
      // Two clips firing together mix into mud rather than reading as bigger.
      await answer(tester, streak: 2);
      expect(player.played, [Sfx.combo]);
    });

    testWidgets('past a milestone it returns to the top note', (tester) async {
      await answer(tester, streak: 3);
      expect(player.played, [Sfx.correct3]);
    });

    testWidgets('a milestone shows the run on screen', (tester) async {
      await answer(tester, streak: 4);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(AnswerStreak.label(5)), findsOneWidget);
    });

    testWidgets('an ordinary correct answer shows no chip', (tester) async {
      await answer(tester, streak: 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('v řadě'), findsNothing);
    });
  });

  group('a wrong answer is a nudge, not a penalty', () {
    testWidgets('one viewport translation owns the displacement', (
      tester,
    ) async {
      await answer(tester, correctly: false);
      expect(
        find.byKey(const ValueKey('answer-reaction-translation')),
        findsOneWidget,
      );
    });

    testWidgets('it plays the soft low sound', (tester) async {
      await answer(tester, correctly: false);
      expect(player.played, [Sfx.wrong]);
    });

    testWidgets('it is felt more than a correct answer, not less', (
      tester,
    ) async {
      await answer(tester, correctly: false);
      expect(haptics.fired, [Haptic.medium]);
    });

    testWidgets('it breaks no promise about the streak sound', (tester) async {
      // A wrong answer at streak 9 must not still play the milestone.
      await answer(tester, streak: 9, correctly: false);
      expect(player.played, [Sfx.wrong]);
    });
  });

  testWidgets('teaching cards get no verdict', (tester) async {
    // Congratulating someone for reading a card devalues the sound that means
    // "you got it right".
    const card = Exercise(
      id: 2,
      lessonId: 1,
      type: ExerciseType.teaching,
      prompt: 'New words',
      data: {
        'type': 'teaching',
        'phrases': [
          {'cz': 'Ahoj', 'en': 'Hello'},
        ],
      },
      xpReward: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sfxPlayerProvider.overrideWithValue(player),
          hapticDriverProvider.overrideWithValue(haptics),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          theme: lightTheme(),
          home: Scaffold(
            body: LessonExerciseViewport(exercise: card, onAnswered: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(player.played, isEmpty);
  });

  testWidgets('reduce motion keeps the sound and drops only the movement', (
    tester,
  ) async {
    // Someone who asked the OS for less movement did not ask for a less
    // rewarding app.
    final result = await answer(tester, reduceMotion: true);
    expect(result!.isCorrect, isTrue);
    expect(player.played, [Sfx.correct1]);
    expect(haptics.fired, [Haptic.light]);
  });
}
