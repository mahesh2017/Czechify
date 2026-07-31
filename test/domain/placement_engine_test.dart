import 'package:ceskina_pro/domain/engines/placement_engine.dart';
import 'package:ceskina_pro/domain/entities/learning_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bank = <DiagnosticItem>[
    for (final skill in [
      LearningSkill.reading,
      LearningSkill.listening,
      LearningSkill.writing,
      LearningSkill.speaking,
    ])
      for (var level = 1; level <= 4; level++)
        DiagnosticItem(
          id: '${skill.name}-$level',
          skill: skill,
          difficulty: level / 5,
          unitCeiling: level * 6,
          optional: skill == LearningSkill.speaking,
        ),
  ];

  test('adaptive diagnostic samples weakly represented required skills', () {
    const engine = PlacementEngine();
    final observations = [
      DiagnosticObservation(
        item: bank.firstWhere((item) => item.skill == LearningSkill.reading),
        correct: true,
        independent: true,
      ),
    ];
    expect(
      engine.nextItem(bank: bank, observations: observations)!.skill,
      isNot(LearningSkill.reading),
    );
  });

  test('scaffolded success estimates below independent success', () {
    const engine = PlacementEngine();
    final item = bank.first;
    final independent = engine.estimateSkill([
      DiagnosticObservation(item: item, correct: true, independent: true),
    ], item.skill);
    final scaffolded = engine.estimateSkill([
      DiagnosticObservation(item: item, correct: true, independent: false),
    ], item.skill);
    expect(scaffolded, lessThan(independent));
  });

  test('delayed transfer failure lowers provisional placement', () {
    const engine = PlacementEngine();
    final observations =
        bank
            .where((item) => item.skill != LearningSkill.speaking)
            .take(9)
            .map(
              (item) => DiagnosticObservation(
                item: item,
                correct: true,
                independent: true,
              ),
            )
            .toList();
    final initial = engine.result(observations);
    final revised = engine.result(
      observations,
      earlyEvidence: [
        LearningEvidence(
          evidenceId: 'delayed-1',
          lessonId: 1,
          skill: LearningSkill.reading,
          phase: LearningPhase.delayedTransfer,
          correct: false,
          novelTask: true,
          responseLatency: const Duration(seconds: 20),
          observedAt: DateTime.utc(2026, 7, 30),
        ),
      ],
    );
    expect(
      revised.estimates[LearningSkill.reading],
      lessThan(initial.estimates[LearningSkill.reading]!),
    );
    expect(
      engine.result(observations, learnerOverrideUnit: 3).provisionalUnit,
      3,
    );
  });
}
