import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Units 4–10 ship complete four-lesson meaning-to-mission progressions',
    () {
      for (var unit = 4; unit <= 10; unit++) {
        final lessons = <Map<String, dynamic>>[
          for (var lesson = 1; lesson <= 4; lesson++) _readLesson(unit, lesson),
        ];

        expect(lessons.map((lesson) => lesson['order_in_unit']), [0, 1, 2, 3]);
        expect(lessons.every((lesson) => lesson['duration_min'] == 12), isTrue);
        expect(
          lessons.every(
            (lesson) => (lesson['can_do'] as String).trim().isNotEmpty,
          ),
          isTrue,
        );
        expect(
          lessons.every(
            (lesson) => (lesson['new_language'] as List).isNotEmpty,
          ),
          isTrue,
        );
        expect(
          lessons.every((lesson) => (lesson['recycles'] as List).isNotEmpty),
          isTrue,
        );
        expect(
          lessons.every(
            (lesson) => (lesson['exit_task'] as String).trim().isNotEmpty,
          ),
          isTrue,
        );
        expect(
          lessons.every((lesson) => (lesson['exercises'] as List).length == 12),
          isTrue,
        );
        expect(lessons.last['is_review'], isTrue);

        final exercises = [
          for (final lesson in lessons) ...lesson['exercises'] as List<dynamic>,
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

        final listeningTranscripts = exercises
            .where((exercise) => exercise['type'] == 'listening_comprehension')
            .map((exercise) => exercise['data']['transcript_cz'] as String)
            .toSet();
        final readingTexts = exercises
            .where((exercise) => exercise['type'] == 'reading_comprehension')
            .map((exercise) => exercise['data']['text_cz'] as String)
            .toSet();
        expect(listeningTranscripts.length, greaterThanOrEqualTo(7));
        expect(readingTexts.length, greaterThanOrEqualTo(4));

        final reading = exercises.firstWhere(
          (exercise) => exercise['type'] == 'reading_comprehension',
        );
        final imagePath = reading['data']['image'] as String;
        expect(
          File(imagePath).existsSync(),
          isTrue,
          reason: 'Unit $unit scene is missing: $imagePath',
        );
        expect(
          imagePath,
          startsWith('assets/images/unit${unit.toString().padLeft(2, '0')}/'),
        );

        final recognitionOnly = types
            .where((type) => type == 'multiple_choice' || type == 'translation')
            .length;
        expect(recognitionOnly / exercises.length, lessThanOrEqualTo(0.25));

        final serialized = jsonEncode(lessons);
        expect(serialized, isNot(contains('familiar everyday situation')));
        expect(
          serialized,
          isNot(
            contains('Is this the same recording as the first listening task?'),
          ),
        );
      }
    },
  );
}

Map<String, dynamic> _readLesson(int unit, int lesson) {
  final unitNumber = unit.toString().padLeft(2, '0');
  final lessonNumber = lesson.toString().padLeft(2, '0');
  final file = File(
    'assets/curriculum/lessons/unit${unitNumber}_lesson$lessonNumber.json',
  );
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}
