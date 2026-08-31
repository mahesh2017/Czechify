import 'package:czechify/data/services/stt/whisper_service.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/repositories/speech_ports.dart';
import 'package:czechify/presentation/providers/stt_providers.dart';
import 'package:czechify/presentation/widgets/common/record_button.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/pronunciation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'support/localized_app.dart';

/// The score used to be appended below the microphone, which pushed Continue
/// off the bottom: finishing an attempt meant scrolling to do anything with
/// it, and the word you needed to hear again was what scrolled away.
void main() {
  /// Returns whatever [heard] says, so a pass or a miss can be staged.
  Future<void> pumpAndSpeak(
    WidgetTester tester, {
    required String heard,
    int times = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pronunciationAssessmentProvider.overrideWithValue(
            PronunciationAssessor(
              recorder: _FakeRecorder(),
              whisper: _FakeCloud(),
              fallbackStt: _FakeLiveTranscriber(result: heard),
              log: Logger('test'),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PronunciationView(
                exercise: const Exercise(
                  id: 1,
                  lessonId: 1,
                  type: ExerciseType.pronunciation,
                  prompt: 'Say it',
                  data: {'target_text': 'káva', 'translation_en': 'coffee'},
                ),
                onAnswered: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The first attempt starts from the microphone; later ones from the
    // button the result offers, which records straight away rather than
    // merely clearing the score.
    await tester.tap(find.byType(RecordButton));
    await tester.pumpAndSettle();
    for (var i = 1; i < times; i++) {
      final retry =
          find.text('Try again').evaluate().isNotEmpty
              ? find.text('Try again')
              : find.text('Try once more');
      await tester.tap(retry);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the result takes the place of the microphone', (tester) async {
    await pumpAndSpeak(tester, heard: 'káva');

    // Not stacked below it — that growth is what forced the scroll.
    expect(find.byType(RecordButton), findsNothing);
    expect(find.byType(ScoreDisplay), findsOneWidget);
  });

  testWidgets('a pass offers only the way onward', (tester) async {
    await pumpAndSpeak(tester, heard: 'káva');

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Move on for now'), findsNothing);
  });

  testWidgets('a miss makes trying again the obvious move', (tester) async {
    await pumpAndSpeak(tester, heard: 'pes');

    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Not quite'), findsOneWidget);
    // Continue is still there — pronunciation must never hard-block progress.
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('a second miss promises a slower model rather than repeating', (
    tester,
  ) async {
    await pumpAndSpeak(tester, heard: 'pes', times: 2);

    expect(find.textContaining('Still not matching'), findsOneWidget);
    expect(find.textContaining('slower'), findsOneWidget);
  });

  testWidgets('a third miss stops asking and offers a way out', (tester) async {
    await pumpAndSpeak(tester, heard: 'pes', times: 3);

    // Submitting here is a miss, so the lesson's mistake queue re-asks it and
    // the evidence row records a speaking miss — "bring it back" is a promise
    // the app already keeps.
    expect(find.text('Move on for now'), findsOneWidget);
    expect(find.textContaining('bring it back'), findsOneWidget);
    // Still not forced: one more go is available for anyone who wants it.
    expect(find.text('Try once more'), findsOneWidget);
  });

  testWidgets('trying again records straight away rather than just resetting', (
    tester,
  ) async {
    await pumpAndSpeak(tester, heard: 'pes');
    expect(find.textContaining('Not quite'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    // One tap, one attempt: the learner is not made to find the microphone
    // again between goes. The coaching has moved on, which is the evidence a
    // second attempt actually happened.
    expect(find.byType(ScoreDisplay), findsOneWidget);
    expect(find.textContaining('Still not matching'), findsOneWidget);
  });
}

class _FakeRecorder implements AudioRecorderPort {
  bool _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<String> start() async {
    _recording = true;
    return '/tmp/fake.wav';
  }

  @override
  Future<String> stop() async {
    _recording = false;
    return '/tmp/fake.wav';
  }

  @override
  Future<void> cleanup() async {}

  @override
  Future<String> recordUntilSilence({
    Duration silenceTimeout = const Duration(seconds: 3),
    Duration maxDuration = const Duration(seconds: 15),
    Future<void>? stopSignal,
  }) async {
    await start();
    return stop();
  }
}

class _FakeLiveTranscriber implements LiveTranscriber {
  _FakeLiveTranscriber({required this.result});

  final String result;

  @override
  Future<bool> supportsCzech() async => true;

  @override
  Future<String> listenFor({
    Duration timeout = const Duration(seconds: 10),
  }) async => result;

  @override
  Future<void> stop() async {}
}

class _FakeCloud implements CloudTranscriber {
  @override
  bool get isAvailable => false;

  @override
  Future<WhisperResult> transcribe({
    required String audioPath,
    String language = 'cs',
    String? prompt,
  }) async => const WhisperResult(
    text: '',
    words: [],
    language: 'cs',
    duration: 0,
  );
}
