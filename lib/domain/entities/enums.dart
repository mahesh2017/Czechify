/// CEFR proficiency level.
enum CEFRLevel {
  preA1('Pre-A1'),
  a1('A1'),
  a2('A2');

  const CEFRLevel(this.label);
  final String label;
}

/// Curriculum phase.
enum Phase { a1, a2 }

/// Exercise types supported by the app.
enum ExerciseType {
  multipleChoice,
  fillBlank,
  translation,
  wordOrder,
  dictation,
  pronunciation,
  declensionTable,
  aspectRecognition,
  prepositionCase,
  listening,
  dialogue,
  matching,
  errorCorrection,
  readingComprehension,
  listeningComprehension,
  writingTask,
  speakingTask,
  // A non-graded presentation card: teaches a concept (text + audio, later
  // video) before the practice exercises. Costs no heart, earns no XP.
  teaching,
}

/// Lesson types.
enum LessonType { introduction, practice, application, review }

/// Exam level.
enum ExamLevel { a1, a2 }

/// Exam section types.
enum ExamSectionType { reading, listening, writing, speaking }

/// Official exam product simulated by a bank. Each product is a distinct
/// exam with its own blueprint (timings, task inventory, point map) and its
/// own scoring rule — they are never blended into one test.
enum ExamProduct {
  /// State exam required as the language proof for permanent residence.
  permanentResidence,

  /// Certifikovaná zkouška z češtiny pro cizince (ÚJOP, Charles University).
  cce,
}

extension ExamProductAsset on ExamProduct {
  /// Filename slug for `exam_bank_<slug>_<level>.json`.
  String get slug => switch (this) {
        ExamProduct.permanentResidence => 'permres',
        ExamProduct.cce => 'cce',
      };

  /// Learner-facing product name.
  String get displayName => switch (this) {
        ExamProduct.permanentResidence => 'Permanent-residence',
        ExamProduct.cce => 'CCE',
      };

  /// Persisted/serialized identifier.
  String get id => switch (this) {
        ExamProduct.permanentResidence => 'permanent_residence',
        ExamProduct.cce => 'cce',
      };

  static ExamProduct fromId(String? value) => switch (value) {
        'cce' => ExamProduct.cce,
        _ => ExamProduct.permanentResidence, // default + legacy rows
      };
}

/// How a product converts section points into a pass/fail decision.
enum ExamScoringRule {
  /// Raw points; pass = ≥60% of written (reading+listening+writing) combined
  /// AND ≥60% of speaking. Permanent-residence A2 (110-point) format.
  rawPointsWrittenSpeakingGate,

  /// Percentage-transformed; pass = ≥60% overall AND ≥60% in EACH of the four
  /// parts independently. CCE format — not yet implemented (no CCE bank ships).
  percentagePerPartGate,
}

extension ExamScoringRuleId on ExamScoringRule {
  String get id => switch (this) {
        ExamScoringRule.rawPointsWrittenSpeakingGate => 'raw_points_written_speaking_gate',
        ExamScoringRule.percentagePerPartGate => 'percentage_per_part_gate',
      };

  static ExamScoringRule fromId(String? value) => switch (value) {
        'percentage_per_part_gate' => ExamScoringRule.percentagePerPartGate,
        _ => ExamScoringRule.rawPointsWrittenSpeakingGate,
      };
}