import 'enums.dart';

/// A curriculum unit (e.g., "Unit 1: Sounds & Pronunciation").
class Unit {
  final int id;
  final String title;
  final String description;
  final Phase phase;
  final int orderIndex;
  final List<String> grammarTags;
  final bool isExamPrep;
  final int? lessonCount;

  const Unit({
    required this.id,
    required this.title,
    required this.description,
    required this.phase,
    required this.orderIndex,
    this.grammarTags = const [],
    this.isExamPrep = false,
    this.lessonCount,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      phase: Phase.values.byName(json['phase'] as String),
      orderIndex: json['order_index'] as int,
      grammarTags:
          (json['grammar_tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isExamPrep: json['is_exam_prep'] as bool? ?? false,
      lessonCount: json['lesson_count'] as int?,
    );
  }
}
