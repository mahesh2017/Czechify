import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/l10n/app_localizations.dart';
import 'package:czechify/presentation/providers/chat_providers.dart';
import 'package:czechify/presentation/routes/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder:
              (context, state, navigationShell) =>
                  AdaptiveScaffold(navigationShell: navigationShell),
          branches: [
            _branch('/', 'home'),
            _branch('/curriculum', 'learn'),
            _branch('/review', 'review'),
            _branch('/chat', 'chat'),
            _branch('/stats', 'stats'),
          ],
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  Widget host({bool disableAnimations = false, _TestChatNotifier? chat}) =>
      ProviderScope(
        overrides: [if (chat != null) chatProvider.overrideWith(() => chat)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: lightTheme(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: disableAnimations),
                child: child!,
              ),
        ),
      );

  testWidgets('switching tabs preserves local state and scroll position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-increment')));
    await tester.drag(
      find.byKey(const ValueKey('home-list')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    final before = _scrollPosition(tester, 'home');
    expect(before, greaterThan(0));

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('learn count 0'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('home count 1'), findsOneWidget);
    expect(_scrollPosition(tester, 'home'), closeTo(before, 0.1));
  });

  testWidgets('branch change has a restrained incoming transition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final opacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('branch-transition-opacity')),
    );
    expect(opacity.opacity, inExclusiveRange(0.88, 1));
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion switches branches without transition frames', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(disableAnimations: true));
    await tester.pumpAndSettle();
    router.go('/curriculum');
    await tester.pump();

    final opacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('branch-transition-opacity')),
    );
    expect(opacity.opacity, 1);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('bottom navigation follows active chat state smoothly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final chat = _TestChatNotifier();
    await tester.pumpWidget(host(chat: chat));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsNothing);
    chat.endConversation();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}

StatefulShellBranch _branch(String path, String name) => StatefulShellBranch(
  routes: [
    GoRoute(path: path, builder: (context, state) => _ProbeScreen(name: name)),
  ],
);

double _scrollPosition(WidgetTester tester, String name) {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(
      of: find.byKey(ValueKey('$name-list')),
      matching: find.byType(Scrollable),
    ),
  );
  return scrollable.position.pixels;
}

class _ProbeScreen extends StatefulWidget {
  const _ProbeScreen({required this.name});

  final String name;

  @override
  State<_ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<_ProbeScreen> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${widget.name} count $count'),
        FilledButton(
          key: ValueKey('${widget.name}-increment'),
          onPressed: () => setState(() => count++),
          child: const Text('increment'),
        ),
        Expanded(
          child: ListView.builder(
            key: ValueKey('${widget.name}-list'),
            itemExtent: 56,
            itemCount: 50,
            itemBuilder: (context, index) => Text('${widget.name} item $index'),
          ),
        ),
      ],
    );
  }
}

class _TestChatNotifier extends ChatNotifier {
  @override
  ChatState build() => const ChatState(conversationId: 'active');

  void endConversation() => state = const ChatState();
}
