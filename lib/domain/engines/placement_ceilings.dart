import 'dart:convert';

import '../entities/course_catalog.dart';
import '../entities/enums.dart';
import '../entities/unit.dart';
import 'curriculum_access_policy.dart';

/// Per-phase placement. Null storage means an old global ceiling, whereas an
/// explicit empty map means no placement. Neither represents paid access.
class PlacementCeilings {
  final Map<Phase, int> throughUnitIds;
  PlacementCeilings(Map<Phase, int> values)
    : throughUnitIds = Map.unmodifiable(values);

  /// Revision 25 fallback for a restore before curriculum installation.
  /// Keep aligned with the pinned catalog; normally use the installed units.
  static List<Unit> get bundledUnits => [
    for (final phase in Phase.values)
      for (final id in CourseCatalog.a1ReferralV1.unitsFor(phase))
        Unit(id: id, title: '', description: '', phase: phase, orderIndex: id),
  ];

  factory PlacementCeilings.read({
    required String? json,
    required int? legacyUnit,
    required List<Unit> units,
  }) {
    final values = <Phase, int>{};
    final byId = {for (final unit in units) unit.id: unit};
    if (json == null) {
      final ceiling = byId[legacyUnit]?.orderIndex;
      if (ceiling != null) {
        for (final unit in units.where((u) => u.orderIndex <= ceiling)) {
          final old = byId[values[unit.phase]];
          if (old == null || unit.orderIndex > old.orderIndex) {
            values[unit.phase] = unit.id;
          }
        }
      }
    } else {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Placement ceilings must be an object.');
      }
      for (final entry in decoded.entries) {
        final phase = Phase.values
            .where((p) => p.name == entry.key)
            .firstOrNull;
        final id = entry.value;
        if (phase == null || id is! int || byId[id]?.phase != phase) {
          throw const FormatException('Invalid phase placement.');
        }
        values[phase] = id;
      }
    }
    return PlacementCeilings(values);
  }

  PlacementCeilings advance(int unitId, List<Unit> units) {
    final target = units.where((u) => u.id == unitId).firstOrNull;
    if (target == null) throw ArgumentError.value(unitId, 'unitId');
    return merge(PlacementCeilings({target.phase: unitId}), units);
  }

  PlacementCeilings merge(PlacementCeilings other, List<Unit> units) {
    final byId = {for (final unit in units) unit.id: unit};
    final merged = {...throughUnitIds};
    for (final entry in other.throughUnitIds.entries) {
      final target = byId[entry.value];
      final current = byId[merged[entry.key]];
      if (target != null &&
          target.phase == entry.key &&
          (current == null || target.orderIndex > current.orderIndex)) {
        merged[entry.key] = target.id;
      }
    }
    return PlacementCeilings(merged);
  }

  String encode() => jsonEncode({
    for (final phase in Phase.values)
      if (throughUnitIds[phase] case final int id) phase.name: id,
  });

  List<CurriculumPlacement> get placements => [
    for (final entry in throughUnitIds.entries)
      CurriculumPlacement(phase: entry.key, throughUnitId: entry.value),
  ];
}
