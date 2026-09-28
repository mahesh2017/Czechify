import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/common/scrolling_passage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// A long reading text scrolls inside its box, and says so (Mahesh, 28 Sep
/// 2026: "there should be clear indication that text box is scrollable").
void main() {
  Future<void> show(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: ScrollingPassage(child: Text(text))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double hintOpacity(WidgetTester tester) =>
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.text('Scroll the text for more'),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

  testWidgets('a text that fits shows no scroll cue', (tester) async {
    await show(tester, 'Ahoj Pavle, děkuju za e-mail.');
    expect(hintOpacity(tester), 0);
  });

  testWidgets('a longer text says it scrolls, until its end is reached', (
    tester,
  ) async {
    await show(tester, List.filled(40, 'Měl jsem hezký víkend.').join(' '));
    expect(hintOpacity(tester), 1);
    // The scrollbar stays visible, not only while dragging.
    expect(
      tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
      isTrue,
    );

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(hintOpacity(tester), 0);
  });
}
