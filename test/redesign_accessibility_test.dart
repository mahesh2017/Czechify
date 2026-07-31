import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceskina_pro/presentation/widgets/home/streak_state_sheet.dart';
import 'support/localized_app.dart';

void main() {
  testWidgets('protected streak remains readable at 200 percent text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed:
                          () => showStreakStateSheet(
                            context,
                            streak: 8,
                            freezeAvailable: false,
                          ),
                      child: const Text('Open streak'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open streak'));
    await tester.pumpAndSettle();

    expect(find.text('Streak protected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('streak action meets the 44 point target minimum', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: FilledButton(
                  onPressed:
                      () => showStreakStateSheet(
                        context,
                        streak: 0,
                        freezeAvailable: true,
                      ),
                  child: const Text('Open streak'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Open streak'));
    await tester.pumpAndSettle();

    final size = tester.getSize(
      find.widgetWithText(FilledButton, 'Begin again'),
    );
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
