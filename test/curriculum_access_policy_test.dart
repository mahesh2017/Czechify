import 'package:czechify/domain/engines/curriculum_access_policy.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = CurriculumAccessPolicy();
  const units = [
    Unit(id: 1, title: 'One', description: '', phase: Phase.a1, orderIndex: 1),
    Unit(id: 2, title: 'Two', description: '', phase: Phase.a1, orderIndex: 2),
  ];
  const lessons = {
    1: [
      Lesson(id: 101, unitId: 1, orderInUnit: 0, title: '1A', description: ''),
      Lesson(id: 102, unitId: 1, orderInUnit: 1, title: '1B', description: ''),
    ],
    2: [
      Lesson(id: 201, unitId: 2, orderInUnit: 0, title: '2A', description: ''),
    ],
  };

  test('unlocks one lesson at a time from committed completion', () {
    final initial = policy.evaluate(
      orderedUnits: units,
      lessonsByUnit: lessons,
      completedLessonIds: const {},
    );
    expect(initial.unlockedUnitIds, {1});
    expect(initial.unlockedLessonIds, {101});

    final afterFirst = policy.evaluate(
      orderedUnits: units,
      lessonsByUnit: lessons,
      completedLessonIds: const {101},
    );
    expect(afterFirst.unlockedUnitIds, {1});
    expect(afterFirst.unlockedLessonIds, {101, 102});

    final afterUnit = policy.evaluate(
      orderedUnits: units,
      lessonsByUnit: lessons,
      completedLessonIds: const {101, 102},
    );
    expect(afterUnit.unlockedUnitIds, {1, 2});
    expect(afterUnit.unlockedLessonIds, {101, 102, 201});
  });

  test('records auditable prerequisite IDs for every lesson', () {
    final access = policy.evaluate(
      orderedUnits: units,
      lessonsByUnit: lessons,
      completedLessonIds: const {},
    );
    expect(access.lessonPrerequisites[101], isEmpty);
    expect(access.lessonPrerequisites[102], {101});
    expect(access.lessonPrerequisites[201], {101, 102});
  });

  test('out-of-sequence completion cannot bypass prerequisites', () {
    final access = policy.evaluate(
      orderedUnits: units,
      lessonsByUnit: lessons,
      completedLessonIds: const {102},
    );
    expect(access.unlockedUnitIds, {1});
    expect(access.unlockedLessonIds, {101});
  });

  test('provisional placement unlocks through the selected unit only', () {
    final access = policy.evaluate(
      orderedUnits: units,
      lessonsByUnit: lessons,
      completedLessonIds: const {},
      provisionalThroughUnitId: 2,
    );
    expect(access.unlockedUnitIds, {1, 2});
    expect(access.unlockedLessonIds, {101, 201});
    expect(access.lessonPrerequisites[201], isEmpty);
    expect(access.unlockedLessonIds, isNot(contains(102)));
  });

  test(
    'server entitlement unlocks every unit and lesson without completion',
    () {
      final access = policy.evaluate(
        orderedUnits: units,
        lessonsByUnit: lessons,
        completedLessonIds: const {},
        unlockAll: true,
      );

      expect(access.unlockedUnitIds, {1, 2});
      expect(access.unlockedLessonIds, {101, 102, 201});
      // Keep the real graph for auditing and for immediate restoration after
      // the entitlement expires or is revoked.
      expect(access.lessonPrerequisites[201], {101, 102});
    },
  );

  const mixedUnits = [
    ...units,
    Unit(
      id: 16,
      title: 'A2 start',
      description: '',
      phase: Phase.a2,
      orderIndex: 16,
    ),
    Unit(
      id: 28,
      title: 'Late A1',
      description: '',
      phase: Phase.a1,
      orderIndex: 28,
    ),
    Unit(
      id: 29,
      title: 'Late A2',
      description: '',
      phase: Phase.a2,
      orderIndex: 29,
    ),
    Unit(
      id: 30,
      title: 'Final A1',
      description: '',
      phase: Phase.a1,
      orderIndex: 30,
    ),
  ];
  const mixedLessons = {
    ...lessons,
    16: [
      Lesson(id: 1601, unitId: 16, orderInUnit: 0, title: '', description: ''),
    ],
    28: [
      Lesson(id: 2801, unitId: 28, orderInUnit: 0, title: '', description: ''),
    ],
    29: [
      Lesson(id: 2901, unitId: 29, orderInUnit: 0, title: '', description: ''),
    ],
    30: [
      Lesson(id: 3001, unitId: 30, orderInUnit: 0, title: '', description: ''),
    ],
  };

  test('late A1 lessons never depend on interleaved A2 units', () {
    final access = policy.evaluate(
      orderedUnits: mixedUnits.reversed.toList(),
      lessonsByUnit: mixedLessons,
      completedLessonIds: {101, 102, 201, 2801},
    );
    expect(access.unlockedLessonIds, contains(3001));
    expect(access.lessonPrerequisites[3001], {101, 102, 201, 2801});
    expect(access.lessonPrerequisites[2901], {1601});
    expect(access.unlockedLessonIds, isNot(contains(2901)));
    expect(access.lessonPrerequisites[1601], isEmpty);
  });

  test('explicit A2 placement does not waive an A1 prerequisite', () {
    final access = policy.evaluate(
      orderedUnits: mixedUnits,
      lessonsByUnit: mixedLessons,
      completedLessonIds: {},
      placements: [
        const CurriculumPlacement(phase: Phase.a2, throughUnitId: 29),
      ],
    );
    expect(access.unlockedLessonIds, contains(2901));
    expect(access.unlockedLessonIds, isNot(contains(201)));
    expect(access.lessonPrerequisites[201], {101, 102});
  });

  test('placement with mismatched or unknown phase membership is ignored', () {
    final access = policy.evaluate(
      orderedUnits: mixedUnits,
      lessonsByUnit: mixedLessons,
      completedLessonIds: {},
      placements: [
        const CurriculumPlacement(phase: Phase.a1, throughUnitId: 29),
        const CurriculumPlacement(phase: Phase.a2, throughUnitId: 999),
      ],
    );
    expect(access.unlockedLessonIds, {101, 1601});
  });

  test(
    'legacy scalar retains its old open span without cross-phase dependencies',
    () {
      final access = policy.evaluate(
        orderedUnits: mixedUnits,
        lessonsByUnit: mixedLessons,
        completedLessonIds: {},
        provisionalThroughUnitId: 16,
      );
      expect(access.unlockedLessonIds, {101, 201, 1601});
      expect(access.lessonPrerequisites[2801], {101, 102, 201});
    },
  );
}
