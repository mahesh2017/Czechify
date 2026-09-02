import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/common/lesson_ui.dart';
import 'package:czechify/presentation/widgets/common/learning_tip_card.dart';
import 'package:czechify/presentation/widgets/common/motion_widgets.dart';
import 'package:czechify/presentation/widgets/common/record_button.dart';
import 'package:czechify/presentation/widgets/common/soft_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {bool reducedMotion = false, double scale = 1}) {
    return MaterialApp(
      theme: lightTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reducedMotion,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('progress starts at restored value and animates only updates', (
    tester,
  ) async {
    var progress = 0.25;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SizedBox(
              width: 240,
              child: SoftProgressBar(value: progress),
            );
          },
        ),
      ),
    );

    double paintedValue() =>
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value!;

    expect(paintedValue(), 0.25);
    update(() => progress = 0.75);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(paintedValue(), inExclusiveRange(0.25, 0.75));

    // Retargeting uses the currently painted value instead of jumping to the
    // previous destination first.
    final beforeRetarget = paintedValue();
    update(() => progress = 0.4);
    await tester.pump();
    expect(paintedValue(), closeTo(beforeRetarget, 0.001));
    await tester.pumpAndSettle();
    expect(paintedValue(), closeTo(0.4, 0.001));
  });

  testWidgets('changing values render immediately without motion', (
    tester,
  ) async {
    var value = 3;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MotionNumberText(value);
          },
        ),
        reducedMotion: true,
      ),
    );
    await tester.pumpAndSettle();

    update(() => value = 12);
    await tester.pump();
    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('score ring interpolates its sweep and percentage together', (
    tester,
  ) async {
    var fraction = 0.2;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ScoreRing(
              fraction: fraction,
              label: '${(fraction * 100).round()}%',
              caption: 'accuracy',
            );
          },
        ),
      ),
    );

    double ringValue() =>
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value!;

    expect(ringValue(), 0.2);
    expect(find.text('20%'), findsOneWidget);
    update(() => fraction = 0.8);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ringValue(), inExclusiveRange(0.2, 0.8));
    expect(find.text('20%'), findsNothing);
    expect(find.text('80%'), findsNothing);
    await tester.pumpAndSettle();
    expect(ringValue(), closeTo(0.8, 0.001));
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('earned score opts into a mount sweep with a reduced fallback', (
    tester,
  ) async {
    const score = ScoreRing(
      fraction: 0.8,
      label: '80%',
      caption: 'accuracy',
      animateOnMount: true,
    );
    await tester.pumpWidget(host(score));
    double ringValue() =>
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value!;

    expect(ringValue(), 0);
    expect(find.text('0%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(ringValue(), inExclusiveRange(0, 0.8));
    await tester.pumpAndSettle();
    expect(ringValue(), closeTo(0.8, 0.001));
    expect(find.text('80%'), findsOneWidget);

    await tester.pumpWidget(host(const SizedBox.shrink()));
    await tester.pumpWidget(host(score, reducedMotion: true));
    await tester.pumpAndSettle();
    expect(ringValue(), closeTo(0.8, 0.001));
    expect(find.text('80%'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('tappable cards and primary buttons have press depth', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 320,
          child: SoftCard(onTap: () {}, child: const Text('Open lesson')),
        ),
      ),
    );
    final cardGesture = await tester.startGesture(
      tester.getCenter(find.text('Open lesson')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final cardScale = find.descendant(
      of: find.byType(SoftCard),
      matching: find.byType(ScaleTransition),
    );
    expect(tester.widget<ScaleTransition>(cardScale).scale.value, lessThan(1));
    await cardGesture.up();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      host(
        SizedBox(
          width: 320,
          child: PrimaryButton(label: 'Continue', onPressed: () {}),
        ),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    final buttonGesture = await tester.startGesture(
      tester.getCenter(find.text('Continue')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final buttonScale = find.descendant(
      of: find.byType(PrimaryButton),
      matching: find.byType(ScaleTransition),
    );
    expect(
      tester.widget<ScaleTransition>(buttonScale).scale.value,
      lessThan(1),
    );
    await buttonGesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('record state changes fill and icon without losing semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var recording = false;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return RecordButton(isRecording: recording, onPressed: () {});
          },
        ),
      ),
    );
    expect(find.bySemanticsLabel('Start recording'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    update(() => recording = true);
    await tester.pump();
    expect(find.bySemanticsLabel('Stop recording'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);

    // Stop the repeating recording ring before the test exits.
    update(() => recording = false);
    await tester.pump();
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('record state schedules no animation frames when motion is off', (
    tester,
  ) async {
    var recording = false;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return RecordButton(isRecording: recording, onPressed: () {});
          },
        ),
        reducedMotion: true,
      ),
    );
    await tester.pumpAndSettle();

    update(() => recording = true);
    await tester.pump();
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('learning tip remains usable at 200 percent text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SingleChildScrollView(
          child: SizedBox(width: 340, child: LearningTipCard()),
        ),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);

    final card = find.byType(LearningTipCard);
    final before =
        tester
            .widgetList<Text>(
              find.descendant(of: card, matching: find.byType(Text)),
            )
            .map((text) => text.data)
            .toList();
    await tester.tapAt(tester.getTopLeft(card) + const Offset(100, 100));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('💡 Tip of the day'), findsOneWidget);
    final after =
        tester
            .widgetList<Text>(
              find.descendant(of: card, matching: find.byType(Text)),
            )
            .map((text) => text.data)
            .toList();
    expect(after, isNot(equals(before)));
  });
}
