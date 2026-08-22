import '../entities/enums.dart';
import '../entities/unit.dart';

/// Where a learner should be placed when they change level after onboarding.
///
/// Two pieces of state decide what a learner can open: the level stored in
/// settings, which drives chat difficulty and which units download for offline
/// use, and the placement profile's `provisionalUnit`, which is what actually
/// unlocks curriculum. Onboarding writes both and nothing wrote either again,
/// so a learner who picked A1 to try the app had no way to move to A2.
class LevelSwitch {
  const LevelSwitch();

  /// The unit a learner moving to [level] should be unlocked through.
  ///
  /// Returns null when the switch would move them backwards, which is the
  /// caller's signal to leave placement alone.
  ///
  /// The rule is monotonic on purpose: the ceiling never comes down. Someone
  /// who has reached A2 and looks at the level control out of curiosity — or
  /// sets it back to A1 to revise — must not lose access to units they have
  /// already opened. Levelling *down* changes what the tutor pitches at them
  /// and what downloads for offline use, and nothing else.
  ///
  /// Comparison is by [Unit.orderIndex], never by id. Unit ids are not in
  /// curriculum order: A1 holds 1-15, 28 and 30 while A2 holds 16-27, 29 and
  /// 31, so `max(currentId, targetId)` would read unit 30 as being past the
  /// start of A2 and quietly unlock the wrong span.
  int? provisionalUnitFor({
    required List<Unit> units,
    required CEFRLevel level,
    required int? currentProvisionalUnit,
  }) {
    final target = firstUnitOf(units: units, level: level);
    if (target == null) return null;

    final current = units
        .cast<Unit?>()
        .firstWhere((u) => u?.id == currentProvisionalUnit, orElse: () => null);
    if (current != null && current.orderIndex >= target.orderIndex) return null;

    return target.id;
  }

  /// The earliest unit of [level] in curriculum order.
  ///
  /// Derived rather than hardcoded — onboarding used a literal 16 for "first
  /// A2 unit", which is a fact about today's curriculum file rather than about
  /// the curriculum, and silently wrong the moment a unit is inserted.
  Unit? firstUnitOf({required List<Unit> units, required CEFRLevel level}) {
    final phase = level == CEFRLevel.a2 ? Phase.a2 : Phase.a1;
    final matching = units.where((u) => u.phase == phase).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return matching.isEmpty ? null : matching.first;
  }

  /// Whether every unit of [level] has been completed.
  ///
  /// Used to decide when to offer the next level rather than leaving a learner
  /// to find the setting on their own.
  bool hasFinished({
    required List<Unit> units,
    required CEFRLevel level,
    required Set<int> completedUnitIds,
  }) {
    final phase = level == CEFRLevel.a2 ? Phase.a2 : Phase.a1;
    final matching = units.where((u) => u.phase == phase).toList();
    if (matching.isEmpty) return false;
    return matching.every((u) => completedUnitIds.contains(u.id));
  }
}
