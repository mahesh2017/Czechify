import '../entities/pending_referral_receipt.dart';
import '../entities/gamification_state.dart';
import '../entities/exercise_attempt_evidence.dart';

/// Abstract interface for progress + gamification state persistence.
abstract class ProgressRepository {
  Stream<ProgressSnapshot> watchProgress();
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
    PendingReferralReceipt? referralReceipt,
  });
  Future<Set<int>> getCompletedLessonIds();
  Future<ProgressSnapshot> getSnapshot();
  Future<void> recordExamPassed(String level);
  Future<void> updateStreak(int currentStreak, int longestStreak);
}
