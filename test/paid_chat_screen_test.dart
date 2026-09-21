import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:czechify/domain/entities/chat_message.dart';
import 'package:czechify/presentation/providers/billing_providers.dart';
import 'package:czechify/presentation/providers/chat_providers.dart';
import 'package:czechify/presentation/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/localized_app.dart';

/// Once chat needs the AI subscription, the screen says so plainly, states
/// the daily limit the server enforces, and offers the plan rather than a
/// retry that cannot work.
class _Chat extends ChatNotifier {
  _Chat(this.initial);
  final ChatState initial;
  int retries = 0;

  @override
  ChatState build() => initial;

  @override
  Future<void> retryLastMessage() async => retries++;
}

const _conversation = 'conv_0a1b2c3d-4e5f-4a6b-8c7d-8e9f0a1b2c3d';

Future<_Chat> _pump(
  WidgetTester tester, {
  ChatState state = const ChatState(),
  bool access = true,
  int limit = 25,
}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final chat = _Chat(state);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ChatScreen()),
      GoRoute(
        path: '/subscriptions',
        builder: (_, _) => const Scaffold(body: Text('Subscriptions page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatProvider.overrideWith(() => chat),
        aiChatAccessProvider.overrideWith((_) async => access),
        monetizationConfigurationProvider.overrideWith(
          (_) async => MonetizationConfiguration(
            playCheckoutEnabled: true,
            coursePaywallEnabled: true,
            paidChatRequired: true,
            aiDailyTurnLimit: limit,
          ),
        ),
        recentConversationsProvider.overrideWith((_) async => const []),
        hasMoreConversationsProvider.overrideWith((_) async => false),
      ],
      child: MaterialApp.router(
        theme: lightTheme(),
        routerConfig: router,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return chat;
}

ChatState _failed(String code) => ChatState(
  conversationId: _conversation,
  messages: [ChatMessage.user('Ahoj', conversationId: _conversation)],
  error: 'server text',
  errorCode: code,
);

void main() {
  testWidgets('without the subscription, new conversations lead to the plan', (
    tester,
  ) async {
    await _pump(tester, access: false);
    expect(find.text('Talk with the AI tutor'), findsOneWidget);
    expect(find.textContaining('up to 25 tutor replies a day'), findsOneWidget);
    expect(find.textContaining('part of Czechify Core'), findsOneWidget);
    expect(find.text('Pick a situation'), findsNothing);
    await tester.tap(find.text('See AI chat'));
    await tester.pumpAndSettle();
    expect(find.text('Subscriptions page'), findsOneWidget);
  });

  testWidgets('with access, the situations are offered as before', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Pick a situation'), findsOneWidget);
    expect(find.text('Talk with the AI tutor'), findsNothing);
  });

  testWidgets('a missing subscription offers the plan, not a retry', (
    tester,
  ) async {
    final chat = await _pump(tester, state: _failed('ai_entitlement_required'));
    expect(
      find.text('Talking with the tutor needs the AI chat subscription.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('See AI chat'));
    await tester.pumpAndSettle();
    expect(find.text('Subscriptions page'), findsOneWidget);
    expect(chat.retries, 0);
  });

  testWidgets('a used-up day says so and offers no retry', (tester) async {
    await _pump(tester, state: _failed('quota_exceeded'));
    expect(
      find.text("You've used today's tutor replies. More tomorrow."),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('an unknown outcome warns that sending again costs a reply', (
    tester,
  ) async {
    final chat = await _pump(tester, state: _failed('result_unavailable'));
    expect(find.textContaining("couldn't confirm"), findsOneWidget);
    await tester.tap(find.text('Send again'));
    await tester.pump();
    expect(chat.retries, 1);
  });

  testWidgets('an error without a code keeps the service text and a retry', (
    tester,
  ) async {
    final chat = await _pump(
      tester,
      state: const ChatState(
        conversationId: _conversation,
        error: 'Could not reach the AI tutor.',
      ),
    );
    expect(find.text('Could not reach the AI tutor.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(chat.retries, 1);
  });
}
