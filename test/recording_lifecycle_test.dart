import 'dart:async';

import 'package:ceskina_pro/domain/repositories/speech_ports.dart';
import 'package:ceskina_pro/presentation/providers/stt_providers.dart';
import 'package:ceskina_pro/presentation/widgets/common/record_button.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/speaking_task_view.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: testLocalizationsDelegates,
  supportedLocales: testSupportedLocales,
  home: Scaffold(body: child),
);

/// Recording holds the microphone. Every screen that starts one has to let go
/// of it again — on the way out, and when the result is thrown away.
void main() {
  testWidgets('leaving mid-recording releases the microphone', (tester) async {
    final mic = _FakeTranscriber();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [liveTranscriberProvider.overrideWithValue(mic)],
        child: _app(
          SpeakingTaskView(
            exercise: _exercise,
            onAnswered: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(RecordButton));
    await tester.pump();
    expect(mic.listening, isTrue);

    // The learner backs out while it is still listening.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [liveTranscriberProvider.overrideWithValue(mic)],
        child: _app(const SizedBox.shrink()),
      ),
    );
    await tester.pump();

    expect(
      mic.stopCalls,
      1,
      reason: 'the recogniser kept listening for a widget that was gone',
    );

    mic.complete('');
    await tester.pumpAndSettle();
  });

  testWidgets('the record control carries a screen-reader label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final mic = _FakeTranscriber();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [liveTranscriberProvider.overrideWithValue(mic)],
        child: _app(
          SpeakingTaskView(exercise: _exercise, onAnswered: (_) {}),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Start recording'), findsOneWidget);
    handle.dispose();
  });
}

const _exercise = Exercise(
  id: 1,
  lessonId: 1,
  type: ExerciseType.speakingTask,
  prompt: 'Say something',
  data: {
    'prompt_en': 'Say something',
    'expected_phrases': ['dobrý den'],
    'min_duration_seconds': 10,
  },
);

class _FakeTranscriber implements LiveTranscriber {
  bool listening = false;
  int stopCalls = 0;
  Completer<String>? _pending;

  void complete(String text) {
    listening = false;
    _pending?.complete(text);
    _pending = null;
  }

  @override
  Future<String> listenFor({Duration timeout = const Duration(seconds: 10)}) {
    listening = true;
    return (_pending = Completer<String>()).future;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    complete('');
  }

  @override
  Future<bool> supportsCzech() async => true;
}
