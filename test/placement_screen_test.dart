import 'package:ceskina_pro/presentation/screens/placement/placement_screen.dart';
import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/presentation/widgets/common/lesson_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/localized_app.dart';

void main() {
  testWidgets('placement starts with a provisional multiskill diagnostic', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: _PlacementTestApp()));

    expect(find.text('Find my starting point'), findsOneWidget);
    expect(find.text('Question 1 · adaptive test'), findsOneWidget);
    expect(find.text('READING'), findsOneWidget);
    expect(find.byType(QuizOptionTile), findsNWidgets(3));
    expect(tester.widget<KeyCta>(find.byType(KeyCta)).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing a valid writing answer enables Next immediately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: _PlacementTestApp()));

    // The diagnostic balances skills, so its first reading and listening
    // questions are followed by the first writing question.
    for (var i = 0; i < 2; i++) {
      if (find.byType(ListenPanel).evaluate().isNotEmpty) {
        await tester.tap(
          find
              .descendant(
                of: find.byType(ListenPanel),
                matching: find.byType(InkWell),
              )
              .first,
        );
        await tester.pump();
      }
      await tester.tap(find.byType(QuizOptionTile).first);
      await tester.pump();
      await tester.tap(find.byType(KeyCta));
      await tester.pump();
    }

    expect(find.text('Write in Czech: “Hello.”'), findsOneWidget);
    expect(tester.widget<KeyCta>(find.byType(KeyCta)).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Dobrý Den');
    await tester.pump();

    expect(tester.widget<KeyCta>(find.byType(KeyCta)).onPressed, isNotNull);
  });
}

class _PlacementTestApp extends StatelessWidget {
  const _PlacementTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightTheme(),
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: const PlacementScreen(),
    );
  }
}
