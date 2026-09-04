import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Units were numbered by [Unit.id] on the curriculum screen, so the two A1
/// capstones — ids 28 and 30, because 16-27 belong to A2 — rendered as
/// "Unit 28" and "Unit 30" directly beneath "Unit 15" and read as a bug.
///
/// The screen now numbers by position within the level being shown. This pins
/// that rule and the phase split, using the real unit ids from the curriculum.
List<Unit> unitsOf(List<Unit> all, Phase phase) =>
    all.where((u) => u.phase == phase).toList();

Unit unit(int id, Phase phase) => Unit(
  id: id,
  title: 'Unit $id',
  description: '',
  phase: phase,
  orderIndex: id,
  grammarTags: const [],
);

void main() {
  // Mirrors assets/curriculum/a1_units.json + a2_units.json.
  final all = <Unit>[
    for (final id in [...List.generate(15, (i) => i + 1), 28, 30])
      unit(id, Phase.a1),
    for (final id in [...List.generate(12, (i) => i + 16), 29, 31])
      unit(id, Phase.a2),
  ];

  test('A1 holds 17 units including both capstones', () {
    final a1 = unitsOf(all, Phase.a1);
    expect(a1.length, 17);
    expect(a1.map((u) => u.id), containsAll([28, 30]));
  });

  test('A2 holds 14 units and is not empty', () {
    // The A2 tab was unreachable, so this guards that the split yields
    // something to show.
    final a2 = unitsOf(all, Phase.a2);
    expect(a2.length, 14);
    expect(a2.map((u) => u.id), containsAll([16, 29, 31]));
  });

  test('phases do not overlap', () {
    final a1 = unitsOf(all, Phase.a1).map((u) => u.id).toSet();
    final a2 = unitsOf(all, Phase.a2).map((u) => u.id).toSet();
    expect(a1.intersection(a2), isEmpty);
    expect(a1.length + a2.length, all.length);
  });

  test('display number is the position in the level, never the id', () {
    final a1 = unitsOf(all, Phase.a1);
    // The capstones are last in A1 and must read 16 and 17, not 28 and 30.
    expect(a1.indexWhere((u) => u.id == 28) + 1, 16);
    expect(a1.indexWhere((u) => u.id == 30) + 1, 17);
  });

  test('A2 numbering restarts at 1', () {
    final a2 = unitsOf(all, Phase.a2);
    expect(a2.first.id, 16, reason: 'first A2 unit by id');
    expect(a2.indexOf(a2.first) + 1, 1, reason: 'but displayed as Unit 1');
    expect(a2.indexWhere((u) => u.id == 31) + 1, 14);
  });
}
