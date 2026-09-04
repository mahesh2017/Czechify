import 'package:czechify/core/theme/app_motion.dart';
import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/common/motion_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Batch 8 — release validation for the shared motion language.
///
/// Earlier batches proved each transition in the screen that uses it. These
/// cover the four release concerns those batches deferred, at the primitive
/// level where every screen inherits the result: what a reduced-motion or
/// large-text user gets, whether the frames between the start and end states
/// are real motion rather than a snap, what happens when a transition is
/// interrupted partway, and whether anything keeps working after it settles.
void main() {
  group('accessibility', () {
    testWidgets('reduced motion announces incoming content on its first frame', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var step = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          disableAnimations: true,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MotionEntrance(
                key: ValueKey(step),
                child: Text('Step $step'),
              );
            },
          ),
        ),
      );

      update(() => step = 1);
      await tester.pump();

      // A fade-in leaves its first frame fully transparent, which drops the
      // subtree from the semantics tree. Reduced motion has to skip that frame
      // entirely, or a screen reader announces the step late.
      expect(find.bySemanticsLabel('Step 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 0'), findsNothing);
      semantics.dispose();
    });

    testWidgets('reduced motion swaps announce the new state immediately', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var state = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          disableAnimations: true,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MotionSwap(
                child: Text('Answer $state', key: ValueKey(state)),
              );
            },
          ),
        ),
      );

      update(() => state = 1);
      await tester.pump();

      expect(find.bySemanticsLabel('Answer 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Answer 0'), findsNothing);
      semantics.dispose();
    });

    testWidgets('primitives stay laid out at 200 percent text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          textScale: 2,
          child: const SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MotionSwap(
                  child: Text(
                    'Poslouchejte a vyberte správnou odpověď',
                    key: ValueKey('prompt'),
                  ),
                ),
                MotionDisclosure(
                  visible: true,
                  child: Text('Nápověda: sloveso stojí na druhé pozici.'),
                ),
                MotionNumberText(1250, prefix: '+', suffix: ' XP'),
                MotionEntrance(child: Text('Pokračovat')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No overflow, and every primitive stays inside the width it was given
      // rather than pushing its content off-screen at the largest text size.
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Nápověda'), findsOneWidget);
      expect(find.text('+1250 XP'), findsOneWidget);
      for (final text in find.byType(Text).evaluate()) {
        expect(
          tester.getSize(find.byWidget(text.widget)).width,
          lessThanOrEqualTo(320),
        );
      }

      // The prompt wraps instead of clipping, which is what proves the scale
      // was actually applied rather than silently ignored.
      expect(
        tester
            .getSize(find.text('Poslouchejte a vyberte správnou odpověď'))
            .height,
        greaterThan(40),
      );
    });
  });

  group('intermediate frames', () {
    testWidgets('an entrance fades and lifts through its midpoint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(child: const MotionEntrance(child: Text('Nová otázka'))),
      );

      final samples = <double>[];
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        samples.add(_entranceOpacity(tester));
      }

      // Every sample sits strictly inside the range, so the entrance is real
      // motion rather than a delayed snap, and it only ever moves forward.
      for (final sample in samples) {
        expect(sample, greaterThan(0));
        expect(sample, lessThan(1));
      }
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i], greaterThan(samples[i - 1]));
      }
      expect(_entranceTranslation(tester).dy, greaterThan(0));

      await tester.pumpAndSettle();
      expect(_entranceOpacity(tester), 1);
      expect(_entranceTranslation(tester), Offset.zero);
    });

    testWidgets('a value change passes through the numbers between', (
      tester,
    ) async {
      var value = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MotionNumberText(value, duration: AppMotion.reward);
            },
          ),
        ),
      );
      expect(find.text('0'), findsOneWidget);

      update(() => value = 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final midpoint = _renderedNumber(tester);
      expect(midpoint, greaterThan(0));
      expect(midpoint, lessThan(100));

      await tester.pump(const Duration(milliseconds: 150));
      expect(_renderedNumber(tester), greaterThanOrEqualTo(midpoint));

      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('a disclosure grows through a partial height', (tester) async {
      var visible = false;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MotionDisclosure(
                visible: visible,
                child: const SizedBox(height: 120, child: Text('Nápověda')),
              );
            },
          ),
        ),
      );

      update(() => visible = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));

      final partial = _disclosureHeight(tester);
      expect(partial, greaterThan(0));
      expect(partial, lessThan(120));

      await tester.pumpAndSettle();
      expect(_disclosureHeight(tester), 120);
    });
  });

  group('interruption', () {
    testWidgets('turning on reduced motion mid-entrance snaps and stops', (
      tester,
    ) async {
      var reduced = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme(),
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: const MotionEntrance(child: Text('Nová otázka')),
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(_entranceOpacity(tester), lessThan(1));

      update(() => reduced = true);
      await tester.pump();

      expect(_entranceOpacity(tester), 1);
      expect(_entranceTranslation(tester), Offset.zero);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('turning on reduced motion mid-count snaps to the target', (
      tester,
    ) async {
      var reduced = false;
      var value = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme(),
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: MotionNumberText(value, duration: AppMotion.reward),
              );
            },
          ),
        ),
      );

      update(() => value = 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_renderedNumber(tester), lessThan(100));

      update(() => reduced = true);
      await tester.pump();

      expect(find.text('100'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('retargeting mid-count continues from the visible number', (
      tester,
    ) async {
      var value = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MotionNumberText(value, duration: AppMotion.reward);
            },
          ),
        ),
      );

      update(() => value = 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final interrupted = _renderedNumber(tester);
      expect(interrupted, greaterThan(0));

      // A second award arriving mid-count must not rewind the visible total.
      update(() => value = 160);
      await tester.pump();
      expect(_renderedNumber(tester), greaterThanOrEqualTo(interrupted));

      await tester.pump(const Duration(milliseconds: 100));
      expect(_renderedNumber(tester), greaterThanOrEqualTo(interrupted));

      await tester.pumpAndSettle();
      expect(find.text('160'), findsOneWidget);
    });

    testWidgets('a disclosure reopened mid-exit settles fully open', (
      tester,
    ) async {
      var visible = true;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MotionDisclosure(
                visible: visible,
                child: const SizedBox(height: 120, child: Text('Nápověda')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() => visible = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      update(() => visible = true);
      await tester.pumpAndSettle();

      expect(find.text('Nápověda'), findsOneWidget);
      expect(_disclosureHeight(tester), 120);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('rapid swaps settle on one live child', (tester) async {
      var state = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MotionSwap(
                child: Text('Answer $state', key: ValueKey(state)),
              );
            },
          ),
        ),
      );

      for (var next = 1; next <= 3; next++) {
        update(() => state = next);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      expect(find.text('Answer 3'), findsOneWidget);
      for (final stale in const ['Answer 0', 'Answer 1', 'Answer 2']) {
        expect(find.text(stale), findsNothing);
      }
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('disposing mid-transition schedules no further frames', (
      tester,
    ) async {
      var showing = true;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return showing
                  ? const MotionEntrance(child: Text('Nová otázka'))
                  : const Text('Konec');
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      // Leaving a lesson mid-entrance has to take the ticker with it, or the
      // screen keeps paying for frames nobody sees.
      update(() => showing = false);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Nová otázka'), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('performance', () {
    testWidgets('an entrance repaints without rebuilding its content', (
      tester,
    ) async {
      var builds = 0;
      await tester.pumpWidget(
        _app(
          child: MotionEntrance(child: _BuildCounter(onBuild: () => builds++)),
        ),
      );
      expect(builds, 1);

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // The transition drives opacity and translation only. Rebuilding the
      // exercise underneath on every frame is what made earlier motion work
      // expensive, so hold the line here rather than in each screen.
      expect(builds, 1);
    });

    testWidgets('a swap rebuilds neither child per frame', (tester) async {
      var incomingBuilds = 0;
      var state = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MotionSwap(
                child: state == 0
                    ? const SizedBox(key: ValueKey(0), child: Text('First'))
                    : _BuildCounter(
                        key: const ValueKey(1),
                        onBuild: () => incomingBuilds++,
                      ),
              );
            },
          ),
        ),
      );

      update(() => state = 1);
      await tester.pump();
      expect(incomingBuilds, 1);

      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();

      expect(incomingBuilds, 1);
    });

    testWidgets('settled primitives leave no transient callbacks', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MotionEntrance(child: Text('Nová otázka')),
              MotionSwap(child: Text('Answer', key: ValueKey('a'))),
              MotionDisclosure(visible: true, child: Text('Nápověda')),
              MotionNumberText(42),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}

Widget _app({
  required Widget child,
  bool disableAnimations = false,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: lightTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

double _entranceOpacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find
            .descendant(
              of: find.byType(MotionEntrance),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;
}

Offset _entranceTranslation(WidgetTester tester) {
  return tester
      .widget<FractionalTranslation>(
        find
            .descendant(
              of: find.byType(MotionEntrance),
              matching: find.byType(FractionalTranslation),
            )
            .first,
      )
      .translation;
}

int _renderedNumber(WidgetTester tester) {
  final text = tester.widget<Text>(
    find
        .descendant(
          of: find.byType(MotionNumberText),
          matching: find.byType(Text),
        )
        .first,
  );
  return int.parse(RegExp(r'-?\d+').firstMatch(text.data!)!.group(0)!);
}

double _disclosureHeight(WidgetTester tester) {
  // A disclosure in flight holds both the outgoing collapsed entry and the
  // incoming content, so measure the clip that actually wraps the content.
  return tester
      .getSize(
        find
            .ancestor(
              of: find.text('Nápověda'),
              matching: find.byType(ClipRect),
            )
            .first,
      )
      .height;
}

class _BuildCounter extends StatelessWidget {
  const _BuildCounter({super.key, required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const Text('Content');
  }
}
