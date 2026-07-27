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
  final ExamLevel level;
  final ExamBlueprint blueprint;
  final List<MockExamSection> sections;
  final int totalTimeMinutes;

  const MockExam({
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
  Future<ExamResult> saveResult(ExamResult result);
  Future<List<ExamResult>> getResults(ExamLevel level, {ExamProduct? product});
}
