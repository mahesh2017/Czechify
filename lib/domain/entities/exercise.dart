import 'enums.dart';

/// An exercise within a lesson.
class Exercise {
  final int id;
  final int lessonId;
  final ExerciseType type;
  final String prompt;
  final Map<String, dynamic> data; // Type-specific JSON payload
  final String? answerKey;
  final String? grammarRuleId;
  final int xpReward;

  const Exercise({
    required this.id,
    required this.lessonId,
    required this.type,
    required this.prompt,
    required this.data,
    this.answerKey,
    this.grammarRuleId,
    this.xpReward = 10,
  });

  /// Whether this item is scored, a warm-up guess, a lecture check or guided
  /// practice. See [ExerciseMode].
  ExerciseMode get mode => ExerciseMode.fromData(data['mode']);

  /// A notebook step: a teaching card asking the learner to write in their
  /// paper notebook. Never graded, like every teaching card.
  bool get isNotebookStep =>
      type == ExerciseType.teaching && data['style'] == 'notebook';

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int,
      lessonId: json['lesson_id'] as int,
      type: ExerciseType.values.byName(json['type'] as String),
      prompt: json['prompt'] as String,
      data: json['data'] as Map<String, dynamic>,
      answerKey: json['answer_key'] as String?,
      grammarRuleId: json['grammar_rule_id'] as String?,
      xpReward: json['xp_reward'] as int? ?? 10,
    );
  }
}
