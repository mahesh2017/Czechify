import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The grammar reference listed every unit in the course in ascending order,
/// so a learner on Unit 5 had to scroll past Units 1-4 to reach what they were
/// working on, and could read grammar for units they had not unlocked.
///
/// This pins the selection rule the screen applies. Kept as pure logic so it
/// runs without a widget harness or a database.
List<Unit> visibleUnits({
  required List<Unit> allUnits,
  required Set<int>? unlockedUnitIds,
  required bool hasHighlight,
}) {
  return [
    for (final unit in allUnits)
      if (hasHighlight ||
          unlockedUnitIds == null ||
          unlockedUnitIds.contains(unit.id))
        unit,
  ]..sort((a, b) => b.orderIndex.compareTo(a.orderIndex));
}

Unit unit(int id) => Unit(
  id: id,
  title: 'Unit $id',
  description: '',
  phase: Phase.a1,
  orderIndex: id,
  grammarTags: const [],
);

void main() {
  final all = [for (var i = 1; i <= 6; i++) unit(i)];

  test('only unlocked units are listed', () {
    final visible = visibleUnits(
      allUnits: all,
      unlockedUnitIds: {1, 2, 3},
      hasHighlight: false,
    );
    expect(visible.map((u) => u.id), [3, 2, 1]);
  });

  test('most recent unit comes first', () {
    final visible = visibleUnits(
      allUnits: all,
      unlockedUnitIds: {1, 2, 3, 4, 5},
      hasHighlight: false,
    );
    expect(
      visible.first.id,
      5,
      reason: 'the unit being studied should need no scrolling',
    );
    expect(visible.last.id, 1);
  });

  test('a fresh install still sees Unit 1', () {
    final visible = visibleUnits(
      allUnits: all,
      unlockedUnitIds: {1},
      hasHighlight: false,
    );
    expect(visible.map((u) => u.id), [1]);
  });

  test('a direct rule link is never hidden by gating', () {
    // Opening a specific rule must work even when its unit is locked,
    // otherwise a link from elsewhere in the app dead-ends.
    final visible = visibleUnits(
      allUnits: all,
      unlockedUnitIds: {1},
      hasHighlight: true,
    );
    expect(visible.length, all.length);
  });

  test('unknown access falls back to showing everything', () {
    // Hiding the grammar for the unit they are on is worse than showing extra.
    final visible = visibleUnits(
      allUnits: all,
      unlockedUnitIds: null,
      hasHighlight: false,
    );
    expect(visible.length, all.length);
    expect(visible.first.id, 6);
  });
}
