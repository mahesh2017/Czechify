import '../entities/lesson.dart';
import 'course_access_policy.dart';
import 'curriculum_access_policy.dart';

enum LessonAdmission {
  allowed,
  loading,
  paymentRequired,
  prerequisiteRequired,
  reverificationRequired,
  accountTransition,
  invalidContent,
}

/// An existing attempt may finish across an expiry, but cannot admit another
/// lesson, another attempt, or another account (including switching away/back).
class LessonAdmissionPermit {
  final String accountId;
  final int accountEpoch;
  final int lessonId;
  final String attemptId;
  final DateTime admittedAt;

  const LessonAdmissionPermit({
    required this.accountId,
    required this.accountEpoch,
    required this.lessonId,
    required this.attemptId,
    required this.admittedAt,
  });

  bool allows({
    required String? accountId,
    required int accountEpoch,
    required int lessonId,
    required String? attemptId,
    required DateTime now,
  }) =>
      this.accountId == accountId &&
      this.accountEpoch == accountEpoch &&
      this.lessonId == lessonId &&
      this.attemptId == attemptId &&
      !now.isBefore(admittedAt) &&
      now.isBefore(admittedAt.add(const Duration(hours: 2)));
}

class LessonAdmissionPolicy {
  const LessonAdmissionPolicy();

  LessonAdmission evaluate({
    required Lesson? lesson,
    required CurriculumAccess? progression,
    required CourseAccess? commercial,
    required DateTime now,
    required String? accountId,
    required int accountEpoch,
    bool accountTransition = false,
    bool loading = false,
    String? attemptId,
    LessonAdmissionPermit? permit,
  }) {
    if (accountTransition) return LessonAdmission.accountTransition;
    if (loading) return LessonAdmission.loading;
    if (lesson == null) return LessonAdmission.invalidContent;
    if (permit?.allows(
          accountId: accountId,
          accountEpoch: accountEpoch,
          lessonId: lesson.id,
          attemptId: attemptId,
          now: now,
        ) ??
        false) {
      return LessonAdmission.allowed;
    }
    if (commercial == null || progression == null) {
      return LessonAdmission.loading;
    }
    if (!progression.lessonPrerequisites.containsKey(lesson.id)) {
      return LessonAdmission.invalidContent;
    }
    if (!commercial.canAccessUnit(lesson.unitId)) {
      return commercial.reverificationUnitIds.contains(lesson.unitId)
          ? LessonAdmission.reverificationRequired
          : LessonAdmission.paymentRequired;
    }
    return progression.unlockedLessonIds.contains(lesson.id)
        ? LessonAdmission.allowed
        : LessonAdmission.prerequisiteRequired;
  }
}
