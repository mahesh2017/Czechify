import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('A2 Unit 16 ships a four-stage market communication sequence', () {
    final lessons = <Map<String, dynamic>>[
      for (var lesson = 1; lesson <= 4; lesson++) _readLesson(lesson),
    ];

    expect(lessons.map((lesson) => lesson['order_in_unit']), [0, 1, 2, 3]);
    expect(lessons.every((lesson) => lesson['duration_min'] == 12), isTrue);
    expect(
      lessons.every((lesson) => (lesson['exercises'] as List).length == 12),
      isTrue,
    );
    expect(lessons.last['lesson_type'], 'mission');
    expect(lessons.last['is_review'], isTrue);

    final exercises =
        [
          for (final lesson in lessons) ...lesson['exercises'] as List<dynamic>,
        ].cast<Map<String, dynamic>>();
    final types = exercises.map((exercise) => exercise['type']).toList();

    expect(types.where((type) => type == 'teaching'), hasLength(4));
    expect(
      types.where((type) => type == 'listening_comprehension'),
      hasLength(4),
    );
    expect(
      types.where((type) => type == 'reading_comprehension'),
      hasLength(4),
    );
    expect(types, containsAll(['dialogue', 'writing_task', 'speaking_task']));
    expect(lessons.last['exercises'].last['type'], 'speaking_task');

    final images = [
      for (final exercise in exercises)
        if (exercise['type'] == 'reading_comprehension')
          exercise['data']['image'] as String,
    ];
    expect(images.toSet(), hasLength(2));
    for (final image in images) {
      expect(File(image).existsSync(), isTrue, reason: image);
    }

    final recognitionOnly =
        types
            .where((type) => type == 'multiple_choice' || type == 'translation')
            .length;
    expect(recognitionOnly / exercises.length, lessThanOrEqualTo(0.25));
  });
}

Map<String, dynamic> _readLesson(int lesson) {
  final file = File(
    'assets/curriculum/lessons/unit16_lesson${lesson.toString().padLeft(2, '0')}.json',
  );
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}
