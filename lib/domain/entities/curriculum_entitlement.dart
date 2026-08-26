class CurriculumEntitlement {
  final bool unlockAll;
  final DateTime? expiresAt;
  final String? reason;

  const CurriculumEntitlement({
    required this.unlockAll,
    this.expiresAt,
    this.reason,
  });

  static const none = CurriculumEntitlement(unlockAll: false);

  bool isActiveAt(DateTime now) =>
      unlockAll && (expiresAt == null || expiresAt!.isAfter(now.toUtc()));

  factory CurriculumEntitlement.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['expires_at'];
    return CurriculumEntitlement(
      unlockAll: json['unlock_all'] == true,
      expiresAt:
          expiresAt is String && expiresAt.isNotEmpty
              ? DateTime.tryParse(expiresAt)?.toUtc()
              : null,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'unlock_all': unlockAll,
    'expires_at': expiresAt?.toUtc().toIso8601String(),
    'reason': reason,
  };
}
