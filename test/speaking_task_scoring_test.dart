import 'dart:async';

import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/repositories/speech_ports.dart';
import 'package:czechify/presentation/providers/stt_providers.dart';
import 'package:czechify/presentation/widgets/common/record_button.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/exercise_shared.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/speaking_task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// Partial credit used to count every spoken token that appeared anywhere in
/// the expected vocabulary and divide by the number of distinct expected
/// words. Repetition therefore paid: one word said enough times cleared the
/// pass mark for a phrase the learner never produced.
void main() {
  /// Drives one recording to completion and returns what the exercise reported.
  Future<ExerciseResult> speak(
    WidgetTester tester,
    String transcript, {
    List<String> expectedPhrases = const ['Dobrý den, jmenuji se Jana.'],
  }) async {
    final mic = _FakeTranscriber();
    ExerciseResult? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [liveTranscriberProvider.overrideWithValue(mic)],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: SpeakingTaskView(
              exercise: Exercise(
                id: 1,
                lessonId: 1,
                type: ExerciseType.speakingTask,
                prompt: 'Introduce yourself',
                data: {
                  'prompt_en': 'Introduce yourself',
                  'expected_phrases': expectedPhrases,
                },
              ),
              onAnswered: (r) => result = r,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(RecordButton));
    await tester.pump();
    mic.complete(transcript);
    await tester.pump();
    // The view shows the result briefly before it auto-submits.
    await tester.pump(const Duration(seconds: 3));

    expect(result, isNotNull, reason: 'the exercise never reported a result');
    return result!;
  }

  testWidgets('one word repeated does not pass the task', (tester) async {
    final result = await speak(tester, 'dobrý dobrý dobrý dobrý dobrý dobrý');

    expect(result.isCorrect, isFalse);
  });

  testWidgets('padding a real attempt with repeats does not rescue it', (
    tester,
  ) async {
    // Two of the five expected words, then filler. The filler must not carry
    // it over the line.
    final result = await speak(tester, 'dobrý den den den den den den den den');

    expect(result.isCorrect, isFalse);
  });

  testWidgets('the expected phrase still passes', (tester) async {
    final result = await speak(tester, 'Dobrý den, jmenuji se Jana.');

    expect(result.isCorrect, isTrue);
  });

  testWidgets('a near-miss of the expected phrase still passes', (
    tester,
  ) async {
    // Most of the phrase, recognised without its punctuation — the ordinary
    // shape of a good attempt, and the case the partial score exists for.
    final result = await speak(tester, 'dobrý den jmenuji se jana');

    expect(result.isCorrect, isTrue);
  });

  testWidgets('the learner is credited for the alternative they chose', (
    tester,
  ) async {
    final result = await speak(
      tester,
      'ahoj jmenuji se jana',
      expectedPhrases: const [
        'Dobrý den, jmenuji se Jana.',
        'Ahoj, jmenuji se Jana.',
      ],
    );

    expect(result.isCorrect, isTrue);
  });

  testWidgets('a phone without Czech says so, and records no failure', (
    tester,
  ) async {
    ExerciseResult? result;
    final mic = _NoCzechTranscriber();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [liveTranscriberProvider.overrideWithValue(mic)],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: SpeakingTaskView(
              exercise: const Exercise(
                id: 1,
                lessonId: 1,
                type: ExerciseType.speakingTask,
                prompt: 'Introduce yourself',
                data: {
                  'prompt_en': 'Introduce yourself',
                  'expected_phrases': ['Dobrý den, jmenuji se Jana.'],
                },
              ),
              onAnswered: (r) => result = r,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(RecordButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // The learner is told what is actually wrong, not "recording failed",
    // which they can only read as their own doing.
    expect(find.textContaining('cannot recognise Czech'), findsOneWidget);
    // And nothing is submitted, so an unavailable recogniser never becomes a
    // wrong answer on their record.
    expect(result, isNull);
  });

  testWidgets('any other recogniser failure still records nothing', (
    tester,
  ) async {
    ExerciseResult? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveTranscriberProvider.overrideWithValue(_BrokenTranscriber()),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: SpeakingTaskView(
              exercise: const Exercise(
                id: 1,
                lessonId: 1,
                type: ExerciseType.speakingTask,
                prompt: 'Introduce yourself',
                data: {
                  'prompt_en': 'Introduce yourself',
                  'expected_phrases': ['Dobrý den, jmenuji se Jana.'],
                },
              ),
              onAnswered: (r) => result = r,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(RecordButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(find.textContaining('Recording'), findsOneWidget);
    expect(result, isNull);
  });
}

/// The recogniser fails for some other reason — no microphone permission, a
/// platform error. The learner gets the generic message, and still no failure
/// on their record.
class _BrokenTranscriber implements LiveTranscriber {
  @override
  Future<String> listenFor({Duration timeout = const Duration(seconds: 10)}) =>
      throw Exception('platform channel unavailable');

  @override
  Future<void> stop() async {}

  @override
  Future<bool> supportsCzech() async => true;
}

/// A recogniser that cannot handle Czech refuses rather than transcribing with
/// the device default — an English recogniser hearing Czech produces words
/// that then get scored, and the learner is told their Czech was wrong.
class _NoCzechTranscriber implements LiveTranscriber {
  @override
  Future<String> listenFor({Duration timeout = const Duration(seconds: 10)}) =>
      throw const SpeechServiceException(
        'Your phone cannot recognise Czech speech, so this cannot be checked '
        'on the device.',
        cloudSpeechWouldFix: true,
      );

  @override
  Future<void> stop() async {}

  @override
  Future<bool> supportsCzech() async => false;
}

class _FakeTranscriber implements LiveTranscriber {
  Completer<String>? _pending;

  void complete(String text) {
    _pending?.complete(text);
    _pending = null;
  }

  @override
  Future<String> listenFor({Duration timeout = const Duration(seconds: 10)}) =>
      (_pending = Completer<String>()).future;

  @override
  Future<void> stop() async => complete('');

  @override
  Future<bool> supportsCzech() async => true;
}
