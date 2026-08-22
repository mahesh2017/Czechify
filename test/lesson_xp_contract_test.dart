import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/domain/entities/exercise_outcome.dart';
import 'package:ceskina_pro/domain/entities/lesson.dart';
import 'package:ceskina_pro/presentation/providers/database_providers.dart';
import 'package:ceskina_pro/presentation/providers/gamification_providers.dart';
import 'package:ceskina_pro/presentation/providers/lesson_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lesson_session_harness.dart';

/// The HUD used to sum each exercise's authored xp_reward while the database
/// received a flat 10/15/20 by accuracy. A lesson could display 125 XP and
/// commit 20.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the lesson records exactly the XP it showed the learner', () async {
    final repo = FakeProgressRepository();
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        curriculumRepositoryProvider.overrideWithValue(
          FakeCurriculumRepository(),
        ),
        gamificationProvider.overrideWith(TestGamificationNotifier.new),
        lessonSessionProvider.overrideWith(_TestLessonSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(lessonSessionProvider.notifier);

    // Arms the attempt without needing a database behind loadLesson.
    await notifier.retry();

    for (final xp in const [25, 30]) {
      await notifier.onExerciseAnswered(
        outcome: ExerciseOutcome.correct,
        xpEarned: xp,
      );
      await notifier.nextExercise();
    }

    final shown = container.read(lessonSessionProvider).totalXp;
    expect(shown, 55, reason: 'the HUD adds up the per-exercise rewards');
    expect(repo.recordedXp, isNotNull, reason: 'the lesson committed');
    expect(repo.recordedXp, shown);
  });

  test('a re-asked mistake pays into both numbers or neither', () async {
    final repo = FakeProgressRepository();
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        curriculumRepositoryProvider.overrideWithValue(
          FakeCurriculumRepository(),
        ),
        gamificationProvider.overrideWith(TestGamificationNotifier.new),
        lessonSessionProvider.overrideWith(_TestLessonSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(lessonSessionProvider.notifier);
    await notifier.retry();

    await notifier.onExerciseAnswered(
      outcome: ExerciseOutcome.correct,
      xpEarned: 25,
    );
    await notifier.nextExercise();
    await notifier.onExerciseAnswered(
      outcome: ExerciseOutcome.incorrect,
      xpEarned: 30,
    );
    expect(
      container.read(lessonSessionProvider).totalXp,
      25,
      reason: 'a missed exercise pays nothing on the attempt that missed it',
    );

    // The miss is re-asked before the lesson ends; getting it right then does
    // pay, and the recorded total has to follow the displayed one through it.
    await notifier.nextExercise();
    await notifier.onExerciseAnswered(
      outcome: ExerciseOutcome.correct,
      xpEarned: 30,
    );
    await notifier.nextExercise();

    final shown = container.read(lessonSessionProvider).totalXp;
    expect(shown, 55);
    expect(repo.recordedXp, shown);
  });
}

class _TestLessonSessionNotifier extends LessonSessionNotifier {
  @override
  LessonSessionState build() => const LessonSessionState(
    lesson: Lesson(
      id: 1,
      unitId: 1,
      orderInUnit: 0,
      title: 'Test lesson',
      description: 'Test',
    ),
    exercises: [
      Exercise(
        id: 1,
        lessonId: 1,
        type: ExerciseType.pronunciation,
        prompt: 'Say this',
        data: {'target_text': 'Dobrý den'},
        xpReward: 25,
      ),
      Exercise(
        id: 2,
        lessonId: 1,
        type: ExerciseType.pronunciation,
        prompt: 'Say another',
        data: {'target_text': 'Na shledanou'},
        xpReward: 30,
      ),
    ],
    originalCount: 2,
    // An ordinary lesson, so the mistake re-ask pass is in play — that is the
    // path the second test needs. This used to say isExamMode: true and still
    // reach the re-asks, because retry() dropped exam mode on the way through;
    // the test was passing for the wrong reason until that was fixed.
    isExamMode: false,
  );
}
