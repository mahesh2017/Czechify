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
  final int writingScore; // 0-100
  final int speakingScore; // 0-100
  final int totalScore; // 0-100
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

  int get sectionAverage =>
      ((readingScore + listeningScore + writingScore + speakingScore) / 4)
          .round();
}
