import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/chat_message.dart';
import 'package:czechify/domain/repositories/speech_ports.dart';
import 'package:czechify/presentation/providers/chat_providers.dart';
import 'package:czechify/presentation/providers/stt_providers.dart';
import 'package:czechify/presentation/screens/chat/chat_screen.dart';
import 'package:czechify/presentation/widgets/common/motion_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

void main() {
  Future<({WidgetTester tester, _ChatMotionNotifier notifier})> mount(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late _ChatMotionNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith(() => notifier = _ChatMotionNotifier()),
          liveTranscriberProvider.overrideWithValue(_FakeTranscriber()),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          builder:
              disableAnimations
                  ? (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: child!,
                  )
                  : null,
          home: const ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (tester: tester, notifier: notifier);
  }

  testWidgets('restored messages stay still while appended messages enter', (
    tester,
  ) async {
    final harness = await mount(tester);
    final restored = tester.widget<MotionEntrance>(
      find.byKey(const ValueKey('chat-message-restored')),
    );
    expect(restored.animateOnMount, isFalse);

    harness.notifier.append(_message('live', 'Ahoj!', MessageRole.user));
    await tester.pump();

    final incomingFinder = find.byKey(const ValueKey('chat-message-live'));
    final incoming = tester.widget<MotionEntrance>(incomingFinder);
    expect(incoming.animateOnMount, isTrue);
    final translation = tester.widget<FractionalTranslation>(
      find.descendant(
        of: incomingFinder,
        matching: find.byType(FractionalTranslation),
      ),
    );
    expect(translation.translation.dx, greaterThan(0));
  });

  testWidgets('appended messages snap into place with reduced motion', (
    tester,
  ) async {
    final harness = await mount(tester, disableAnimations: true);
    harness.notifier.append(_message('live', 'Ahoj!', MessageRole.user));
    await tester.pump();
    await tester.pump();

    final incomingFinder = find.byKey(const ValueKey('chat-message-live'));
    final translation = tester.widget<FractionalTranslation>(
      find.descendant(
        of: incomingFinder,
        matching: find.byType(FractionalTranslation),
      ),
    );
    expect(translation.translation, Offset.zero);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

ChatMessage _message(String id, String content, MessageRole role) =>
    ChatMessage(
      id: id,
      conversationId: 'conversation',
      role: role,
      content: content,
      createdAt: DateTime.utc(2026, 9, 3),
    );

class _ChatMotionNotifier extends ChatNotifier {
  @override
  ChatState build() => ChatState(
    conversationId: 'conversation',
    scenarioId: 'casual_chat',
    scenarioTitle: 'Casual Chat',
    messages: [_message('restored', 'Dobrý den!', MessageRole.tutor)],
  );

  void append(ChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }
}

class _FakeTranscriber implements LiveTranscriber {
  @override
  Future<String> listenFor({
    Duration timeout = const Duration(seconds: 30),
  }) async => '';

  @override
  Future<void> stop() async {}

  @override
  Future<bool> supportsCzech() async => true;
}
