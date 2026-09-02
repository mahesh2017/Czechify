import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/common/motion_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('motion swap renders its new keyed state immediately when off', (
    tester,
  ) async {
    var state = 0;
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, update) {
              setState = update;
              return MotionSwap(
                child: Text('state $state', key: ValueKey(state)),
              );
            },
          ),
        ),
      ),
    );

    setState(() => state = 1);
    await tester.pump();

    expect(find.text('state 0'), findsNothing);
    expect(find.text('state 1'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('outgoing swap content immediately loses input and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var state = 0;
    var oldTaps = 0;
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: StatefulBuilder(
          builder: (context, update) {
            setState = update;
            return Center(
              child: MotionSwap(
                child:
                    state == 0
                        ? Semantics(
                          key: const ValueKey('old'),
                          label: 'Old action',
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => oldTaps++,
                            child: const SizedBox(
                              width: 120,
                              height: 48,
                              child: Text('old'),
                            ),
                          ),
                        )
                        : const SizedBox(
                          key: ValueKey('new'),
                          width: 120,
                          height: 48,
                          child: Text('new'),
                        ),
              ),
            );
          },
        ),
      ),
    );

    setState(() => state = 1);
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.bySemanticsLabel('Old action'), findsNothing);
    await tester.tapAt(tester.getCenter(find.text('new')));
    expect(oldTaps, 0);
    semantics.dispose();
  });

  testWidgets('disclosure clips, fades, and settles without hidden semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var visible = true;
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: StatefulBuilder(
          builder: (context, update) {
            setState = update;
            return MotionDisclosure(
              visible: visible,
              child: Semantics(
                label: 'Supporting hint',
                child: const SizedBox(height: 80, child: Text('hint')),
              ),
            );
          },
        ),
      ),
    );

    setState(() => visible = false);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.bySemanticsLabel('Supporting hint'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('hint'), findsNothing);
    semantics.dispose();
  });

  testWidgets('disclosure renders its hidden state immediately when off', (
    tester,
  ) async {
    var visible = true;
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, update) {
              setState = update;
              return MotionDisclosure(
                visible: visible,
                child: const Text('reduced hint'),
              );
            },
          ),
        ),
      ),
    );

    setState(() => visible = false);
    await tester.pump();

    expect(find.text('reduced hint'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
