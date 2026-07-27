import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cheat sheets are per-unit, so they follow the grammar reference's rule:
/// only units the learner has reached, most recent first. Previously all 31
/// sheets were listed in ascending order, so the sheet for the unit being
/// studied sat at the bottom and sheets for unreached units were readable.
///
/// This mirrors the selection the screen performs, and runs it against the
/// real asset so a change to the JSON shape fails here too.
List<Map<String, dynamic>> visibleSheets({
  required List<dynamic> all,
  required Set<int>? unlockedUnitIds,
}) {
  return [
    for (final sheet in all)
      if (unlockedUnitIds == null ||
          unlockedUnitIds.contains((sheet as Map<String, dynamic>)['unit_id']))
        sheet as Map<String, dynamic>,
  ]..sort((a, b) => (b['unit_id'] as int).compareTo(a['unit_id'] as int));
}

void main() {
  final raw = File('assets/curriculum/cheat_sheets.json').readAsStringSync();
  final all =
      (jsonDecode(raw) as Map<String, dynamic>)['cheat_sheets']
          as List<dynamic>;

  test('the asset still has a sheet per unit', () {
    expect(all.length, 31);
  });

  test('only reached units are listed', () {
    final visible = visibleSheets(all: all, unlockedUnitIds: {1, 2, 3});
    expect(visible.map((s) => s['unit_id']), [3, 2, 1]);
  });

  test('most recent unit comes first', () {
    final visible = visibleSheets(all: all, unlockedUnitIds: {1, 5, 9});
    expect(
      visible.first['unit_id'],
      9,
      reason: 'the sheet being studied should need no scrolling',
    );
    expect(visible.last['unit_id'], 1);
  });

  test('a fresh install sees only Unit 1', () {
    final visible = visibleSheets(all: all, unlockedUnitIds: {1});
    expect(visible.length, 1);
    expect(visible.single['unit_id'], 1);
  });

  test('unknown access falls back to showing everything', () {
    // Hiding the sheet for the unit they are on is worse than showing extra.
    final visible = visibleSheets(all: all, unlockedUnitIds: null);
    expect(visible.length, all.length);
    expect(visible.first['unit_id'], 31);
  });
}
