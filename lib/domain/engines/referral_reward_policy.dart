import '../entities/course_catalog.dart';

enum ReferralRewardOutcome { granted, capReached }

class ReferralRewardDecision {
  final int ordinal;
  final int? unitId;

  const ReferralRewardDecision({required this.ordinal, required this.unitId});

  ReferralRewardOutcome get outcome =>
      unitId == null
          ? ReferralRewardOutcome.capReached
          : ReferralRewardOutcome.granted;
}

/// Deterministic reward preview. This never persists or authorizes a reward:
/// the backend must re-evaluate inside the beneficiary's locked transaction.
class ReferralRewardPolicy {
  const ReferralRewardPolicy();

  List<int> awardableOrdinals({
    required Set<int> completeManifestUnitIds,
    required bool bothAccountsLinked,
    required bool riskCleared,
  }) {
    if (!bothAccountsLinked ||
        !riskCleared ||
        !completeManifestUnitIds.contains(1)) {
      return const [];
    }
    return [1, if (completeManifestUnitIds.contains(2)) 2];
  }

  List<ReferralRewardDecision> allocate({
    required CourseCatalog catalog,
    required Set<int> permanentlyOwnedUnitIds,
    required Iterable<int> newQualifiedOrdinals,
  }) {
    final ordinals = newQualifiedOrdinals.toList()..sort();
    if (ordinals.toSet().length != ordinals.length ||
        ordinals.any((ordinal) => ordinal != 1 && ordinal != 2)) {
      throw ArgumentError('Each referee has only milestones 1 and 2.');
    }
    final remaining =
        catalog.rewardUnitIds
            .where((id) => !permanentlyOwnedUnitIds.contains(id))
            .iterator;
    return List.unmodifiable([
      for (final ordinal in ordinals)
        ReferralRewardDecision(
          ordinal: ordinal,
          unitId: remaining.moveNext() ? remaining.current : null,
        ),
    ]);
  }
}
