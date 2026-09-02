import 'package:czechify/core/theme/app_motion.dart';
import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/common/lesson_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('motion durations resolve to zero when motion is disabled', (
    tester,
  ) async {
    late BuildContext reducedContext;
    late BuildContext standardContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Column(
          children: [
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  reducedContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
            MediaQuery(
              data: const MediaQueryData(disableAnimations: false),
              child: Builder(
                builder: (context) {
                  standardContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(reducedContext.motionDisabled, isTrue);
    expect(reducedContext.motionDuration(AppMotion.content), Duration.zero);
    expect(standardContext.motionDisabled, isFalse);
    expect(
      standardContext.motionDuration(AppMotion.content),
      AppMotion.content,
    );
  });

  testWidgets('reduced-motion XP feedback stays readable then completes', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: XpFlyUp(label: '+10 XP', onCompleted: () => completions++),
        ),
      ),
    );

    expect(find.text('+10 XP'), findsOneWidget);
    expect(completions, 0);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pump(
      AppMotion.reducedFeedbackHold - const Duration(milliseconds: 1),
    );
    expect(completions, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(completions, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('standard XP feedback completes after its visible animation', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: XpFlyUp(label: '+10 XP', onCompleted: () => completions++),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(completions, 0);

    await tester.pumpAndSettle();
    expect(completions, 1);
  });
}
