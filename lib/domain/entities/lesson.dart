import 'enums.dart';

/// A lesson within a unit.
class Lesson {
  final int id;
  final int unitId;
  final int orderInUnit;
  final String title;
  final String description;
  final int durationMinutes;
  final LessonType lessonType;
  final bool isReview;

  const Lesson({
    required this.id,
    required this.unitId,
    required this.orderInUnit,
    required this.title,
    required this.description,
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
      durationMinutes: json['duration_min'] as int? ?? 10,
      lessonType: LessonType.values.byName(
        json['lesson_type'] as String? ?? 'introduction',
      ),
      isReview: json['is_review'] as bool? ?? false,
    );
  }
}
