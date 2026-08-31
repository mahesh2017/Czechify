import 'package:czechify/domain/engines/unit_completion_detector.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/unit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finishing a unit was previously undetectable: units were only ever read
/// backwards, as "which are unlocked". These pin the forward question.
void main() {
  const detector = UnitCompletionDetector();

  Unit unit(int id, int order, String title) => Unit(
    id: id,
    title: title,
    description: '',
    phase: Phase.a1,
    orderIndex: order,
  );

  Lesson lesson(int id, int unitId, int order) => Lesson(
    id: id,
    unitId: unitId,
    title: 'Lesson $id',
    description: '',
    orderInUnit: order,
  );

  // Unit 4 is two lessons, which is the shape of nearly every unit here.
  final phase = [
    unit(3, 30, 'Numbers'),
    unit(4, 40, 'Greetings'),
    unit(5, 50, 'At the Café'),
  ];
  final unitLessons = [lesson(41, 4, 0), lesson(42, 4, 1)];

  UnitMilestone? evaluate({
    required int justFinished,
    required Set<int> before,
    required Set<int> now,
    List<Unit>? units,
    List<Lesson>? lessons,
  }) => detector.evaluate(
    lesson: (lessons ?? unitLessons).firstWhere((l) => l.id == justFinished),
    unit: (units ?? phase).firstWhere((u) => u.id == 4),
    unitLessons: lessons ?? unitLessons,
    phaseUnits: units ?? phase,
    completedBefore: before,
    completedNow: now,
  );

  test('the last lesson of a unit finishes it', () {
    final milestone = evaluate(justFinished: 42, before: {41}, now: {41, 42});
    expect(milestone, isNotNull);
    expect(milestone!.unitId, 4);
    expect(milestone.title, 'Greetings');
  });

  test('an earlier lesson does not', () {
    expect(evaluate(justFinished: 41, before: const {}, now: {41}), isNull);
  });

  group('replaying must not celebrate again', () {
    test('re-finishing the last lesson of a finished unit is silent', () {
      // Every lesson is complete either way — the only thing separating a
      // first finish from a replay is whether this one was already done.
      expect(
        evaluate(justFinished: 42, before: {41, 42}, now: {41, 42}),
        isNull,
      );
    });

    test('replaying an earlier lesson of a finished unit is silent', () {
      expect(
        evaluate(justFinished: 41, before: {41, 42}, now: {41, 42}),
        isNull,
      );
    });
  });

  group('numbering follows what the learner sees', () {
    test('it is the position in the phase, not the row id', () {
      // Unit id 4 sits second in this phase. Showing "Unit 4" here would
      // disagree with the curriculum screen, which numbers by position.
      final milestone = evaluate(justFinished: 42, before: {41}, now: {41, 42});
      expect(milestone!.number, 2);
    });

    test('order comes from orderIndex, not from list order', () {
      final shuffled = [phase[2], phase[0], phase[1]];
      final milestone = evaluate(
        justFinished: 42,
        before: {41},
        now: {41, 42},
        units: shuffled,
      );
      expect(milestone!.number, 2);
      expect(milestone.nextTitle, 'At the Café');
    });
  });

  group('what it unlocked', () {
    test('it names the next unit', () {
      final milestone = evaluate(justFinished: 42, before: {41}, now: {41, 42});
      expect(milestone!.nextTitle, 'At the Café');
    });

    test('the last unit of a phase names nothing', () {
      final last = [unit(4, 40, 'Greetings')];
      final milestone = evaluate(
        justFinished: 42,
        before: {41},
        now: {41, 42},
        units: last,
      );
      expect(milestone!.nextTitle, isNull);
    });
  });

  test('a unit with no lessons cannot be finished', () {
    // Guards against an empty list reading as "all complete", which would
    // celebrate a unit that has no content at all.
    expect(
      detector.evaluate(
        lesson: lesson(42, 4, 1),
        unit: phase[1],
        unitLessons: const [],
        phaseUnits: phase,
        completedBefore: const {},
        completedNow: {42},
      ),
      isNull,
    );
  });

  test('a unit is not finished while any lesson is outstanding', () {
    final three = [...unitLessons, lesson(43, 4, 2)];
    expect(
      evaluate(justFinished: 42, before: {41}, now: {41, 42}, lessons: three),
      isNull,
    );
  });
}
