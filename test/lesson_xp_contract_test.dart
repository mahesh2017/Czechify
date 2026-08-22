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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The HUD used to sum each exercise's authored xp_reward while the database
/// received a flat 10/15/20 by accuracy. A lesson could display 125 XP and
/// commit 20.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the lesson records exactly the XP it showed the learner', () async {
    final repo = _FakeProgressRepository();
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        curriculumRepositoryProvider.overrideWithValue(
          _FakeCurriculumRepository(),
        ),
        gamificationProvider.overrideWith(_TestGamificationNotifier.new),
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
    final repo = _FakeProgressRepository();
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        curriculumRepositoryProvider.overrideWithValue(
          _FakeCurriculumRepository(),
        ),
        gamificationProvider.overrideWith(_TestGamificationNotifier.new),
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
    // Skips the mistake re-ask pass so the lesson ends after both answers.
    isExamMode: true,
  );
}

/// Keeps the hearts and celebration calls on the completion path from
/// reaching a database this test does not need.
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
  int? recordedXp;

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
    recordedXp = activityXp;
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
