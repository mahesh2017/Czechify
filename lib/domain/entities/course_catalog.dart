import 'enums.dart';

/// Published membership and reward order, never inferred from numeric IDs.
class CourseCatalog {
  final List<int> a1UnitIds;
  final List<int> a2UnitIds;
  final List<int> freeUnitIds;
  final List<int> rewardUnitIds;

  CourseCatalog({
    required Iterable<int> a1UnitIds,
    required Iterable<int> a2UnitIds,
    required Iterable<int> freeUnitIds,
    required Iterable<int> rewardUnitIds,
  }) : a1UnitIds = List.unmodifiable(a1UnitIds),
       a2UnitIds = List.unmodifiable(a2UnitIds),
       freeUnitIds = List.unmodifiable(freeUnitIds),
       rewardUnitIds = List.unmodifiable(rewardUnitIds) {
    final a1 = this.a1UnitIds.toSet();
    final a2 = this.a2UnitIds.toSet();
    final free = this.freeUnitIds.toSet();
    final rewards = this.rewardUnitIds.toSet();
    if (a1.isEmpty ||
        a1.length != this.a1UnitIds.length ||
        a2.length != this.a2UnitIds.length ||
        free.length != this.freeUnitIds.length ||
        rewards.length != this.rewardUnitIds.length ||
        a1.intersection(a2).isNotEmpty ||
        !a1.containsAll(free) ||
        !a1.containsAll(rewards) ||
        free.intersection(rewards).isNotEmpty ||
        free.union(rewards).length != a1.length ||
        [...a1, ...a2].any((id) => id <= 0)) {
      throw ArgumentError('Invalid course campaign membership.');
    }
    final expectedRewards = this.a1UnitIds.where((id) => !free.contains(id));
    if (expectedRewards.join(',') != this.rewardUnitIds.join(',')) {
      throw ArgumentError('Rewards must follow A1 curriculum order.');
    }
  }

  static final a1ReferralV1 = CourseCatalog(
    a1UnitIds: const [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      28,
      30,
    ],
    a2UnitIds: const [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 29, 31],
    freeUnitIds: const [1, 2],
    rewardUnitIds: const [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 28, 30],
  );

  List<int> unitsFor(Phase phase) => phase == Phase.a1 ? a1UnitIds : a2UnitIds;
  Set<int> get allUnitIds => {...a1UnitIds, ...a2UnitIds};
}
