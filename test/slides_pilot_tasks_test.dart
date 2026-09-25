import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/core/theme/app_tokens.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/domain/entities/pronunciation_result.dart';
import 'package:czechify/domain/repositories/speech_ports.dart';
import 'package:czechify/presentation/providers/pronunciation_providers.dart';
import 'package:czechify/presentation/providers/stt_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/widgets/common/slide_deck.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:czechify/presentation/widgets/lesson/lesson_exercise_viewport.dart';
import 'package:czechify/presentation/widgets/lesson/slides_pilot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pilot_units.dart';
import 'support/localized_app.dart';
import 'support/shipped_exercises.dart';

/// Unit 2 pilot, step 3: writing, speaking and pronunciation put the task on
/// one slide and doing it on the next, so neither the brief nor the keyboard
/// pushes the page, the microphone or the result off a small phone.
void main() {
  Future<List<ExerciseResult>> pump(
    WidgetTester tester,
    Exercise exercise, {
    List<Object> overrides = const [],
    Locale? locale,
  }) async {
    final results = <ExerciseResult>[];
    tester.view.physicalSize = const Size(375, 557);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          czechTtsProvider.overrideWithValue(_SilentTts()),
          ...overrides.cast(),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          locale: locale,
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

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pump();
  }

  test('writing, speaking and pronunciation are slides in Unit 2 only', () {
    Exercise of(int lessonId, ExerciseType type) =>
        Exercise(id: 1, lessonId: lessonId, type: type, prompt: '', data: const {});
    for (final type in [
      ExerciseType.writingTask,
      ExerciseType.speakingTask,
      ExerciseType.pronunciation,
    ]) {
      expect(showsAsSlides(of(204, type)), isTrue, reason: '$type in Unit 2');
      expect(
        showsAsSlides(of(outsidePilotLesson(4), type)),
        isFalse,
        reason: '$type outside the pilot',
      );
    }
  });

  group('writing', () {
    const writing = Exercise(
      id: 2360,
      lessonId: 203,
      type: ExerciseType.writingTask,
      prompt: 'Write',
      data: {
        'prompt_en':
            'Write a greeting, your real name, and where you are from. Keep '
            'one register throughout.',
        'prompt_cz': 'Napište pozdrav, jméno a odkud jste.',
        'min_words': 3,
        'key_vocab': ['Dobrý den.', 'Jsem z…'],
        'sample_answer': 'Dobrý den. Jmenuji se Eva. Jsem z Indie.',
      },
    );

    testWidgets('the brief, then a page that opens ready to type; review, '
        'revise and send, with the feedback left to the lesson', (
      tester,
    ) async {
      final results = await pump(tester, writing);

      expect(find.textContaining('Write a greeting'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tapKey(tester, SlideDeck.nextKey);
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue,
        reason: 'the page opens ready to type',
      );

      // Nothing to review yet.
      await tapKey(tester, SlideDeck.doneKey);
      expect(find.text('Submit revision'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Dobrý den. Jsem Eva.');
      await tester.pump();
      expect(find.text('4 words'), findsOneWidget);
      await tapKey(tester, SlideDeck.doneKey);
      expect(find.text('Submit revision'), findsOneWidget);
      expect(results, isEmpty);
      // Reviewing puts the keyboard away, so the note on what to check shows.
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isFalse,
      );
      expect(find.textContaining('Revise: check'), findsOneWidget);

      await tapKey(tester, SlideDeck.doneKey);
      expect(results.single.outcome, ExerciseOutcome.skipped);
      expect(
        results.single.correctAnswer,
        'Dobrý den. Jmenuji se Eva. Jsem z Indie.',
      );
      // The lesson's feedback sheet has the count and the reference answer;
      // the page does not grow a second copy.
      expect(find.text('Writing cycle complete'), findsNothing);
      expect(find.byKey(SlideDeck.doneKey), findsNothing);
    });

    testWidgets('with the keyboard up the page keeps the room and the brief '
        'steps aside', (tester) async {
      await pump(tester, writing);
      await tapKey(tester, SlideDeck.nextKey);
      expect(find.text('Napište pozdrav, jméno a odkud jste.'), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(find.text('Napište pozdrav, jméno a odkud jste.'), findsNothing);
      expect(tester.getSize(find.byType(TextField)).height, greaterThan(80));
      expect(tester.takeException(), isNull);
    });
  });

  group('speaking', () {
    const speaking = Exercise(
      id: 2361,
      lessonId: 204,
      type: ExerciseType.speakingTask,
      prompt: 'Speak',
      data: {
        'prompt_en':
            'Greet the person, say your name and where you are from, then '
            'close politely.',
        'prompt_cz': 'Pozdravte se a představte se.',
        'expected_phrases': ['Dobrý den.', 'Jmenuji se', 'Na shledanou.'],
        'max_duration_seconds': 30,
      },
    );

    testWidgets('the brief, then the phrases and the microphone, with Back '
        'and no button of its own', (tester) async {
      await pump(tester, speaking);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);

      await tapKey(tester, SlideDeck.nextKey);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('Jmenuji se'), findsOneWidget);
      expect(find.byKey(SlideDeck.backKey), findsOneWidget);
      expect(find.byKey(SlideDeck.doneKey), findsNothing);
    });

    testWidgets('someone who cannot speak aloud can skip, at no cost', (
      tester,
    ) async {
      final results = await pump(tester, speaking);
      await tapKey(tester, SlideDeck.nextKey);

      await tester.tap(find.text("Can't speak right now? Skip"));
      await tester.pump();
      expect(results.single.outcome, ExerciseOutcome.skipped);
      expect(results.single.correctAnswer, 'Dobrý den.; Jmenuji se; Na shledanou.');
      expect(find.text("Can't speak right now? Skip"), findsNothing);
      expect(find.byKey(SlideDeck.backKey), findsNothing);
      // Nothing left to record into once the task is handed in.
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    });

    testWidgets('outside the pilot the one-page task has the skip too', (
      tester,
    ) async {
      final results = await pump(
        tester,
        Exercise(
          id: 6361,
          lessonId: outsidePilotLesson(4),
          type: ExerciseType.speakingTask,
          prompt: 'Speak',
          data: {
            'prompt_en': 'Say hello.',
            'expected_phrases': ['Dobrý den.'],
          },
        ),
      );
      expect(find.byType(SlideDeck), findsNothing);
      await tester.tap(find.text("Can't speak right now? Skip"));
      await tester.pump();
      expect(results.single.outcome, ExerciseOutcome.skipped);
    });

    testWidgets('a good recording shows in the microphone\'s place and is '
        'green in Czech too', (tester) async {
      final results = await pump(
        tester,
        speaking,
        locale: const Locale('cs'),
        overrides: [
          liveTranscriberProvider.overrideWithValue(
            _Transcriber('Dobrý den.'),
          ),
        ],
      );
      await tapKey(tester, SlideDeck.nextKey);
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      final good = find.text('Dobře — řekli jste to podstatné.');
      expect(good, findsOneWidget);
      expect(
        tester.widget<Text>(good).style?.color,
        tester.element(good).tokens.greenInk,
        reason: 'the colour used to depend on the English word "Good"',
      );

      await tester.pump(const Duration(seconds: 2));
      expect(results.single.isCorrect, isTrue);
      expect(find.byKey(SlideDeck.backKey), findsNothing);
    });
  });

  group('pronunciation', () {
    // Unit 2's longest model sentence, as shipped.
    final model = loadShippedExercises().singleWhere((e) => e.id == 2407);

    setUpAll(() async {
      for (final font in {
        'Bricolage Grotesque': 'BricolageGrotesque',
        'Schibsted Grotesk': 'SchibstedGrotesk',
      }.entries) {
        await (FontLoader(font.key)
          ..addFont(rootBundle.load('assets/fonts/${font.value}.ttf'))).load();
      }
    });

    testWidgets('the sounds to listen for are named in words, not as keys', (
      tester,
    ) async {
      await pump(tester, model);
      expect(find.text('Stress on the first syllable'), findsOneWidget);
      expect(find.text('Long vowels'), findsOneWidget);
      expect(find.text('ě'), findsOneWidget);
      expect(find.text('first_syllable_stress'), findsNothing);
    });

    testWidgets('hear it, then say it: the sentence, the model beside it, '
        'the microphone', (tester) async {
      await pump(tester, model);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      await tapKey(tester, SlideDeck.nextKey);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byTooltip('Play it again'), findsOneWidget);
      expect(find.byKey(SlideDeck.doneKey), findsNothing);
    });

    for (final score in [0.3, 0.9]) {
      testWidgets('after an attempt scoring $score, the result fits a small '
          'phone without scrolling', (tester) async {
        await pump(
          tester,
          model,
          overrides: [pronunciationProvider.overrideWith(() => _Scored(score))],
        );
        await tapKey(tester, SlideDeck.nextKey);
        await tester.tap(find.byIcon(Icons.mic_rounded));
        await tester.pump();
        await tester.pump();

        // The result takes the microphone's place.
        expect(find.byIcon(Icons.mic_rounded), findsNothing);
        final slide = find.descendant(
          of: find.byType(PageView),
          matching: find.byType(SingleChildScrollView),
        );
        final scroll = tester.state<ScrollableState>(
          find.descendant(of: slide.first, matching: find.byType(Scrollable)).first,
        );
        expect(scroll.position.maxScrollExtent, lessThan(1));
        // The result's own buttons stand in for the deck's.
        expect(find.byKey(SlideDeck.backKey), findsNothing);
      });
    }

    testWidgets('outside the pilot the sounds are named in words too', (
      tester,
    ) async {
      await pump(
        tester,
        Exercise(
          id: 6362,
          lessonId: outsidePilotLesson(4),
          type: ExerciseType.pronunciation,
          prompt: 'Say it',
          data: {
            'target_text': 'Máma',
            'focus_sounds': ['vowel_length'],
          },
        ),
      );
      expect(find.byType(SlideDeck), findsNothing);
      expect(find.text('Vowel length'), findsOneWidget);
    });
  });

  testWidgets('at 200% text every step-3 slide in the pilot lays out, with the '
      'keyboard up too; a slide may scroll then, but nothing overflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tasks = loadShippedExercises().where(
      (e) =>
          pilotUnits.contains(e.lessonId ~/ 100) &&
          const {
            ExerciseType.writingTask,
            ExerciseType.speakingTask,
            ExerciseType.pronunciation,
          }.contains(e.type),
    );
    expect(tasks, isNotEmpty);
    for (final exercise in tasks) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [czechTtsProvider.overrideWithValue(_SilentTts())],
          child: MaterialApp(
            theme: lightTheme(),
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: child!,
                ),
            home: Scaffold(
              body: LessonExerciseViewport(
                key: ValueKey(exercise.id),
                exercise: exercise,
                onAnswered: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final deck = tester.state<SlideDeckState>(find.byType(SlideDeck));
      for (var page = 0; page < deck.length; page++) {
        deck.goTo(page);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${exercise.id} $page');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${exercise.id} slide $page with the keyboard up',
        );
        tester.view.resetViewInsets();
        await tester.pump();
      }
    }
  });
}

class _Scored extends PronunciationNotifier {
  _Scored(this.score);
  final double score;

  @override
  Future<void> startRecording({required String expectedText}) async {
    state = PronunciationState(
      expectedText: expectedText,
      attemptId: 4242,
      result: PronunciationResult(
        overallScore: score,
        wordScores: const [],
        problemSounds: const [],
        tips: const [
          PronunciationTip(PronunciationTipCode.vowelLength),
          PronunciationTip(PronunciationTipCode.softeningE),
        ],
      ),
    );
  }
}

class _Transcriber implements LiveTranscriber {
  _Transcriber(this.heard);
  final String heard;

  @override
  Future<String> listenFor({
    Duration timeout = const Duration(seconds: 15),
    bool requireCzech = true,
  }) async => heard;

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
