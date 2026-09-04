import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final lessonPaths = List.generate(
    4,
    (index) => 'assets/curriculum/lessons/unit03_lesson0${index + 1}.json',
  );

  List<Map<String, dynamic>> loadLessons() =>
      lessonPaths
          .map(
            (path) =>
                jsonDecode(File(path).readAsStringSync())
                    as Map<String, dynamic>,
          )
          .toList();

  test('Unit 3 has four short, sequenced lessons and unique exercise IDs', () {
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

  test('Unit 3 balances twelve reusable noun cards across three genders', () {
    final teachings =
        loadLessons()
            .expand((lesson) => lesson['exercises'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .where(
              (exercise) =>
                  exercise['type'] == 'teaching' &&
                  (exercise['data'] as Map<String, dynamic>)['style'] ==
                      'image_cards',
            )
            .toList();

    expect(teachings, hasLength(2));
    final cards =
        teachings
            .expand(
              (exercise) =>
                  ((exercise['data'] as Map<String, dynamic>)['items']
                          as List<dynamic>)
                      .cast<Map<String, dynamic>>(),
            )
            .toList();
    expect(cards, hasLength(12));
    expect(
      cards.map((card) => card['cz']),
      containsAll([
        'muž',
        'žena',
        'dítě',
        'pes',
        'dům',
        'auto',
        'ten stůl',
        'ta kniha',
        'ta káva',
        'ta židle',
        'to okno',
        'to město',
      ]),
    );
    for (final card in cards) {
      expect(File(card['image'] as String).existsSync(), isTrue);
      expect((card['image_label'] as String).trim(), isNotEmpty);
    }

    const masculine = {'muž', 'pes', 'dům', 'stůl'};
    const feminine = {'žena', 'káva', 'kniha', 'židle'};
    const neuter = {'dítě', 'auto', 'okno', 'město'};
    expect(masculine, hasLength(4));
    expect(feminine, hasLength(4));
    expect(neuter, hasLength(4));
  });

  test(
    'Unit 3 teaches kdo/co through listening and requires mission evidence',
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
      expect(allText, contains('Kdo je to?'));
      expect(allText, contains('Co je to?'));
      expect(allText, contains('To je'));
      expect(allText, contains('ten stůl'));
      expect(allText, contains('ta židle'));
      expect(allText, contains('to dítě'));
      expect(allText, isNot(contains('~90%')));
      expect(allText.toLowerCase(), isNot(contains('accusative')));

      final visualMission = exercises.singleWhere(
        (exercise) => exercise['id'] == 3301,
      );
      final visualData = visualMission['data'] as Map<String, dynamic>;
      expect(
        visualData['image'],
        'assets/images/unit03/identification_scene_v1.webp',
      );
      expect((visualData['questions'] as List<dynamic>), hasLength(6));

      final speakingMission = exercises.singleWhere(
        (exercise) => exercise['id'] == 3310,
      );
      final speakingData = speakingMission['data'] as Map<String, dynamic>;
      expect(speakingData['min_duration_seconds'], 20);
      expect(speakingData['max_duration_seconds'], 35);
    },
  );

  test('Unit 3 keeps recognition drills below one quarter of activities', () {
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
}
