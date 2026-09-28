import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/learning_evidence.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/widgets/common/slide_deck.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:czechify/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:czechify/presentation/widgets/lesson/exercise_slides.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// Unit 2 pilot: a passage or recording with questions, and a dialogue, are
/// slides — one question or one reply to a screen — instead of one long page.
void main() {
  Future<List<ExerciseResult>> pump(
    WidgetTester tester,
    Exercise exercise,
  ) async {
    final results = <ExerciseResult>[];
    tester.view.physicalSize = const Size(375, 557);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [czechTtsProvider.overrideWithValue(_SilentTts())],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
          home: Scaffold(
            body: LessonExerciseViewport(
              exercise: exercise,
              onAnswered: results.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return results;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(SlideDeck.nextKey));
    await tester.pump();
  }

  const questions = [
    {
      'question_en': 'What is her name?',
      'options': ['Olena', 'Anna'],
      'correct_index': 0,
    },
    {
      'question_en': 'Where is she from?',
      'options': ['Ukraine', 'India'],
      'correct_index': 0,
    },
  ];

  test('several-part steps are slides; single questions stay one page', () {
    Exercise of(int lessonId, ExerciseType type, [String? style]) => Exercise(
      id: 1,
      lessonId: lessonId,
      type: type,
      prompt: '',
      data: {if (style != null) 'style': style},
    );
    expect(showsAsSlides(of(203, ExerciseType.listeningComprehension)), isTrue);
    expect(showsAsSlides(of(203, ExerciseType.readingComprehension)), isTrue);
    expect(showsAsSlides(of(204, ExerciseType.dialogue)), isTrue);
    expect(showsAsSlides(of(204, ExerciseType.teaching, 'list')), isTrue);
    expect(showsAsSlides(of(202, ExerciseType.teaching, 'lecture')), isTrue);
    expect(showsAsSlides(of(204, ExerciseType.teaching, 'alphabet')), isTrue);
    // Bounded for its comparison deck; its other screens scroll themselves.
    expect(showsAsSlides(of(204, ExerciseType.teaching, 'notebook')), isTrue);
    expect(
      showsAsSlides(of(204, ExerciseType.teaching, 'image_cards')),
      isFalse,
    );
    expect(showsAsSlides(of(203, ExerciseType.multipleChoice)), isFalse);
  });

  testWidgets('reading: the passage in Czech first, English on request, then '
      'one question a slide under the text again', (tester) async {
    final results = await pump(
      tester,
      const Exercise(
        id: 2350,
        lessonId: 203,
        type: ExerciseType.readingComprehension,
        prompt: 'Read',
        data: {
          'prompt_en': 'Read the introduction.',
          'text_cz': 'Jmenuji se Olena. Jsem z Ukrajiny.',
          'text_en': 'My name is Olena. I am from Ukraine.',
          'questions': questions,
        },
      ),
    );

    expect(find.text('Jmenuji se Olena. Jsem z Ukrajiny.'), findsOneWidget);
    expect(find.text('My name is Olena. I am from Ukraine.'), findsNothing);
    await tester.tap(find.text('Show in English'));
    await tester.pump();
    expect(find.text('My name is Olena. I am from Ukraine.'), findsOneWidget);
    await tester.tap(find.text('Back to Czech'));
    await tester.pump();

    await next(tester);
    expect(find.text('What is her name?'), findsOneWidget);
    expect(find.text('Where is she from?'), findsNothing);
    // The text is still there to answer from.
    expect(find.text('Jmenuji se Olena. Jsem z Ukrajiny.'), findsOneWidget);

    // Next waits for an answer.
    await next(tester);
    expect(find.text('What is her name?'), findsOneWidget);
    await tester.tap(find.text('Olena'));
    await tester.pump();
    await next(tester);
    await tester.tap(find.text('India'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(results, hasLength(1));
    expect(results.single.isCorrect, isFalse);
    expect(results.single.supports, {SupportKind.translation});
    expect(find.text('Check answers'), findsNothing);
  });

  testWidgets('listening: each question slide can play the recording again, '
      'which counts as a replay', (tester) async {
    final results = await pump(
      tester,
      const Exercise(
        id: 2351,
        lessonId: 203,
        type: ExerciseType.listeningComprehension,
        prompt: 'Listen',
        data: {
          'prompt_en': 'Listen to the introduction.',
          'transcript_cz': 'Jmenuji se Olena. Jsem z Ukrajiny.',
          'questions': questions,
        },
      ),
    );
    // Let the automatic first play happen.
    await tester.pump(kListenAutoPlayDelay);

    await next(tester);
    await tester.tap(find.text('Play it again'));
    await tester.pump();
    await tester.tap(find.text('Olena'));
    await tester.pump();
    await next(tester);
    await tester.tap(find.text('Ukraine'));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();

    expect(results.single.isCorrect, isTrue);
    expect(results.single.supports, {SupportKind.replay});
  });

  testWidgets('dialogue: the situation first, then one reply a slide, and '
      'Return moves to the next', (tester) async {
    final results = await pump(
      tester,
      const Exercise(
        id: 2352,
        lessonId: 204,
        type: ExerciseType.dialogue,
        prompt: 'Complete the meeting',
        data: {
          'scenario': 'Your first Czech class',
          'lines': [
            {'speaker': 'teacher', 'text': 'Jak se jmenujete?'},
            {'speaker': 'you', 'text': '___'},
            {'speaker': 'teacher', 'text': 'Odkud jste?'},
            {'speaker': 'you', 'text': '___'},
            {'speaker': 'teacher', 'text': 'Těší mě.'},
          ],
          'blank_answers': [
            ['Jmenuji se Eva.'],
            ['Jsem z Indie.'],
          ],
        },
      ),
    );

    expect(find.text('Your first Czech class'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await next(tester);
    expect(find.text('Jak se jmenujete?'), findsOneWidget);
    expect(find.text('Odkud jste?'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Jmenuji se Eva.');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.pump();
    expect(find.text('Odkud jste?'), findsOneWidget);
    // The closing line comes with the last reply.
    expect(find.text('Těší mě.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Jsem z Indie.');
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(results.single.isCorrect, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _SilentTts implements CzechTts {
  @override
  final ValueNotifier<bool> usingFallbackVoice = ValueNotifier(false);
  @override
  Future<void> speak(String text, {double? rate}) async {}
  @override
  Future<void> speakSlow(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
