import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Units 11–15 ship four-stage visual communication missions', () {
    for (var unit = 11; unit <= 15; unit++) {
      final lessons = <Map<String, dynamic>>[
        for (var lesson = 1; lesson <= 4; lesson++) _readLesson(unit, lesson),
      ];

      expect(lessons.map((lesson) => lesson['order_in_unit']), [0, 1, 2, 3]);
      expect(lessons.every((lesson) => lesson['duration_min'] == 12), isTrue);
      expect(
        lessons.every((lesson) => (lesson['exercises'] as List).length == 12),
        isTrue,
      );
      expect(lessons.last['is_review'], isTrue);

      final exercises =
          [
            for (final lesson in lessons)
              ...lesson['exercises'] as List<dynamic>,
          ].cast<Map<String, dynamic>>();
      final types = exercises.map((exercise) => exercise['type']).toList();

      expect(types.where((type) => type == 'teaching'), hasLength(4));
      expect(
        types.where((type) => type == 'listening_comprehension').length,
        greaterThanOrEqualTo(7),
      );
      expect(
        types,
        containsAll([
          'reading_comprehension',
          'dialogue',
          'writing_task',
          'speaking_task',
        ]),
      );
      expect(lessons.last['exercises'].last['type'], 'speaking_task');

      final readingImages = [
        for (final lesson in lessons)
          (lesson['exercises'] as List<dynamic>).firstWhere(
                (exercise) => exercise['type'] == 'reading_comprehension',
              )['data']['image']
              as String,
      ];
      expect(readingImages.toSet(), hasLength(4));
      for (final imagePath in readingImages) {
        expect(File(imagePath).existsSync(), isTrue, reason: imagePath);
      }

      final recognitionOnly =
          types
              .where(
                (type) => type == 'multiple_choice' || type == 'translation',
              )
              .length;
      expect(recognitionOnly / exercises.length, lessThanOrEqualTo(0.25));
    }
  });
}

Map<String, dynamic> _readLesson(int unit, int lesson) {
  final file = File(
    'assets/curriculum/lessons/'
    'unit${unit.toString().padLeft(2, '0')}_lesson${lesson.toString().padLeft(2, '0')}.json',
  );
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}
