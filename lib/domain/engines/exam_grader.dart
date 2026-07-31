import '../entities/enums.dart';
import '../repositories/exam_repository.dart';

/// Per-section and overall scores for a graded mock exam.
///
/// Stores both raw points (matching the permanent-residence A2 format) and
/// percentage scores (0-100, for backwards compatibility with the UI and DB).
class ExamScores {
  final int reading; // 0-100
  final int listening; // 0-100
  final int writing; // 0-100
  final int speaking; // 0-100
  final int total; // 0-100
  final bool passed;
  final bool fullyScored;

  /// Raw points earned per section (permanent-residence A2 format: reading 25,
  /// writing 20, listening 25, speaking 40).
  final int readingPoints;
  final int listeningPoints;
  final int writingPoints;
  final int speakingPoints;
  final int totalPoints;

  /// Maximum points per section (from the exam definition).
  final int readingMax;
  final int listeningMax;
  final int writingMax;
  final int speakingMax;
  final int totalMax;

  const ExamScores({
    required this.reading,
    required this.listening,
    required this.writing,
    required this.speaking,
    required this.total,
    required this.passed,
    required this.fullyScored,
    this.readingPoints = 0,
    this.listeningPoints = 0,
    this.writingPoints = 0,
    this.speakingPoints = 0,
    this.totalPoints = 0,
    this.readingMax = 100,
    this.listeningMax = 100,
    this.writingMax = 100,
    this.speakingMax = 100,
    this.totalMax = 400,
  });
}

/// Pure grading logic for mock exams — no I/O, fully testable.
///
/// Implements the permanent-residence A2 scoring rule
/// ([ExamScoringRule.rawPointsWrittenSpeakingGate]). Multiple-choice sections
/// (reading, listening) are graded against each question's `correct_answer`.
/// Writing and speaking scores are produced elsewhere (AI evaluation /
/// pronunciation scoring) and passed in.
///
/// Dual pass threshold: the candidate must score ≥60% in the written parts
/// (reading + writing + listening) combined AND ≥60% in the speaking part —
/// the permanent-residence format effective 11 April 2026. The CCE
/// percentage-per-part rule is a separate scoring rule and is not implemented
/// here (no CCE bank ships).
class ExamGrader {
  /// Minimum percentage to pass any part.
  static const passThreshold = 60;

  /// Grade an exam.
  ///
  /// [answers] is keyed by section index, then question index within that
  /// section — sections must never share answer slots.
  ///
  /// [writingScore] and [speakingScore] are 0-100 percentages from external
  /// evaluation (AI writing evaluation / pronunciation scoring).
  ExamScores grade({
    required MockExam exam,
    required Map<int, Map<int, dynamic>> answers,
    int? writingScore,
    int? speakingScore,
  }) {
    var readingPoints = 0;
    var listeningPoints = 0;
    var readingMax = 0;
    var listeningMax = 0;
    var writingMax = 0;
    var speakingMax = 0;

    for (var s = 0; s < exam.sections.length; s++) {
      final section = exam.sections[s];
      switch (section.type) {
        case ExamSectionType.reading:
          readingMax = section.maxScore;
          readingPoints = _gradeChoiceSection(section, answers[s] ?? const {});
        case ExamSectionType.listening:
          listeningMax = section.maxScore;
          listeningPoints = _gradeChoiceSection(
            section,
            answers[s] ?? const {},
          );
        case ExamSectionType.writing:
          writingMax = section.maxScore;
          break; // scored externally
        case ExamSectionType.speaking:
          speakingMax = section.maxScore;
          break; // scored externally
      }
    }

    // External scores come in as 0-100 percentages; convert to raw points.
    final fullyScored =
        (writingMax == 0 || writingScore != null) &&
        (speakingMax == 0 || speakingScore != null);
    final writingPct = (writingScore ?? 0).clamp(0, 100);
    final speakingPct = (speakingScore ?? 0).clamp(0, 100);
    final writingPts = ((writingPct / 100) * writingMax).round();
    final speakingPts = ((speakingPct / 100) * speakingMax).round();

    // Percentage scores per section (0-100).
    final reading =
        readingMax > 0 ? ((readingPoints / readingMax) * 100).round() : 0;
    final listening =
        listeningMax > 0 ? ((listeningPoints / listeningMax) * 100).round() : 0;
    final writing = writingPct;
    final speaking = speakingPct;

    final totalPoints =
        readingPoints + writingPts + listeningPoints + speakingPts;
    final totalMax = readingMax + writingMax + listeningMax + speakingMax;

    // Dual pass threshold: ≥60% in written parts AND ≥60% in speaking.
    final writtenPoints = readingPoints + writingPts + listeningPoints;
    final writtenMax = readingMax + writingMax + listeningMax;
    final writtenPct =
        writtenMax > 0 ? (writtenPoints / writtenMax * 100).round() : 0;
    final speakingPctCalculated =
        speakingMax > 0 ? (speakingPts / speakingMax * 100).round() : 0;
    final passed =
        fullyScored &&
        writtenPct >= passThreshold &&
        speakingPctCalculated >= passThreshold;

    // Total as overall percentage.
    final total =
        totalMax > 0
            ? ((totalPoints / totalMax) * 100).round()
            : ((reading + listening + writing + speaking) / 4).round();

    return ExamScores(
      reading: reading,
      listening: listening,
      writing: writing,
      speaking: speaking,
      total: total,
      passed: passed,
      fullyScored: fullyScored,
      readingPoints: readingPoints,
      listeningPoints: listeningPoints,
      writingPoints: writingPts,
      speakingPoints: speakingPts,
      totalPoints: totalPoints,
      readingMax: readingMax,
      listeningMax: listeningMax,
      writingMax: writingMax,
      speakingMax: speakingMax,
      totalMax: totalMax,
    );
  }

  /// Grade a multiple-choice section and return raw points earned.
  int _gradeChoiceSection(
    MockExamSection section,
    Map<int, dynamic> sectionAnswers,
  ) {
    if (section.questions.isEmpty) return 0;

    var earnedPoints = 0;
    for (var q = 0; q < section.questions.length; q++) {
      final correctAnswer = section.questions[q]['correct_answer'];
      // Unanswered questions or questions without a key are wrong —
      // never let null == null count as correct.
      if (correctAnswer == null) continue;
      final userAnswer = sectionAnswers[q];
      if (userAnswer != null && userAnswer == correctAnswer) {
        // Each question's point value, defaulting to evenly divided points.
        final points =
            section.questions[q]['points'] as int? ??
            (section.maxScore ~/ section.questions.length);
        earnedPoints += points;
      }
    }

    // Cap at section max.
    return earnedPoints > section.maxScore ? section.maxScore : earnedPoints;
  }
}
