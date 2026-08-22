import 'package:ceskina_pro/core/feedback/celebration.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/domain/entities/exercise_attempt_evidence.dart';
import 'package:ceskina_pro/domain/entities/exercise_outcome.dart';
import 'package:ceskina_pro/domain/entities/gamification_state.dart';
import 'package:ceskina_pro/domain/entities/lesson.dart';
import 'package:ceskina_pro/domain/entities/unit.dart';
import 'package:ceskina_pro/domain/repositories/curriculum_repository.dart';
import 'package:ceskina_pro/domain/repositories/progress_repository.dart';
import 'package:ceskina_pro/presentation/providers/database_providers.dart';
import 'package:ceskina_pro/presentation/providers/gamification_providers.dart';
import 'package:ceskina_pro/presentation/providers/lesson_providers.dart';
import 'package:ceskina_pro/presentation/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// retry() used to rebuild the session from scratch without carrying
/// isExamMode across, so a retried exam quietly became a normal lesson:
/// the countdown vanished, the heart pool started counting again, and
/// nextExercise() appended mistake re-asks in the middle of an exam.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer containerFor({
    required LessonSessionNotifier Function() session,
    GamificationNotifier Function() gamification =
        _TestGamificationNotifier.new,
    ProgressRepository? progress,
  }) {
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          progress ?? _FakeProgressRepository(),
        ),
        curriculumRepositoryProvider.overrideWithValue(
          _FakeCurriculumRepository(),
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
      gamification: _NoHeartsGamificationNotifier.new,
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
    final repo = _FakeProgressRepository();
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
      gamification: _NoHeartsGamificationNotifier.new,
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
class _TestGamificationNotifier extends GamificationNotifier {
  @override
  GamificationState build() => const GamificationState();

  @override
  Future<void> refreshHearts() async {}

  @override
  Future<List<Celebration>> refreshAfterCommittedLesson() async => const [];

  @override
  Future<int> onWrongAnswer() async => state.hearts - 1;
}

/// Settings load from SharedPreferences after an await; reading them for
/// real would outlive a test that ends the moment retry() returns.
class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

class _NoHeartsGamificationNotifier extends _TestGamificationNotifier {
  @override
  GamificationState build() => const GamificationState(hearts: 0);
}

/// The unit-completion celebration is best-effort and already swallows its
/// own failures; this just keeps it from reaching for a real database.
class _FakeCurriculumRepository implements CurriculumRepository {
  @override
  Future<List<Unit>> getUnits(Phase phase) async => const [];

  @override
  Future<Unit> getUnit(int unitId) async => throw UnimplementedError();

  @override
  Future<List<Lesson>> getLessons(int unitId) async => const [];

  @override
  Future<Lesson> getLesson(int lessonId) async => throw UnimplementedError();

  @override
  Future<List<Exercise>> getExercises(int lessonId) async => const [];
}

class _FakeProgressRepository implements ProgressRepository {
  bool committed = false;

  @override
  Future<bool> recordCompletion({
    required String attemptId,
    required int unitId,
    required int lessonId,
    required double score,
    required int correctCount,
    required int incorrectCount,
    required int skippedCount,
    required DateTime startedAt,
    required int activityXp,
    required List<ExerciseAttemptEvidence> exerciseEvidence,
    String phase = 'initial',
  }) async {
    committed = true;
    return true;
  }

  @override
  Stream<ProgressSnapshot> watchProgress() =>
      const Stream<ProgressSnapshot>.empty();

  @override
  Future<Set<int>> getCompletedLessonIds() async => <int>{};

  @override
  Future<ProgressSnapshot> getSnapshot() async => const ProgressSnapshot();

  @override
  Future<void> recordExamPassed(String level) async {}

  @override
  Future<void> updateStreak(int currentStreak, int longestStreak) async {}
}
