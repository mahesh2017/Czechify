import 'package:ceskina_pro/presentation/routes/lesson_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget app({required String initialLocation}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          builder:
              (context, _) => Scaffold(
                body: Column(
                  children: [
                    const Text('Home'),
                    TextButton(
                      onPressed: () => context.push('/lesson'),
                      child: const Text('Open lesson'),
                    ),
                  ],
                ),
              ),
        ),
        GoRoute(
          path: '/lesson',
          builder:
              (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => leaveLesson(context),
                  child: const Text('Leave lesson'),
                ),
              ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('a directly opened lesson leaves to Home', (tester) async {
    await tester.pumpWidget(app(initialLocation: '/lesson'));

    await tester.tap(find.text('Leave lesson'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a pushed lesson returns to its caller', (tester) async {
    await tester.pumpWidget(app(initialLocation: '/'));
    await tester.tap(find.text('Open lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Leave lesson'), findsOneWidget);

    await tester.tap(find.text('Leave lesson'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}
