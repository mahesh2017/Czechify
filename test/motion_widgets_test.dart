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

  testWidgets('incoming entrance disposes outgoing resources immediately', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var state = 0;
    var disposals = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MotionEntrance(
              key: ValueKey(state),
              child: _DisposeProbe(
                label: 'Question $state',
                onDispose: () => disposals++,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    update(() => state = 1);
    await tester.pump();
    expect(disposals, 1);
    expect(find.text('Question 0'), findsNothing);
    expect(find.bySemanticsLabel('Question 0'), findsNothing);
    expect(find.text('Question 1'), findsOneWidget);

    // A second advance before the entrance settles still leaves exactly one
    // live subtree; the intermediate question cannot become stale UI.
    update(() => state = 2);
    await tester.pump(const Duration(milliseconds: 1));
    expect(disposals, 2);
    expect(find.text('Question 1'), findsNothing);
    expect(find.bySemanticsLabel('Question 1'), findsNothing);
    expect(find.text('Question 2'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('incoming entrance schedules no reduced-motion frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MotionEntrance(child: Text('Final question')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Final question'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

class _DisposeProbe extends StatefulWidget {
  const _DisposeProbe({required this.label, required this.onDispose});

  final String label;
  final VoidCallback onDispose;

  @override
  State<_DisposeProbe> createState() => _DisposeProbeState();
}

class _DisposeProbeState extends State<_DisposeProbe> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(label: widget.label, child: Text(widget.label));
  }
}
