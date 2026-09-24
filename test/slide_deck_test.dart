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

  Future<void> pumpDeck(WidgetTester tester, Widget deck) async {
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
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
        home: Scaffold(body: deck),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a packed deck puts as many blocks on a slide as fit, and says '
      'which ones follow another', (tester) async {
    final deck = GlobalKey<SlideDeckState>();
    await pumpDeck(
      tester,
      SlideDeck.packed(
        key: deck,
        blockCount: 5,
        // Two 200-high blocks fit the small phone's slide; three do not.
        blockBuilder:
            (context, i, leads) => SizedBox(
              height: 200,
              child: Text('Block $i ${leads ? 'leads' : 'follows'}'),
            ),
        doneLabel: 'Continue',
        onDone: () {},
      ),
    );

    expect(deck.currentState!.length, 3);
    expect(find.text('Block 0 leads'), findsOneWidget);
    expect(find.text('Block 1 follows'), findsOneWidget);
    expect(find.text('Block 2 leads'), findsNothing);

    deck.currentState!.showBlock(4);
    await tester.pump();
    expect(find.text('Block 4 leads'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Next waits until the slide allows it', (tester) async {
    var answered = false;
    late StateSetter update;
    await pumpDeck(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return SlideDeck(
            slides: const [Text('Question'), Text('Last')],
            canAdvance: (i) => i != 0 || answered,
            doneLabel: 'Check',
            onDone: () {},
          );
        },
      ),
    );

    await tester.tap(find.byKey(SlideDeck.nextKey));
    await tester.pump();
    expect(find.text('Question'), findsOneWidget);

    update(() => answered = true);
    await tester.pump();
    await tester.tap(find.byKey(SlideDeck.nextKey));
    await tester.pump();
    expect(find.text('Last'), findsOneWidget);
    expect(find.byKey(SlideDeck.doneKey), findsOneWidget);
  });

  testWidgets('a finished deck has no buttons; its slides still swipe', (
    tester,
  ) async {
    await pumpDeck(
      tester,
      SlideDeck(
        slides: const [Text('One'), Text('Two')],
        doneLabel: 'Check',
        onDone: () {},
        finished: true,
      ),
    );
    expect(find.byKey(SlideDeck.nextKey), findsNothing);
    expect(find.byKey(SlideDeck.backKey), findsNothing);
    await tester.fling(find.text('One'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);
  });

  testWidgets('a packed deck spreads blocks evenly over the fewest slides, '
      'rather than leaving one alone on the last', (tester) async {
    final deck = GlobalKey<SlideDeckState>();
    await pumpDeck(
      tester,
      SlideDeck.packed(
        key: deck,
        blockCount: 5,
        // Four fit a slide, so five need two: three and two, not four and one.
        blockBuilder:
            (context, i, _) => SizedBox(height: 100, child: Text('Block $i')),
        doneLabel: 'Continue',
        onDone: () {},
      ),
    );

    expect(deck.currentState!.length, 2);
    expect(find.text('Block 2'), findsOneWidget);
    expect(find.text('Block 3'), findsNothing);
  });

  testWidgets('a block taller than a slide gets one to itself and the rest '
      'still fit', (tester) async {
    final deck = GlobalKey<SlideDeckState>();
    await pumpDeck(
      tester,
      SlideDeck.packed(
        key: deck,
        blockCount: 3,
        blockBuilder:
            (context, i, _) =>
                SizedBox(height: i == 0 ? 900 : 200, child: Text('Block $i')),
        doneLabel: 'Continue',
        onDone: () {},
      ),
    );

    expect(deck.currentState!.length, 2);
    deck.currentState!.goTo(1);
    await tester.pump();
    expect(find.text('Block 1'), findsOneWidget);
    expect(find.text('Block 2'), findsOneWidget);
  });

  testWidgets('a deck its text fields drive with Return gives the keyboard '
      'the buttons\' room; an ordinary deck keeps them', (tester) async {
    for (final returnKey in [true, false]) {
      await pumpDeck(
        tester,
        SlideDeck(
          key: ValueKey(returnKey),
          slides: const [Text('One'), Text('Two')],
          doneLabel: 'Check',
          onDone: () {},
          returnKeyAdvances: returnKey,
        ),
      );
      expect(find.byKey(SlideDeck.nextKey), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pump();
      expect(
        find.byKey(SlideDeck.nextKey),
        returnKey ? findsNothing : findsOneWidget,
      );

      tester.view.resetViewInsets();
      await tester.pump();
      expect(find.byKey(SlideDeck.nextKey), findsOneWidget);
    }
  });
}
