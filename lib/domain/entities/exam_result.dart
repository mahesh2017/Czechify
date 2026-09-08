import 'enums.dart';

/// Result of a mock exam.
class ExamResult {
  final int id;
  final ExamLevel level;

  /// Which official exam product this attempt simulated. Defaults to
  /// permanent-residence; legacy rows without a stored product read as such.
  final ExamProduct product;
  final DateTime takenAt;
  final int readingScore; // 0-100
  final int listeningScore; // 0-100

  /// 0-100, or null when the section was never assessed.
  ///
  /// Writing and speaking are scored outside the grader. An evaluator that is
  /// offline or fails leaves no score, which is not a zero — recording it as
  /// one showed the learner a service failure as their own result.
  final int? writingScore;
  final int? speakingScore;

  /// 0-100, or null while any productive section is unassessed.
  final int? totalScore;

  final bool passed;
  final Map<String, dynamic>? details;

  const ExamResult({
    required this.id,
    required this.level,
    this.product = ExamProduct.permanentResidence,
    required this.takenAt,
    required this.readingScore,
    required this.listeningScore,
    required this.writingScore,
    required this.speakingScore,
    required this.totalScore,
    required this.passed,
    this.details,
  });

  /// Whether every productive section was actually scored.
  bool get fullyScored => writingScore != null && speakingScore != null;
}
