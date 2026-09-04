import 'package:czechify/domain/engines/learning_loop_engine.dart';
import 'package:czechify/domain/entities/learning_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful independent path schedules seven-day transfer', () {
    const engine = LearningLoopEngine();
    final now = DateTime.utc(2026, 7, 23);
    var state = engine.begin();
    state = engine.advance(state, correct: true, independent: true, now: now);
    expect(state.phase, LearningPhase.notice);
    state = engine.advance(state, correct: true, independent: true, now: now);
    expect(state.phase, LearningPhase.retrieve);
    state = engine.advance(state, correct: true, independent: true, now: now);
    expect(state.phase, LearningPhase.use);
    state = engine.advance(state, correct: true, independent: true, now: now);
    expect(state.phase, LearningPhase.delayedTransfer);
    expect(state.delayedTransferDue, DateTime.utc(2026, 7, 30));
  });

  test('feedback reveals progressively, then requires a variant', () {
    const engine = LearningLoopEngine();
    final now = DateTime.utc(2026, 7, 23);
    var state = const LearningLoopState(phase: LearningPhase.retrieve);
    for (final expected in [
      FeedbackStep.signal,
      FeedbackStep.selfRepair,
      FeedbackStep.cue,
      FeedbackStep.explanation,
    ]) {
      state = engine.advance(
        state,
        correct: false,
        independent: true,
        now: now,
      );
      expect(state.feedbackStep, expected);
    }
    state = engine.advance(state, correct: true, independent: true, now: now);
    expect(state.phase, LearningPhase.vary);
    expect(state.feedbackStep, FeedbackStep.immediateVariant);
  });

  test('supported retrieval cannot skip independent repair', () {
    const engine = LearningLoopEngine();
    final state = engine.advance(
      const LearningLoopState(phase: LearningPhase.retrieve),
      correct: true,
      independent: false,
      now: DateTime.utc(2026, 7, 23),
    );
    expect(state.phase, LearningPhase.repair);
  });
}
