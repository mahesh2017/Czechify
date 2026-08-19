import 'package:ceskina_pro/domain/engines/level_switch.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/unit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Curriculum shaped like the real one, where ids are deliberately not in
/// curriculum order: A1 owns 1-2, 28 and 30; A2 owns 16-17, 29 and 31.
/// Every ordering rule here has to survive that.
List<Unit> _units() => const [
  Unit(id: 1, title: 'a', description: '', phase: Phase.a1, orderIndex: 1),
  Unit(id: 2, title: 'b', description: '', phase: Phase.a1, orderIndex: 2),
  Unit(id: 28, title: 'c', description: '', phase: Phase.a1, orderIndex: 3),
  Unit(id: 30, title: 'd', description: '', phase: Phase.a1, orderIndex: 4),
  Unit(id: 16, title: 'e', description: '', phase: Phase.a2, orderIndex: 5),
  Unit(id: 17, title: 'f', description: '', phase: Phase.a2, orderIndex: 6),
  Unit(id: 29, title: 'g', description: '', phase: Phase.a2, orderIndex: 7),
  Unit(id: 31, title: 'h', description: '', phase: Phase.a2, orderIndex: 8),
];

void main() {
  const engine = LevelSwitch();

  group('moving up a level', () {
    test('an A1 learner switching to A2 unlocks through the first A2 unit', () {
      expect(
        engine.provisionalUnitFor(
          units: _units(),
          level: CEFRLevel.a2,
          currentProvisionalUnit: 1,
        ),
        16,
      );
    });

    test('a learner with no placement at all still gets one', () {
      expect(
        engine.provisionalUnitFor(
          units: _units(),
          level: CEFRLevel.a2,
          currentProvisionalUnit: null,
        ),
        16,
      );
    });

    test('the A1 unit with the highest id does not count as past A2', () {
      // The whole reason this compares orderIndex. Unit 30 is A1, but a
      // max-by-id rule would read it as being beyond unit 16 and refuse to
      // unlock A2 — leaving the learner switched on paper and stuck in fact.
      expect(
        engine.provisionalUnitFor(
          units: _units(),
          level: CEFRLevel.a2,
          currentProvisionalUnit: 30,
        ),
        16,
      );
    });
  });

  group('moving down a level never takes access away', () {
    test('an A2 learner switching to A1 keeps their unlocked span', () {
      expect(
        engine.provisionalUnitFor(
          units: _units(),
          level: CEFRLevel.a1,
          currentProvisionalUnit: 16,
        ),
        isNull,
      );
    });

    test('switching to the level already held is a no-op', () {
      expect(
        engine.provisionalUnitFor(
          units: _units(),
          level: CEFRLevel.a2,
          currentProvisionalUnit: 16,
        ),
        isNull,
      );
    });

    test('a learner deep in A2 is not pulled back to its first unit', () {
      expect(
        engine.provisionalUnitFor(
          units: _units(),
          level: CEFRLevel.a2,
          currentProvisionalUnit: 31,
        ),
        isNull,
      );
    });
  });

  group('the first unit of a level is derived, not assumed', () {
    test('A1 starts at its lowest order index, not its lowest id', () {
      expect(engine.firstUnitOf(units: _units(), level: CEFRLevel.a1)?.id, 1);
    });

    test('A2 starts at its lowest order index', () {
      expect(engine.firstUnitOf(units: _units(), level: CEFRLevel.a2)?.id, 16);
    });

    test('pre-A1 is treated as A1 rather than yielding nothing', () {
      expect(engine.firstUnitOf(units: _units(), level: CEFRLevel.preA1)?.id, 1);
    });

    test('an empty curriculum yields no unit rather than throwing', () {
      expect(engine.firstUnitOf(units: const [], level: CEFRLevel.a2), isNull);
      expect(
        engine.provisionalUnitFor(
          units: const [],
          level: CEFRLevel.a2,
          currentProvisionalUnit: null,
        ),
        isNull,
      );
    });
  });

  group('knowing when a level is finished', () {
    test('every A1 unit complete counts as finished', () {
      expect(
        engine.hasFinished(
          units: _units(),
          level: CEFRLevel.a1,
          completedUnitIds: {1, 2, 28, 30},
        ),
        isTrue,
      );
    });

    test('the late-numbered A1 units are not forgotten', () {
      // Units 28 and 30 are A1 despite their ids sitting above A2's first.
      // Anything that treated "A1" as "id below 16" would call this finished.
      expect(
        engine.hasFinished(
          units: _units(),
          level: CEFRLevel.a1,
          completedUnitIds: {1, 2},
        ),
        isFalse,
      );
    });

    test('completing A2 units does not finish A1', () {
      expect(
        engine.hasFinished(
          units: _units(),
          level: CEFRLevel.a1,
          completedUnitIds: {1, 2, 28, 16, 17, 29, 31},
        ),
        isFalse,
      );
    });

    test('an empty curriculum is never finished', () {
      expect(
        engine.hasFinished(
          units: const [],
          level: CEFRLevel.a1,
          completedUnitIds: const {},
        ),
        isFalse,
      );
    });
  });
}
