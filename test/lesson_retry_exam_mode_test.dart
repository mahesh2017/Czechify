import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/domain/entities/exercise_outcome.dart';
import 'package:ceskina_pro/domain/entities/lesson.dart';
import 'package:ceskina_pro/domain/repositories/progress_repository.dart';
import 'package:ceskina_pro/presentation/providers/database_providers.dart';
import 'package:ceskina_pro/presentation/providers/gamification_providers.dart';
import 'package:ceskina_pro/presentation/providers/lesson_providers.dart';
import 'package:ceskina_pro/presentation/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lesson_session_harness.dart';

/// retry() used to rebuild the session from scratch without carrying
/// isExamMode across, so a retried exam quietly became a normal lesson:
/// the countdown vanished, the heart pool started counting again, and
/// nextExercise() appended mistake re-asks in the middle of an exam.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer containerFor({
    required LessonSessionNotifier Function() session,
    GamificationNotifier Function() gamification = TestGamificationNotifier.new,
    ProgressRepository? progress,
  }) {
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          progress ?? FakeProgressRepository(),
        ),
        curriculumRepositoryProvider.overrideWithValue(
          FakeCurriculumRepository(),
        ),
        gamificationProvider.overrideWith(gamification),
        settingsProvider.overrideWith(_TestSettingsNotifier.new),
        lessonSessionProvider.overrideWith(session),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('retrying an exam-prep lesson is still an exam', () async {
    final container = containerFor(session: _ExamSessionNotifier.new);
    final notifier = container.read(lessonSessionProvider.notifier);

    await notifier.retry();

    final state = container.read(lessonSessionProvider);
    expect(state.isExamMode, isTrue, reason: 'an exam stays an exam');
    expect(
      state.remainingSeconds,
      12 * 60,
      reason: 'the countdown restarts at the lesson duration',
    );
    expect(state.hearts, 999, reason: 'hearts stay out of an exam');
  });

  test('an empty heart pool cannot game-over a retried exam', () async {
    final container = containerFor(
      session: _ExamSessionNotifier.new,
      gamification: EmptyHeartsGamificationNotifier.new,
    );
    final notifier = container.read(lessonSessionProvider.notifier);

    await notifier.retry();

    expect(container.read(lessonSessionProvider).isGameOver, isFalse);
    expect(container.read(lessonSessionProvider).hearts, 999);

    // And a wrong answer inside the retried exam still costs nothing.
    await notifier.onExerciseAnswered(outcome: ExerciseOutcome.incorrect);
    expect(container.read(lessonSessionProvider).hearts, 999);
  });

  test('a retried exam does not re-ask the questions it missed', () async {
    final repo = FakeProgressRepository();
    final container = containerFor(
      session: _ExamSessionNotifier.new,
      progress: repo,
    );
    final notifier = container.read(lessonSessionProvider.notifier);
    await notifier.retry();

    await notifier.onExerciseAnswered(outcome: ExerciseOutcome.incorrect);
    await notifier.nextExercise();
    await notifier.onExerciseAnswered(outcome: ExerciseOutcome.correct);
    await notifier.nextExercise();

    final state = container.read(lessonSessionProvider);
    expect(
      state.exercises.length,
      2,
      reason: 'the miss is not appended to an exam',
    );
    expect(state.mistakesAppended, isFalse);
    expect(state.isComplete, isTrue, reason: 'the exam ended after both items');
    expect(repo.committed, isTrue);
  });

  test('a normal lesson retry still answers to the heart pool', () async {
    final container = containerFor(
      session: _NormalSessionNotifier.new,
      gamification: EmptyHeartsGamificationNotifier.new,
    );
    final notifier = container.read(lessonSessionProvider.notifier);

    await notifier.retry();

    final state = container.read(lessonSessionProvider);
    expect(state.isExamMode, isFalse);
    expect(state.hearts, 0, reason: 'hearts persist across attempts');
    expect(
      state.isGameOver,
      isTrue,
      reason: 'retrying without hearts cannot start',
    );
    expect(state.remainingSeconds, 0, reason: 'no countdown outside an exam');
  });
}

const _lesson = Lesson(
  id: 1,
  unitId: 1,
  orderInUnit: 0,
  title: 'Mock exam',
  description: 'Test',
  durationMinutes: 12,
);

const _exercises = [
  Exercise(
    id: 1,
    lessonId: 1,
    type: ExerciseType.pronunciation,
    prompt: 'Say this',
    data: {'target_text': 'Dobrý den'},
  ),
  Exercise(
    id: 2,
    lessonId: 1,
    type: ExerciseType.pronunciation,
    prompt: 'Say another',
    data: {'target_text': 'Na shledanou'},
  ),
];

/// Stands in for what loadLesson() builds from a unit with isExamPrep set,
/// so retry() can be driven without a database behind it.
class _ExamSessionNotifier extends LessonSessionNotifier {
  @override
  LessonSessionState build() => const LessonSessionState(
    lesson: _lesson,
    exercises: _exercises,
    originalCount: 2,
    hearts: 999,
    isExamMode: true,
    remainingSeconds: 12 * 60,
  );
}

class _NormalSessionNotifier extends LessonSessionNotifier {
  @override
  LessonSessionState build() => const LessonSessionState(
    lesson: _lesson,
    exercises: _exercises,
    originalCount: 2,
  );
}

/// Keeps the hearts and celebration calls off a database this test does
/// not need.

/// Settings load from SharedPreferences after an await; reading them for
/// real would outlive a test that ends the moment retry() returns.
class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

/// The unit-completion celebration is best-effort and already swallows its
/// own failures; this just keeps it from reaching for a real database.
