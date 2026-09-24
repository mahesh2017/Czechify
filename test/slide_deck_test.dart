import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/common/slide_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

void main() {
  Future<List<String>> pump(
    WidgetTester tester, {
    List<Widget>? slides,
    double textScale = 1,
  }) async {
    final done = <String>[];
    tester.view.physicalSize = const Size(375, 557);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: Scaffold(
          body: SlideDeck(
            slides:
                slides ??
                const [Text('One'), Text('Two'), Text('Three')],
            doneLabel: 'Continue',
            onDone: () => done.add('done'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return done;
  }

  testWidgets('Next and Back turn the slides; the last one finishes', (
    tester,
  ) async {
    final done = await pump(tester);

    expect(find.text('One'), findsOneWidget);
    expect(find.byKey(SlideDeck.backKey), findsNothing);
    expect(find.bySemanticsLabel('Slide 1 of 3'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);
    expect(find.bySemanticsLabel('Slide 2 of 3'), findsOneWidget);

    await tester.tap(find.byKey(SlideDeck.backKey));
    await tester.pumpAndSettle();
    expect(find.text('One'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Three'), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Continue'));
    expect(done, ['done']);
  });

  testWidgets('a swipe turns the slide too', (tester) async {
    await pump(tester);
    await tester.fling(find.text('One'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);
  });

  testWidgets('one slide shows no dots and finishes straight away', (
    tester,
  ) async {
    await pump(tester, slides: const [Text('Only')]);
    expect(find.bySemanticsLabel(RegExp('Slide')), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('a slide too tall at large text scrolls; its text is never '
      'shrunk', (tester) async {
    await pump(
      tester,
      textScale: 2,
      slides: [
        Column(
          children: [for (var i = 0; i < 20; i++) Text('Line $i')],
        ),
      ],
    );
    final line = tester.getSize(find.text('Line 0'));
    final plain = TextPainter(
      text: const TextSpan(text: 'Line 0'),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(line.height, greaterThan(plain.height * 1.5));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(PageView),
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduced motion a turn lands at once', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
        home: Scaffold(
          body: SlideDeck(
            slides: const [Text('One'), Text('Two')],
            doneLabel: 'Continue',
            onDone: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('One'), findsNothing);
  });
}
