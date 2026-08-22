import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/domain/entities/exercise_outcome.dart';
import 'package:ceskina_pro/domain/engines/learning_loop_engine.dart';
import 'package:ceskina_pro/presentation/providers/lesson_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('skip is neutral and duplicate submission is ignored', () async {
    final container = ProviderContainer(
      overrides: [
        lessonSessionProvider.overrideWith(_TestLessonSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(lessonSessionProvider.notifier);

    await Future.wait([
      notifier.onExerciseAnswered(
        outcome: ExerciseOutcome.skipped,
        xpEarned: 20,
      ),
      notifier.onExerciseAnswered(
        outcome: ExerciseOutcome.skipped,
        xpEarned: 20,
      ),
    ]);

    final state = container.read(lessonSessionProvider);
    expect(state.lastWasSkipped, isTrue);
    expect(state.correctCount, 0);
    expect(state.wrongCount, 0);
    expect(state.totalXp, 0);
    expect(state.hearts, 5);
    expect(state.mistakeQueue, isEmpty);
    expect(state.showFeedback, isTrue);
  });

  test('duplicate correct callback grants lesson XP only once', () async {
    final container = ProviderContainer(
      overrides: [
        lessonSessionProvider.overrideWith(_TestLessonSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(lessonSessionProvider.notifier);

    await Future.wait([
      notifier.onExerciseAnswered(
        outcome: ExerciseOutcome.correct,
        xpEarned: 15,
      ),
      notifier.onExerciseAnswered(
        outcome: ExerciseOutcome.correct,
        xpEarned: 15,
      ),
    ]);

    final state = container.read(lessonSessionProvider);
    expect(state.correctCount, 1);
    expect(state.wrongCount, 0);
    expect(state.totalXp, 15);
  });

  test('advancing explicitly clears all prior feedback fields', () async {
    final container = ProviderContainer(
      overrides: [
        lessonSessionProvider.overrideWith(_TestLessonSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(lessonSessionProvider.notifier);

    await notifier.onExerciseAnswered(
      outcome: ExerciseOutcome.correct,
      explanation: 'Old explanation',
      correctAnswer: 'Old answer',
    );
    await notifier.nextExercise();

    final state = container.read(lessonSessionProvider);
    expect(state.currentIndex, 1);
    expect(state.showFeedback, isFalse);
    expect(state.lastExplanation, isNull);
    expect(state.lastCorrectAnswer, isNull);
    expect(state.lastGrammarRuleId, isNull);
    expect(state.lastOutcome, isNull);
  });

  test('first error signals without revealing explanation or answer', () async {
    final container = ProviderContainer(
      overrides: [
        lessonSessionProvider.overrideWith(_TestLessonSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(lessonSessionProvider.notifier);

    await notifier.onExerciseAnswered(
      outcome: ExerciseOutcome.incorrect,
      explanation: 'Full explanation',
      correctAnswer: 'Dobrý den',
    );

    final state = container.read(lessonSessionProvider);
    expect(state.feedbackStep, FeedbackStep.signal);
    expect(state.lastExplanation, isNull);
    expect(state.lastCorrectAnswer, isNull);
    expect(state.mistakeQueue, hasLength(1));
  });

  test('progress does not run backwards when mistakes are appended', () {
    const exercise = Exercise(
      id: 1,
      lessonId: 1,
      type: ExerciseType.pronunciation,
      prompt: 'Say this',
      data: {},
    );

    // Ten questions answered, ten questions long: the lesson proper is done.
    const finished = LessonSessionState(
      exercises: [exercise, exercise, exercise],
      originalCount: 3,
      currentIndex: 3,
    );
    expect(finished.progress, 1.0);

    // Three of them were missed and get appended. Dividing by the grown list
    // sent this to 0.5.
    const reviewing = LessonSessionState(
      exercises: [exercise, exercise, exercise, exercise, exercise, exercise],
      originalCount: 3,
      currentIndex: 3,
      mistakesAppended: true,
    );
    expect(reviewing.progress, 1.0);
    expect(reviewing.inMistakeReview, isTrue);
  });
}

class _TestLessonSessionNotifier extends LessonSessionNotifier {
  @override
  LessonSessionState build() => const LessonSessionState(
    exercises: [
      Exercise(
        id: 1,
        lessonId: 1,
        type: ExerciseType.pronunciation,
        prompt: 'Say this',
        data: {'target_text': 'Dobrý den'},
        xpReward: 15,
      ),
      Exercise(
        id: 2,
        lessonId: 1,
        type: ExerciseType.pronunciation,
        prompt: 'Say another',
        data: {'target_text': 'Na shledanou'},
        xpReward: 15,
      ),
    ],
    originalCount: 2,
    isExamMode: true,
  );
}
