import 'enums.dart';

/// A lesson within a unit.
class Lesson {
  final int id;
  final int unitId;
  final int orderInUnit;
  final String title;
  final String description;
  final String canDo;
  final List<String> newLanguage;
  final List<String> recycles;
  final String exitTask;
  final int durationMinutes;
  final LessonType lessonType;
  final bool isReview;

  const Lesson({
    required this.id,
    required this.unitId,
    required this.orderInUnit,
    required this.title,
    required this.description,
    this.canDo = '',
    this.newLanguage = const [],
    this.recycles = const [],
    this.exitTask = '',
    this.durationMinutes = 10,
    this.lessonType = LessonType.introduction,
    this.isReview = false,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as int,
      unitId: json['unit_id'] as int,
      orderInUnit: json['order_in_unit'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      canDo: json['can_do'] as String? ?? '',
      newLanguage:
          (json['new_language'] as List<dynamic>? ?? const []).cast<String>(),
      recycles: (json['recycles'] as List<dynamic>? ?? const []).cast<String>(),
      exitTask: json['exit_task'] as String? ?? '',
      durationMinutes: json['duration_min'] as int? ?? 10,
      lessonType: LessonType.values.byName(
        json['lesson_type'] as String? ?? 'introduction',
      ),
      isReview: json['is_review'] as bool? ?? false,
    );
  }
}
