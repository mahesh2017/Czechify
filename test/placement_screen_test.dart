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
    expect(find.text('READING'), findsOneWidget);
    expect(find.byType(QuizOptionTile), findsNWidgets(3));
    expect(tester.widget<KeyCta>(find.byType(KeyCta)).onPressed, isNull);
    expect(tester.takeException(), isNull);
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
