import 'package:czechify/core/feedback/answer_streak.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/presentation/providers/lesson_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A run of correct answers is what stops answer forty feeling identical to
/// answer four. These pin when it survives and when it resets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late LessonSessionNotifier notifier;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        lessonSessionProvider.overrideWith(_StreakSessionNotifier.new),
      ],
    );
    notifier = container.read(lessonSessionProvider.notifier);
  });

  tearDown(() => container.dispose());

  LessonSessionState state() => container.read(lessonSessionProvider);

  Future<void> answer(ExerciseOutcome outcome) async {
    await notifier.onExerciseAnswered(outcome: outcome);
    await notifier.nextExercise();
  }

  test('correct answers build a run', () async {
    await answer(ExerciseOutcome.correct);
    expect(state().answerStreak, 1);
    await answer(ExerciseOutcome.correct);
    await answer(ExerciseOutcome.correct);
    expect(state().answerStreak, 3);
  });

  test('a wrong answer resets it', () async {
    await answer(ExerciseOutcome.correct);
    await answer(ExerciseOutcome.correct);
    await answer(ExerciseOutcome.incorrect);
    expect(state().answerStreak, 0);
  });

  test('skipping resets it too', () async {
    // Otherwise skipping every hard question would keep a run alive, which
    // rewards avoiding exactly the work that teaches.
    await answer(ExerciseOutcome.correct);
    await answer(ExerciseOutcome.skipped);
    expect(state().answerStreak, 0);
  });

  test('the run can be rebuilt after a mistake', () async {
    await answer(ExerciseOutcome.correct);
    await answer(ExerciseOutcome.incorrect);
    await answer(ExerciseOutcome.correct);
    await answer(ExerciseOutcome.correct);
    expect(state().answerStreak, 2);
  });

  test('the best run survives being broken', () async {
    // The completion screen credits what they managed, not what they ended on.
    await answer(ExerciseOutcome.correct);
    await answer(ExerciseOutcome.correct);
    await answer(ExerciseOutcome.correct);
    await answer(ExerciseOutcome.incorrect);
    expect(state().answerStreak, 0);
    expect(state().bestAnswerStreak, 3);
  });

  test('milestones are sparse enough to stay meaningful', () {
    // A lesson is around thirteen exercises. Marking every fourth answer
    // would turn the reward into wallpaper.
    final inOneLesson = List.generate(
      13,
      (i) => i + 1,
    ).where(AnswerStreak.isMilestone);
    expect(inOneLesson, [3, 5, 10]);
  });

  test('the label carries the number', () {
    expect(AnswerStreak.label(5), contains('5'));
  });
}

class _StreakSessionNotifier extends LessonSessionNotifier {
  @override
  LessonSessionState build() => LessonSessionState(
    exercises: [
      for (var i = 1; i <= 8; i++)
        Exercise(
          id: i,
          lessonId: 1,
          type: ExerciseType.multipleChoice,
          prompt: 'Question $i',
          data: const {
            'type': 'multiple_choice',
            'options': ['a', 'b'],
            'correct_index': 0,
          },
          xpReward: 10,
        ),
    ],
    originalCount: 8,
    // Exam mode keeps hearts and mistake re-asks out of the way; the run
    // itself is what is under test.
    isExamMode: true,
  );
}
