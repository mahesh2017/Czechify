import 'package:czechify/core/age_signals/play_age_signals_service.dart';
import 'package:czechify/presentation/screens/compliance/age_signals_gate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('verification gate explains recovery and exposes both actions', (
    tester,
  ) async {
    var retries = 0;
    var storeOpens = 0;
    await tester.pumpWidget(
      AgeSignalsGateApp(
        decision: const AgeEligibilityDecision(
          AgeEligibilityOutcome.verificationRequired,
        ),
        onRetry: () => retries++,
        onOpenPlayStore: () => storeOpens++,
      ),
    );

    expect(find.text('Confirm your age in Google Play'), findsOneWidget);
    expect(find.text('Open Google Play'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);

    await tester.tap(find.text('Open Google Play'));
    await tester.tap(find.text('Check again'));
    expect(storeOpens, 1);
    expect(retries, 1);
  });

  testWidgets('pending approval gate does not send the learner to Play Store', (
    tester,
  ) async {
    await tester.pumpWidget(
      AgeSignalsGateApp(
        decision: const AgeEligibilityDecision(
          AgeEligibilityOutcome.parentApprovalPending,
        ),
        onRetry: () {},
        onOpenPlayStore: () {},
      ),
    );

    expect(find.text('Parent approval is pending'), findsOneWidget);
    expect(
      find.widgetWithIcon(FilledButton, Icons.shop_outlined),
      findsNothing,
    );
    expect(find.text('Check again'), findsOneWidget);
  });

  testWidgets('each refusal has its own explanation', (tester) async {
    for (final (outcome, title, store) in [
      (
        AgeEligibilityOutcome.underMinimumAge,
        'Czechify is for ages 16 and over',
        true,
      ),
      (
        AgeEligibilityOutcome.parentApprovalDeclined,
        'Parent approval is required',
        false,
      ),
      (
        AgeEligibilityOutcome.temporarilyUnavailable,
        'Age check is temporarily unavailable',
        true,
      ),
    ]) {
      await tester.pumpWidget(
        AgeSignalsGateApp(
          key: ValueKey(outcome),
          decision: AgeEligibilityDecision(outcome),
          onRetry: () {},
          onOpenPlayStore: () {},
        ),
      );
      expect(find.text(title), findsOneWidget, reason: '$outcome');
      expect(
        find.text('Open Google Play'),
        store ? findsOneWidget : findsNothing,
        reason: '$outcome',
      );
    }
  });

  testWidgets('an allowed learner never sees the gate', (tester) async {
    await tester.pumpWidget(
      AgeSignalsGateApp(
        decision: const AgeEligibilityDecision(AgeEligibilityOutcome.allowed),
        onRetry: () {},
        onOpenPlayStore: () {},
      ),
    );
    expect(tester.takeException(), isStateError);
  });
}
