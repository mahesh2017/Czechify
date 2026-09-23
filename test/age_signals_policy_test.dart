import 'package:czechify/core/age_signals/play_age_signals_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Play Age Signals 16+ policy', () {
    test('allows supported 16–17 and 18+ ranges', () {
      expect(
        evaluateAgeEligibility(
          const AgeSignalsSnapshot(
            status: AgeSignalsStatus.shared,
            ageLower: 16,
            ageUpper: 17,
          ),
        ).outcome,
        AgeEligibilityOutcome.allowed,
      );
      expect(
        evaluateAgeEligibility(
          const AgeSignalsSnapshot(
            status: AgeSignalsStatus.shared,
            ageLower: 18,
          ),
        ).outcome,
        AgeEligibilityOutcome.allowed,
      );
    });

    test('blocks every default range below 16', () {
      for (final range in [(0, 12), (13, 15)]) {
        expect(
          evaluateAgeEligibility(
            AgeSignalsSnapshot(
              status: AgeSignalsStatus.shared,
              ageLower: range.$1,
              ageUpper: range.$2,
            ),
          ).outcome,
          AgeEligibilityOutcome.underMinimumAge,
        );
      }
    });

    test('allows null bounds documented for an adult without details', () {
      expect(
        evaluateAgeEligibility(
          const AgeSignalsSnapshot(status: AgeSignalsStatus.shared),
        ).outcome,
        AgeEligibilityOutcome.allowed,
      );
    });

    test('honors an optional not-shared choice without inferring age', () {
      expect(
        evaluateAgeEligibility(
          const AgeSignalsSnapshot(status: AgeSignalsStatus.notShared),
        ).outcome,
        AgeEligibilityOutcome.allowed,
      );
    });

    test('blocks unresolved mandatory verification', () {
      expect(
        evaluateAgeEligibility(
          const AgeSignalsSnapshot(
            status: AgeSignalsStatus.verificationRequired,
          ),
        ).outcome,
        AgeEligibilityOutcome.verificationRequired,
      );
    });

    test('blocks pending and declined significant changes', () {
      expect(
        evaluateAgeEligibility(
          const AgeSignalsSnapshot(
            status: AgeSignalsStatus.shared,
            ageLower: 16,
            ageUpper: 17,
            significantChangeStatus: SignificantChangeStatus.pending,
          ),
        ).outcome,
        AgeEligibilityOutcome.parentApprovalPending,
      );
      expect(
        evaluateAgeEligibility(
          const AgeSignalsSnapshot(
            status: AgeSignalsStatus.shared,
            ageLower: 16,
            ageUpper: 17,
            significantChangeStatus: SignificantChangeStatus.declined,
          ),
        ).outcome,
        AgeEligibilityOutcome.parentApprovalDeclined,
      );
    });

    test('fails closed for API errors and unexpected straddling ranges', () {
      expect(
        evaluateAgeEligibility(
          const AgeSignalsSnapshot(status: AgeSignalsStatus.error),
        ).outcome,
        AgeEligibilityOutcome.temporarilyUnavailable,
      );
      expect(
        evaluateAgeEligibility(
          const AgeSignalsSnapshot(
            status: AgeSignalsStatus.shared,
            ageLower: 15,
          ),
        ).outcome,
        AgeEligibilityOutcome.temporarilyUnavailable,
      );
    });
  });
}
