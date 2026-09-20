enum SubscriptionState {
  pending,
  active,
  inGracePeriod,
  canceled,
  onHold,
  paused,
  expired,
  revoked,
  unknown;

  static SubscriptionState fromStorage(String value) => switch (value) {
    'pending' => pending,
    'active' => active,
    'in_grace_period' => inGracePeriod,
    'canceled' => canceled,
    'on_hold' => onHold,
    'paused' => paused,
    'expired' => expired,
    'revoked' => revoked,
    _ => unknown,
  };

  bool get permitsAccess => switch (this) {
    active || inGracePeriod || canceled => true,
    _ => false,
  };
}

/// One authoritative purchase source. A scheduled future pause is still
/// active; [SubscriptionState.paused] means the pause has taken effect.
class VerifiedSubscription {
  final SubscriptionState state;
  final DateTime validUntil;
  final DateTime verifiedAt;

  const VerifiedSubscription({
    required this.state,
    required this.validUntil,
    required this.verifiedAt,
  });

  bool isActiveAt(DateTime now) =>
      state.permitsAccess && now.isBefore(validUntil);

  DateTime get offlineValidUntil {
    final leaseEnd = verifiedAt.add(const Duration(days: 7));
    return validUntil.isBefore(leaseEnd) ? validUntil : leaseEnd;
  }
}

/// Safe feature projection from a verified, account-bound server snapshot.
/// Validity and offline validity are separately aggregated across purchases.
class FeatureEntitlement {
  final bool active;
  final DateTime? validUntil;
  final DateTime? offlineValidUntil;

  const FeatureEntitlement({
    required this.active,
    this.validUntil,
    this.offlineValidUntil,
  });

  static const none = FeatureEntitlement(active: false);

  factory FeatureEntitlement.fromVerifiedPurchases(
    Iterable<VerifiedSubscription> purchases, {
    required DateTime now,
  }) {
    DateTime? validUntil;
    DateTime? offlineUntil;
    for (final purchase in purchases.where((p) => p.isActiveAt(now))) {
      if (validUntil == null || purchase.validUntil.isAfter(validUntil)) {
        validUntil = purchase.validUntil;
      }
      final bound = purchase.offlineValidUntil;
      if (offlineUntil == null || bound.isAfter(offlineUntil)) {
        offlineUntil = bound;
      }
    }
    return FeatureEntitlement(
      active: validUntil != null,
      validUntil: validUntil,
      offlineValidUntil: offlineUntil,
    );
  }

  bool isActiveAt(DateTime now, {required bool offline}) =>
      active &&
      validUntil != null &&
      now.isBefore(validUntil!) &&
      (!offline ||
          (offlineValidUntil != null && now.isBefore(offlineValidUntil!)));
}

enum PermanentGrantSource { referral, legacy, staffPermanent }

class PermanentUnitGrant {
  final String id;
  final int unitId;
  final PermanentGrantSource source;
  final bool revoked;

  const PermanentUnitGrant({
    required this.id,
    required this.unitId,
    required this.source,
    this.revoked = false,
  });
}

/// Domain representation only. Never construct this from an unverified cache
/// or a client-owned progress row. The transport layer must verify the JWS,
/// schema, account and revision before supplying this to access policies.
class MonetizationSnapshot {
  final String userId;
  final int revision;
  final DateTime verifiedAt;
  final FeatureEntitlement core;
  final FeatureEntitlement aiChat;
  final List<PermanentUnitGrant> permanentGrants;
  final DateTime? migrationGraceUntil;

  MonetizationSnapshot({
    required this.userId,
    required this.revision,
    required this.verifiedAt,
    this.core = FeatureEntitlement.none,
    this.aiChat = FeatureEntitlement.none,
    Iterable<PermanentUnitGrant> permanentGrants = const [],
    this.migrationGraceUntil,
  }) : permanentGrants = List.unmodifiable(permanentGrants);

  /// Reject cross-account and replayed snapshots. Refreshes of the same
  /// revision may advance verification time, never roll it backwards.
  bool canReplace(MonetizationSnapshot? previous, {required String accountId}) {
    if (accountId.isEmpty || userId != accountId || revision < 0) return false;
    if (previous == null || previous.userId != accountId) return true;
    return revision > previous.revision ||
        (revision == previous.revision &&
            !verifiedAt.isBefore(previous.verifiedAt));
  }
}
