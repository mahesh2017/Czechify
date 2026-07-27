import 'package:ceskina_pro/core/feedback/celebration.dart';
import 'package:ceskina_pro/core/theme/app_theme.dart';
import 'package:ceskina_pro/presentation/widgets/celebration/unit_complete_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

void main() {
  Future<int> show(
    WidgetTester tester,
    UnitCompleted unit, {
    bool reduceMotion = false,
  }) async {
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        theme: lightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: UnitCompleteOverlay(
            celebration: unit,
            onDismiss: () => dismissed++,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    return dismissed;
  }

  const unit = UnitCompleted(
    unitId: 4,
    unitNumber: 2,
    unitTitle: 'Greetings',
    nextUnitTitle: 'At the Café',
  );

  testWidgets('it shows the unit the learner just finished', (tester) async {
    await show(tester, unit);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Greetings'), findsOneWidget);
  });

  testWidgets('it names what that opened up', (tester) async {
    // The whole reason this ceremony has no dismiss timer: it is the one
    // moment the app has to point at what comes next.
    await show(tester, unit);
    expect(find.textContaining('At the Café'), findsOneWidget);
    expect(find.textContaining('Unit 3'), findsOneWidget);
  });

  testWidgets('the end of a phase promises nothing that does not exist', (
    tester,
  ) async {
    await show(
      tester,
      const UnitCompleted(unitId: 9, unitNumber: 9, unitTitle: 'Review'),
    );
    expect(find.textContaining('is now open'), findsNothing);
  });

  testWidgets('a milestone unit is marked as one', (tester) async {
    await show(
      tester,
      const UnitCompleted(unitId: 7, unitNumber: 5, unitTitle: 'Numbers'),
    );
    expect(find.textContaining('MILESTONE'), findsOneWidget);
  });

  testWidgets('an ordinary unit is not', (tester) async {
    await show(tester, unit);
    expect(find.textContaining('MILESTONE'), findsNothing);
  });

  testWidgets('continuing dismisses it', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        theme: lightTheme(),
        home: UnitCompleteOverlay(
          celebration: unit,
          onDismiss: () => dismissed++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.text('Continue'));
    expect(dismissed, 1);
  });

  testWidgets('reduce motion still shows the whole ceremony', (tester) async {
    // No stamp, no shockwave, no confetti — but every word of it, and the
    // button that leads onward.
    await show(tester, unit, reduceMotion: true);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('At the Café'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('sharing is offered but never automatic', (tester) async {
    // The button opens the OS share sheet; nothing leaves the device until
    // the learner picks a destination there.
    await show(tester, unit);
    expect(find.text('Share'), findsOneWidget);
  });
}
