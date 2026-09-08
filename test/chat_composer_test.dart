import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/engines/llm_orchestrator.dart';
import 'package:czechify/domain/repositories/speech_ports.dart';
import 'package:czechify/presentation/providers/chat_providers.dart';
import 'package:czechify/presentation/providers/stt_providers.dart';
import 'package:czechify/presentation/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// The composer clears the draft the moment the learner hits send, because
/// waiting for the database first feels broken. That leaves it owing them the
/// text back if the send is refused — which it did not do.
void main() {
  Future<_RecordingNotifier> mount(
    WidgetTester tester, {
    required bool accepts,
    LiveTranscriber? transcriber,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late _RecordingNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith(
            () => notifier = _RecordingNotifier(accepts: accepts),
          ),
          liveTranscriberProvider.overrideWithValue(
            transcriber ?? _FakeTranscriber(),
          ),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  final composer = find.byType(TextField).first;

  group('what the learner is told when dictation does not produce text', () {
    // The recogniser used to return an empty string when it heard nothing and
    // when it could not run at all, so both arrived here as a transcription of
    // silence and got the same notice. They are different problems: one is
    // fixed by speaking again, the other by leaving the app.
    Future<String> noticeFor(
      WidgetTester tester,
      SpeechServiceException failure,
    ) async {
      await mount(
        tester,
        accepts: true,
        transcriber: _FailingTranscriber(failure),
      );
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();
      return tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? '')
          .firstWhere((text) => text.contains('type'), orElse: () => '');
    }

    testWidgets('hearing nothing invites another try', (tester) async {
      final notice = await noticeFor(
        tester,
        const SpeechServiceException(
          'No speech was recognised. Please try recording again.',
          nothingHeard: true,
        ),
      );
      expect(notice, contains('Try again'));
    });

    testWidgets('a recogniser that cannot run says so instead', (tester) async {
      final notice = await noticeFor(
        tester,
        const SpeechServiceException(
          'Speech recognition is not available on this phone.',
          cloudSpeechWouldFix: true,
        ),
      );
      expect(notice, contains('unavailable'));
    });
  });

  testWidgets('a refused message is put back in the composer', (tester) async {
    final notifier = await mount(tester, accepts: false);

    await tester.enterText(composer, 'Dobrý den');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(notifier.sent, ['Dobrý den']);
    // Without this the learner was told to try again with nothing to try.
    expect(tester.widget<TextField>(composer).controller?.text, 'Dobrý den');
  });

  testWidgets('an accepted message leaves the composer empty', (tester) async {
    await mount(tester, accepts: true);

    await tester.enterText(composer, 'Dobrý den');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(composer).controller?.text, isEmpty);
  });

  testWidgets('a newer draft outranks the one that failed', (tester) async {
    await mount(tester, accepts: false);

    await tester.enterText(composer, 'první');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    // The learner starts typing again before the refusal comes back.
    await tester.enterText(composer, 'druhá');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(composer).controller?.text, 'druhá');
  });

  testWidgets('the counter appears only as the server limit nears', (
    tester,
  ) async {
    await mount(tester, accepts: true);

    await tester.enterText(composer, 'krátká zpráva');
    await tester.pump();
    expect(find.textContaining('/ 4000'), findsNothing);

    await tester.enterText(
      composer,
      'x' * (LLMOrchestrator.maxMessageCharacters - 100),
    );
    await tester.pump();
    expect(find.textContaining('/ 4000'), findsOneWidget);
  });

  testWidgets('the composer will not exceed the server limit', (tester) async {
    await mount(tester, accepts: true);

    // The proxy refuses anything longer, and the message is persisted before
    // it is sent — so an oversized one used to fail on every retry.
    await tester.enterText(
      composer,
      'x' * (LLMOrchestrator.maxMessageCharacters + 500),
    );
    await tester.pump();

    expect(
      tester.widget<TextField>(composer).controller?.text.length,
      LLMOrchestrator.maxMessageCharacters,
    );
  });
}

class _RecordingNotifier extends ChatNotifier {
  _RecordingNotifier({required this.accepts});

  final bool accepts;
  final List<String> sent = [];

  @override
  ChatState build() => const ChatState(
    conversationId: 'conversation',
    scenarioId: 'casual_chat',
    messages: [],
  );

  @override
  Future<bool> sendMessage(String text) async {
    sent.add(text);
    return accepts;
  }
}

/// A recogniser that fails in a stated way.
class _FailingTranscriber implements LiveTranscriber {
  _FailingTranscriber(this.failure);

  final SpeechServiceException failure;

  @override
  Future<String> listenFor({
    Duration timeout = const Duration(seconds: 30),
    bool requireCzech = true,
  }) async => throw failure;

  @override
  Future<void> stop() async {}

  @override
  Future<bool> supportsCzech() async => true;
}

class _FakeTranscriber implements LiveTranscriber {
  @override
  Future<String> listenFor({
    Duration timeout = const Duration(seconds: 30),
    bool requireCzech = true,
  }) async => 'Dobrý den';

  @override
  Future<void> stop() async {}

  @override
  Future<bool> supportsCzech() async => true;
}
