import '../entities/exam_result.dart';
import '../entities/enums.dart';

/// Versioned specification for one official exam product at one level. Kept
/// separate from the questions so timings/points/scoring are auditable against
/// the official model test and never blended between products.
class ExamBlueprint {
  final ExamProduct product;

  /// Blueprint version string (e.g. the official effective date "2026-04-11").
  final String version;

  /// Effective date of the official format this blueprint reproduces.
  final String effectiveDate;

  final ExamScoringRule scoringRule;

  const ExamBlueprint({
    required this.product,
    required this.version,
    required this.effectiveDate,
    required this.scoringRule,
  });
}

/// Mock exam definition.
class MockExam {
  /// Stable identity of this paper within its bank (e.g. `a2-practice-2`).
  ///
  /// A bank holds several interchangeable papers and one is picked at random
  /// per attempt, so nothing else distinguishes them: they share a level, a
  /// blueprint and — in every shipped bank — the same section lengths. An
  /// interrupted attempt has to name the paper it was taken from, or its
  /// answers get restored on top of whichever paper the next random draw
  /// returns.
  final String id;

  final ExamLevel level;
  final ExamBlueprint blueprint;
  final List<MockExamSection> sections;
  final int totalTimeMinutes;

  const MockExam({
    required this.id,
    required this.level,
    required this.blueprint,
    required this.sections,
    required this.totalTimeMinutes,
  });

  ExamProduct get product => blueprint.product;
}

/// A section of a mock exam.
class MockExamSection {
  final ExamSectionType type;
  final int timeLimitMinutes;
  final List<Map<String, dynamic>> questions;
  final int maxScore;

  const MockExamSection({
    required this.type,
    required this.timeLimitMinutes,
    required this.questions,
    required this.maxScore,
  });
}

/// Abstract interface for exam data access.
abstract class ExamRepository {
  Future<MockExam> getMockExam(
    ExamLevel level, {
    ExamProduct product = ExamProduct.permanentResidence,
  });

  /// The paper [id] names, or null when this bank no longer contains it.
  ///
  /// Resuming an interrupted attempt must land on the paper the answers were
  /// given to. Null means the checkpoint outlived its paper — a content update
  /// replaced the bank — and the caller must discard it rather than overlay
  /// those answers onto a different paper.
  Future<MockExam?> findMockExam(
    ExamLevel level,
    String id, {
    ExamProduct product = ExamProduct.permanentResidence,
  });
  Future<ExamResult> saveResult(ExamResult result);
  Future<List<ExamResult>> getResults(ExamLevel level, {ExamProduct? product});
}

/// Thrown when a shipped exam bank is corrupt or unreadable.  The caller
/// must surface this to the learner — never silently substitute minimal
/// sample content for a real exam bank that should be present.
class ExamAssetException implements Exception {
  final String message;
  final ExamLevel level;
  final ExamProduct product;

  const ExamAssetException(
    this.message, {
    required this.level,
    required this.product,
  });

  @override
  String toString() => 'ExamAssetException($product $level): $message';
}
