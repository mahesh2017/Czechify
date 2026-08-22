import 'package:ceskina_pro/core/feedback/celebration.dart';
import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/domain/entities/exercise_attempt_evidence.dart';
import 'package:ceskina_pro/domain/entities/gamification_state.dart';
import 'package:ceskina_pro/domain/entities/lesson.dart';
import 'package:ceskina_pro/domain/entities/unit.dart';
import 'package:ceskina_pro/domain/repositories/curriculum_repository.dart';
import 'package:ceskina_pro/domain/repositories/progress_repository.dart';
import 'package:ceskina_pro/presentation/providers/gamification_providers.dart';

/// Doubles for the three repositories a lesson session reaches for, so a test
/// can drive [LessonSessionNotifier] without standing up Drift.
///
/// Both the XP-contract and exam-retry tests needed exactly these; keeping one
/// copy means a change to a repository interface breaks in one place.

/// Captures what the lesson committed.
class FakeProgressRepository implements ProgressRepository {
  int? recordedXp;
  int recordCalls = 0;

  /// Whether the lesson reached the point of committing an attempt.
  bool get committed => recordCalls > 0;

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
    recordCalls++;
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

/// The unit-completion celebration is best-effort and swallows its own
/// failures; this only keeps it from reaching for a real database.
class FakeCurriculumRepository implements CurriculumRepository {
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

/// Keeps hearts, celebrations and the wrong-answer path off the database.
class TestGamificationNotifier extends GamificationNotifier {
  @override
  GamificationState build() => const GamificationState();

  @override
  Future<void> refreshHearts() async {}

  @override
  Future<List<Celebration>> refreshAfterCommittedLesson() async => const [];

  @override
  Future<int> onWrongAnswer() async => state.hearts - 1;
}

/// A gamification stub with no hearts left, for the game-over paths.
class EmptyHeartsGamificationNotifier extends TestGamificationNotifier {
  @override
  GamificationState build() => const GamificationState(hearts: 0);
}
