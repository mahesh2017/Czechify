/// Milestone states as the server names them. A friend's review or rejection
/// reaches the referrer as [verificationPending]; only the invited learner
/// sees their own [needsReview] or [rejected].
enum ReferralMilestoneStatus {
  waitingForLearning,
  waitingForAccountLink,
  verificationPending,
  rewardGranted,
  capReached,
  needsReview,
  rejected;

  static ReferralMilestoneStatus parse(Object? value) => switch (value) {
    'waiting_for_account_link' => waitingForAccountLink,
    'verification_pending' => verificationPending,
    'reward_granted' => rewardGranted,
    'cap_reached' => capReached,
    'needs_review' => needsReview,
    'rejected' => rejected,
    _ => waitingForLearning,
  };
}

List<ReferralMilestoneStatus> _milestones(Object? raw) {
  final byOrdinal = <int, ReferralMilestoneStatus>{};
  if (raw is List) {
    for (final m in raw) {
      if (m is Map && m['ordinal'] is int) {
        byOrdinal[m['ordinal'] as int] = ReferralMilestoneStatus.parse(
          m['status'],
        );
      }
    }
  }
  return [
    byOrdinal[1] ?? ReferralMilestoneStatus.waitingForLearning,
    byOrdinal[2] ?? ReferralMilestoneStatus.waitingForLearning,
  ];
}

class ReferredFriend {
  /// A number, never a name or account: learners see only progress.
  final int number;
  final List<ReferralMilestoneStatus> milestones;
  const ReferredFriend(this.number, this.milestones);
}

class OwnReferralClaim {
  final int lessonsCompleted;
  final int lessonsRequired;
  final List<ReferralMilestoneStatus> milestones;
  const OwnReferralClaim({
    required this.lessonsCompleted,
    required this.lessonsRequired,
    required this.milestones,
  });
}

class ReferralStatus {
  final String? inviteCode;
  final int unitsEarned;
  final int unitsAvailable;
  final int? nextRewardUnit;
  final OwnReferralClaim? ownClaim;
  final List<ReferredFriend> friends;
  final int? nextCursor;

  const ReferralStatus({
    this.inviteCode,
    this.unitsEarned = 0,
    this.unitsAvailable = 15,
    this.nextRewardUnit,
    this.ownClaim,
    this.friends = const [],
    this.nextCursor,
  });

  factory ReferralStatus.fromJson(Map<String, Object?> json) {
    final own = json['own_claim'];
    final friends = json['friends'];
    int count(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
    return ReferralStatus(
      inviteCode: json['referral_code'] as String?,
      unitsEarned: count(json['units_earned']),
      unitsAvailable: json['units_available'] is int
          ? json['units_available'] as int
          : 15,
      nextRewardUnit: json['next_reward_unit'] as int?,
      ownClaim: own is Map
          ? OwnReferralClaim(
              lessonsCompleted: count(own['lessons_completed']),
              lessonsRequired: count(own['lessons_required']),
              milestones: _milestones(own['milestones']),
            )
          : null,
      friends: [
        if (friends is List)
          for (final f in friends)
            if (f is Map && f['friend'] is int)
              ReferredFriend(f['friend'] as int, _milestones(f['milestones'])),
      ],
      nextCursor: json['next_cursor'] as int?,
    );
  }
}
