import 'package:czechify/domain/engines/learning_router.dart';
import 'package:czechify/domain/entities/learning_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const levels = [
    LearningCandidate(
      lessonId: 1,
      order: 1,
      completed: false,
      isPreferredLevel: false,
      skills: {LearningSkill.grammar},
    ),
    LearningCandidate(
      lessonId: 16,
      order: 16,
      completed: false,
      skills: {LearningSkill.grammar},
    ),
  ];
  test('fresh A2 learner starts at A2 while A1 stays accessible', () {
    final route = const LearningRouter().select(
      candidates: levels,
      accessibleLessonIds: {1, 16},
      evidence: [],
    );
    expect(route?.lessonId, 16);
  });
  test('earlier-level evidence can still recommend targeted repair', () {
    final route = const LearningRouter().select(
      candidates: levels,
      accessibleLessonIds: {1, 16},
      evidence: [
        LearningEvidence(
          evidenceId: 'a1-repair',
          lessonId: 1,
          skill: LearningSkill.grammar,
          phase: LearningPhase.delayedTransfer,
          correct: false,
          novelTask: true,
          responseLatency: const Duration(seconds: 5),
          observedAt: DateTime(2026),
        ),
      ],
    );
    expect(route?.lessonId, 1);
  });
  test('inaccessible preferred level falls back to accessible work', () {
    final route = const LearningRouter().select(
      candidates: levels,
      accessibleLessonIds: {1},
      evidence: [],
    );
    expect(route?.lessonId, 1);
  });

  test('an A1 starter who has finished A1 moves on to A2', () {
    // The starting level never changes after onboarding. Counting finished
    // A1 lessons as "work at the preferred level" kept this learner on lesson
    // 1 for good, with "Maintain retained performance" as the reason.
    final route = const LearningRouter().select(
      candidates: const [
        LearningCandidate(
          lessonId: 1,
          order: 1,
          completed: true,
          skills: {LearningSkill.grammar},
        ),
        LearningCandidate(
          lessonId: 2,
          order: 2,
          completed: true,
          skills: {LearningSkill.grammar},
        ),
        LearningCandidate(
          lessonId: 16,
          order: 16,
          completed: false,
          isPreferredLevel: false,
          skills: {LearningSkill.grammar},
        ),
      ],
      accessibleLessonIds: {1, 2, 16},
      evidence: [],
    );
    expect(route?.lessonId, 16);
    expect(route?.kind, LearningRouteKind.newWork);
    expect(route?.kind.isRepair, isFalse);
  });

  test('independent misses in a finished lesson mark it for repair', () {
    // Two latest unaided misses outweigh an untouched lesson — this is the
    // pick Home shows as "Worth revisiting", beside the next lesson.
    LearningEvidence miss(int exerciseId) => LearningEvidence(
      evidenceId: 'miss-$exerciseId',
      lessonId: 3,
      exerciseId: exerciseId,
      skill: LearningSkill.grammar,
      phase: LearningPhase.retrieve,
      correct: false,
      novelTask: false,
      responseLatency: const Duration(seconds: 4),
      observedAt: DateTime(2026, 9, 1),
    );

    final route = const LearningRouter().select(
      candidates: const [
        LearningCandidate(
          lessonId: 3,
          order: 3,
          completed: true,
          skills: {LearningSkill.grammar},
        ),
        LearningCandidate(
          lessonId: 4,
          order: 4,
          completed: false,
          skills: {LearningSkill.grammar},
        ),
      ],
      accessibleLessonIds: {3, 4},
      evidence: [miss(31), miss(32)],
    );

    expect(route?.lessonId, 3);
    expect(route?.kind, LearningRouteKind.independentRepair);
    expect(route?.kind.isRepair, isTrue);
  });

  test('delayed novel-task failure outranks linear next lesson', () {
    const router = LearningRouter();
    final route = router.select(
      candidates: const [
        LearningCandidate(
          lessonId: 1,
          order: 1,
          completed: true,
          skills: {LearningSkill.interaction},
          conceptKeys: {'register'},
        ),
        LearningCandidate(
          lessonId: 2,
          order: 2,
          completed: false,
          skills: {LearningSkill.reading},
        ),
      ],
      accessibleLessonIds: const {1, 2},
      evidence: [
        LearningEvidence(
          evidenceId: 'transfer-fail',
          lessonId: 1,
          skill: LearningSkill.interaction,
          phase: LearningPhase.delayedTransfer,
          correct: false,
          novelTask: true,
          conceptKeys: const {'register'},
          responseLatency: const Duration(seconds: 30),
          observedAt: DateTime.utc(2026, 7, 30),
        ),
      ],
    );
    expect(route?.lessonId, 1);
    expect(route?.reason, 'Delayed transfer needs repair');
  });

  test('a mistake that was later put right stops pulling the learner back', () {
    // Home pointed at the same finished lesson every time. Evidence is
    // append-only, so two old wrong answers scored a completed lesson 1 above
    // an untouched lesson 2 permanently — and passing lesson 1 again could not
    // undo it, because a later success adds a row and removes nothing.
    const router = LearningRouter();
    LearningEvidence attempt({
      required String id,
      required int exerciseId,
      required bool correct,
      required DateTime at,
    }) => LearningEvidence(
      evidenceId: id,
      lessonId: 1,
      exerciseId: exerciseId,
      skill: LearningSkill.grammar,
      phase: LearningPhase.retrieve,
      correct: correct,
      novelTask: false,
      conceptKeys: const {'basics'},
      responseLatency: const Duration(seconds: 5),
      observedAt: at,
    );

    final route = router.select(
      candidates: const [
        LearningCandidate(
          lessonId: 1,
          order: 1,
          completed: true,
          skills: {LearningSkill.grammar},
          conceptKeys: {'basics'},
        ),
        LearningCandidate(
          lessonId: 2,
          order: 2,
          completed: false,
          skills: {LearningSkill.grammar},
        ),
      ],
      accessibleLessonIds: const {1, 2},
      evidence: [
        attempt(
          id: 'miss-a',
          exerciseId: 10,
          correct: false,
          at: DateTime.utc(2026, 8, 1),
        ),
        attempt(
          id: 'miss-b',
          exerciseId: 11,
          correct: false,
          at: DateTime.utc(2026, 8, 1),
        ),
        // Both put right on a later pass through the lesson.
        attempt(
          id: 'fix-a',
          exerciseId: 10,
          correct: true,
          at: DateTime.utc(2026, 8, 5),
        ),
        attempt(
          id: 'fix-b',
          exerciseId: 11,
          correct: true,
          at: DateTime.utc(2026, 8, 5),
        ),
      ],
    );

    expect(route?.lessonId, 2, reason: 'the learner should move forward');
    expect(route?.reason, 'Continue with new accessible work');
  });

  test('a mistake still outstanding does keep the learner there', () {
    // The other half of the same rule: reinforcement is about what is weak
    // now, so an unrepaired miss must still win.
    const router = LearningRouter();
    final route = router.select(
      candidates: const [
        LearningCandidate(
          lessonId: 1,
          order: 1,
          completed: true,
          skills: {LearningSkill.grammar},
          conceptKeys: {'basics'},
        ),
        LearningCandidate(
          lessonId: 2,
          order: 2,
          completed: false,
          skills: {LearningSkill.grammar},
        ),
      ],
      accessibleLessonIds: const {1, 2},
      evidence: [
        for (var i = 0; i < 2; i++)
          LearningEvidence(
            evidenceId: 'still-wrong-$i',
            lessonId: 1,
            exerciseId: 20 + i,
            skill: LearningSkill.grammar,
            phase: LearningPhase.retrieve,
            correct: false,
            novelTask: false,
            conceptKeys: const {'basics'},
            responseLatency: const Duration(seconds: 5),
            observedAt: DateTime.utc(2026, 8, 5),
          ),
      ],
    );

    expect(route?.lessonId, 1);
    expect(route?.reason, 'Independent practice needs reinforcement');
  });

  test('engagement rewards cannot influence routing contract', () {
    const router = LearningRouter();
    final route = router.select(
      candidates: const [
        LearningCandidate(
          lessonId: 7,
          order: 7,
          completed: false,
          skills: {LearningSkill.listening},
        ),
      ],
      accessibleLessonIds: const {7},
      evidence: const [],
    );
    expect(route?.lessonId, 7);
  });
}
