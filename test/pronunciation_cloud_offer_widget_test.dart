import 'package:czechify/data/database/database.dart' hide Exercise;
import 'package:czechify/data/repositories/consent_repository.dart';
import 'package:czechify/data/services/stt/whisper_service.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/domain/repositories/speech_ports.dart';
import 'package:czechify/presentation/providers/stt_providers.dart';
import 'package:logging/logging.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:czechify/presentation/widgets/common/record_button.dart';
import 'package:czechify/presentation/widgets/lesson/exercises/pronunciation_view.dart';

import 'support/localized_app.dart';

/// A phone without a Czech language pack cannot check pronunciation on device.
/// Saying so is honest but useless on its own: the learner is mid-exercise and
/// the remedy the app can actually offer is its own switch.
void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() async => database.close());

  /// Drives the real assessment path rather than seeding state: the view only
  /// shows an error for an attempt it started itself, and that scoping is part
  /// of what is being checked.
  Future<void> pumpAndRecord(
    WidgetTester tester, {
    required bool czechAvailable,
    bool cloudAvailable = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          pronunciationAssessmentProvider.overrideWithValue(
            PronunciationAssessor(
              recorder: _FakeRecorder(),
              whisper: _FakeCloud(available: cloudAvailable),
              fallbackStt: _FakeLiveTranscriber(
                czechAvailable: czechAvailable,
              ),
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
                  data: {'target_text': 'děti'},
                ),
                onAnswered: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RecordButton));
    await tester.pumpAndSettle();
  }

  testWidgets('a phone without Czech is offered the cloud, not just told', (
    tester,
  ) async {
    await pumpAndRecord(tester, czechAvailable: false);

    expect(find.textContaining('cannot recognise Czech'), findsOneWidget);
    expect(find.text('Check it in the cloud instead'), findsOneWidget);
    // What accepting costs is stated next to the button, not buried.
    expect(find.textContaining('Sends this recording'), findsOneWidget);
  });

  testWidgets('the offer asks for consent before sending anything', (
    tester,
  ) async {
    await pumpAndRecord(tester, czechAvailable: false);

    await tester.tap(find.text('Check it in the cloud instead'));
    await tester.pumpAndSettle();

    // The same wording Settings uses — one consent record, one meaning.
    expect(find.text('Allow cloud speech?'), findsOneWidget);
    expect(find.textContaining('OpenAI'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    final repo = ConsentRepository(database);
    expect(await repo.isGranted(ConsentPurpose.voiceCloudProcessing), isFalse);
  });

  testWidgets('an ordinary failure gets no such offer', (tester) async {
    // A spent allowance is not fixed by consenting to something already
    // consented to. Offering it would be noise on top of bad news.
    await pumpAndRecord(tester, czechAvailable: true);

    // Czech is available, so nothing failed in a way cloud speech would fix.
    expect(find.text('Check it in the cloud instead'), findsNothing);
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
  _FakeLiveTranscriber({required this.czechAvailable});

  final bool czechAvailable;

  @override
  Future<bool> supportsCzech() async => czechAvailable;

  @override
  Future<String> listenFor({
    Duration timeout = const Duration(seconds: 10),
  }) async => 'děti';

  @override
  Future<void> stop() async {}
}

class _FakeCloud implements CloudTranscriber {
  _FakeCloud({required this.available});

  final bool available;

  @override
  bool get isAvailable => available;

  @override
  Future<WhisperResult> transcribe({
    required String audioPath,
    String language = 'cs',
    String? prompt,
  }) async => const WhisperResult(
    text: 'děti',
    words: [],
    language: 'cs',
    duration: 1,
  );
}
