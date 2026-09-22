/// This device's own record of lessons from before the existing-user
/// migration's cutoff, sent once as an offline claim. The server maps
/// lessons to units itself; [unitIds] only decides whether to offer a claim.
class LegacyLessonRecord {
  final Set<int> completedLessonIds;
  final Set<int> attemptedLessonIds;
  final Set<int> unitIds;

  const LegacyLessonRecord({
    required this.completedLessonIds,
    required this.attemptedLessonIds,
    required this.unitIds,
  });

  bool get isEmpty => completedLessonIds.isEmpty && attemptedLessonIds.isEmpty;

  /// Whether the record reaches a unit the account does not already keep.
  bool addsTo(Iterable<int> keptUnitIds) =>
      unitIds.difference(keptUnitIds.toSet()).isNotEmpty;
}
