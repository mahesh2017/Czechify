import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const int kMinimumSupportedAge = 16;

enum AgeSignalsStatus {
  unsupported,
  shared,
  notShared,
  verificationRequired,
  error,
}

enum SignificantChangeStatus { approved, pending, declined }

@immutable
class AgeSignalsSnapshot {
  const AgeSignalsSnapshot({
    required this.status,
    this.ageLower,
    this.ageUpper,
    this.significantChangeStatus,
  });

  final AgeSignalsStatus status;
  final int? ageLower;
  final int? ageUpper;
  final SignificantChangeStatus? significantChangeStatus;
}

enum AgeEligibilityOutcome {
  allowed,
  underMinimumAge,
  verificationRequired,
  parentApprovalPending,
  parentApprovalDeclined,
  temporarilyUnavailable,
}

@immutable
class AgeEligibilityDecision {
  const AgeEligibilityDecision(this.outcome);

  final AgeEligibilityOutcome outcome;

  bool get isAllowed => outcome == AgeEligibilityOutcome.allowed;
}

/// Converts the store response into Czechify's 16+ access policy.
///
/// `NOT_SHARED` is an explicit user/parent choice in regions where sharing is
/// optional, so it must not be treated as proof that the learner is underage.
/// `VERIFICATION_REQUIRED`, by contrast, is only returned where sharing is
/// mandatory and Play still needs the user to resolve their status.
AgeEligibilityDecision evaluateAgeEligibility(
  AgeSignalsSnapshot snapshot, {
  int minimumAge = kMinimumSupportedAge,
}) {
  switch (snapshot.status) {
    case AgeSignalsStatus.unsupported:
    case AgeSignalsStatus.notShared:
      return const AgeEligibilityDecision(AgeEligibilityOutcome.allowed);
    case AgeSignalsStatus.verificationRequired:
      return const AgeEligibilityDecision(
        AgeEligibilityOutcome.verificationRequired,
      );
    case AgeSignalsStatus.error:
      return const AgeEligibilityDecision(
        AgeEligibilityOutcome.temporarilyUnavailable,
      );
    case AgeSignalsStatus.shared:
      break;
  }

  switch (snapshot.significantChangeStatus) {
    case SignificantChangeStatus.pending:
      return const AgeEligibilityDecision(
        AgeEligibilityOutcome.parentApprovalPending,
      );
    case SignificantChangeStatus.declined:
      return const AgeEligibilityDecision(
        AgeEligibilityOutcome.parentApprovalDeclined,
      );
    case SignificantChangeStatus.approved:
    case null:
      break;
  }

  final lower = snapshot.ageLower;
  final upper = snapshot.ageUpper;
  if (upper != null && upper < minimumAge) {
    return const AgeEligibilityDecision(AgeEligibilityOutcome.underMinimumAge);
  }
  if (lower == null && upper == null || lower != null && lower >= minimumAge) {
    return const AgeEligibilityDecision(AgeEligibilityOutcome.allowed);
  }

  // Default Play bands never straddle 16. Treat a malformed or unexpected
  // custom range conservatively until a fresh signal can be obtained.
  return const AgeEligibilityDecision(
    AgeEligibilityOutcome.temporarilyUnavailable,
  );
}

abstract interface class AgeSignalsService {
  Future<AgeSignalsSnapshot> requestAgeSignals();

  Future<void> openPlayStore();
}

class GooglePlayAgeSignalsService implements AgeSignalsService {
  GooglePlayAgeSignalsService._();

  static final GooglePlayAgeSignalsService instance =
      GooglePlayAgeSignalsService._();

  static const MethodChannel _channel = MethodChannel(
    'com.eminentsite.czechify/age_signals',
  );

  @override
  Future<AgeSignalsSnapshot> requestAgeSignals() async {
    // Play only returns production signals to Play-owned installs. Let local
    // debug/sideloaded builds remain usable; release-track builds take the
    // real, fail-closed path below.
    if (!Platform.isAndroid || kDebugMode) {
      return const AgeSignalsSnapshot(status: AgeSignalsStatus.unsupported);
    }

    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'requestAgeSignals',
      );
      return _decode(response);
    } on PlatformException {
      return const AgeSignalsSnapshot(status: AgeSignalsStatus.error);
    } on MissingPluginException {
      return const AgeSignalsSnapshot(status: AgeSignalsStatus.error);
    }
  }

  @override
  Future<void> openPlayStore() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openPlayStore');
  }

  AgeSignalsSnapshot _decode(Map<String, Object?>? response) {
    final status = switch (response?['status']) {
      'shared' => AgeSignalsStatus.shared,
      'not_shared' => AgeSignalsStatus.notShared,
      'verification_required' => AgeSignalsStatus.verificationRequired,
      _ => AgeSignalsStatus.error,
    };
    final significantChangeStatus =
        switch (response?['significantChangeStatus']) {
          'approved' => SignificantChangeStatus.approved,
          'pending' => SignificantChangeStatus.pending,
          'declined' => SignificantChangeStatus.declined,
          _ => null,
        };

    return AgeSignalsSnapshot(
      status: status,
      ageLower: response?['ageLower'] as int?,
      ageUpper: response?['ageUpper'] as int?,
      significantChangeStatus: significantChangeStatus,
    );
  }
}
