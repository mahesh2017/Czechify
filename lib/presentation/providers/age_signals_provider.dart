import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/age_signals/play_age_signals_service.dart';

final ageSignalsServiceProvider = Provider<AgeSignalsService>(
  (ref) => GooglePlayAgeSignalsService.instance,
);

final ageEligibilityProvider = FutureProvider<AgeEligibilityDecision>((
  ref,
) async {
  final service = ref.watch(ageSignalsServiceProvider);
  final snapshot = await service.requestAgeSignals();
  return evaluateAgeEligibility(snapshot);
});
