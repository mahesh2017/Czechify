import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final lessonPaths = List.generate(
    4,
    (index) => 'assets/curriculum/lessons/unit02_lesson0${index + 1}.json',
  );

  List<Map<String, dynamic>> loadLessons() =>
      lessonPaths
          .map(
            (path) =>
                jsonDecode(File(path).readAsStringSync())
                    as Map<String, dynamic>,
          )
          .toList();

  test('Unit 2 has four short, sequenced lessons and unique exercise IDs', () {
    final lessons = loadLessons();

    expect(lessons.map((lesson) => lesson['order_in_unit']), [0, 1, 2, 3]);
    expect(lessons.map((lesson) => lesson['duration_min']), [12, 12, 12, 12]);

    final exerciseIds = <int>[];
    for (final lesson in lessons) {
      final lessonId = lesson['id'] as int;
      final exercises = lesson['exercises'] as List<dynamic>;
      expect(exercises, hasLength(12));
      for (final raw in exercises) {
        final exercise = raw as Map<String, dynamic>;
        expect(exercise['lesson_id'], lessonId);
        exerciseIds.add(exercise['id'] as int);
      }
    }
    expect(exerciseIds.toSet(), hasLength(exerciseIds.length));
  });

  test(
    'Unit 2 teaches register through context and includes mission evidence',
    () {
      final lessons = loadLessons();
      final exercises =
          lessons
              .expand((lesson) => lesson['exercises'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .toList();
      final types = exercises.map((exercise) => exercise['type'] as String);
      final allText = lessonPaths
          .map(File.new)
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(
        types.where((type) => type == 'listening_comprehension').length,
        8,
      );
      expect(
        types,
        containsAll([
          'reading_comprehension',
          'speaking_task',
          'writing_task',
          'dialogue',
        ]),
      );
      expect(allText, contains('assets/images/unit02/formal_reception_v1.png'));
      expect(allText, contains('assets/images/unit02/informal_cafe_v1.png'));
      expect(allText, contains('Jak se jmenujete?'));
      expect(allText, contains('Jak se jmenuješ?'));
      expect(allText, contains('Odkud jste?'));
      expect(allText, contains('Odkud jsi?'));
      expect(allText, contains('Prosím pomalu.'));

      final mission = exercises.singleWhere(
        (exercise) => exercise['id'] == 2310,
      );
      final missionData = mission['data'] as Map<String, dynamic>;
      expect(missionData['min_duration_seconds'], 20);
      expect(missionData['max_duration_seconds'], 30);
    },
  );

  test('Unit 2 keeps recognition drills below one quarter of activities', () {
    final exercises =
        loadLessons()
            .expand((lesson) => lesson['exercises'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .toList();
    final constrained = exercises.where(
      (exercise) =>
          exercise['type'] == 'multiple_choice' ||
          exercise['type'] == 'translation',
    );

    expect(constrained.length / exercises.length, lessThanOrEqualTo(0.25));
  });

  test('Unit 2 excludes the formerly accepted ungrammatical origin form', () {
    final allText = lessonPaths
        .map(File.new)
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(allText, isNot(contains('Jsem z Praha')));
  });
}
