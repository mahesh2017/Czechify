import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final lessonPaths = List.generate(
    4,
    (index) => 'assets/curriculum/lessons/unit01_lesson0$index.json',
  );

  test('Unit 1 has four short, sequenced lessons with valid unique IDs', () {
    final lessons =
        lessonPaths
            .map(
              (path) =>
                  jsonDecode(File(path).readAsStringSync())
                      as Map<String, dynamic>,
            )
            .toList();

    expect(lessons.map((lesson) => lesson['order_in_unit']), [0, 1, 2, 3]);
    expect(
      lessons.every((lesson) => (lesson['duration_min'] as int) <= 13),
      isTrue,
    );

    final ids = <int>[];
    for (final lesson in lessons) {
      final lessonId = lesson['id'] as int;
      final exercises = lesson['exercises'] as List<dynamic>;
      expect(exercises.length, greaterThanOrEqualTo(10));
      for (final raw in exercises) {
        final exercise = raw as Map<String, dynamic>;
        expect(exercise['lesson_id'], lessonId);
        ids.add(exercise['id'] as int);
      }
    }
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('Unit 1 includes perception, useful repair, and formative transfer', () {
    final allText = lessonPaths
        .map(File.new)
        .map((file) => file.readAsStringSync())
        .join('\n');
    final types = <String>[];
    for (final path in lessonPaths) {
      final lesson =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      for (final raw in lesson['exercises'] as List<dynamic>) {
        types.add((raw as Map<String, dynamic>)['type'] as String);
      }
    }

    expect(
      types.where((type) => type == 'listening_comprehension').length,
      greaterThanOrEqualTo(5),
    );
    expect(
      types,
      containsAll(['reading_comprehension', 'speaking_task', 'writing_task']),
    );
    expect(allText, contains('Nerozumím.'));
    expect(allText, contains('Ještě jednou, prosím.'));
    expect(allText, contains('Prosím pomalu.'));
    expect(allText, contains('Jak se to píše?'));
  });

  test(
    'Unit 1 no longer contains the known inaccurate claims and examples',
    () {
      final allText = lessonPaths
          .map(File.new)
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(allText, isNot(contains('No exceptions')));
      expect(allText, isNot(contains('dum (house vs explosion)')));
      expect(
        allText,
        isNot(contains('All three show how vowel length changes meaning')),
      );
      expect(allText, isNot(contains('Příliš žluťoučký kůň')));
      expect(allText, isNot(contains('Řeka teče pod mostem')));
      expect(allText, isNot(contains('Tři děti jdou do školy')));
    },
  );
}
