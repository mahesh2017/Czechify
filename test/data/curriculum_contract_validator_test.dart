import 'dart:convert';
import 'dart:io';

import 'package:ceskina_pro/data/content/curriculum_contract_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all shipped lessons satisfy normalized executable contracts', () {
    final packs = <String, Object?>{
      for (final file in Directory('assets/curriculum/lessons')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json')))
        file.path: jsonDecode(file.readAsStringSync()),
    };

    final issues = CurriculumContractValidator.collectSnapshotIssues(packs);

    expect(issues, isEmpty, reason: issues.join('\n'));
  });

  test('reports actionable paths for unsafe word-order indices', () {
    final issues = CurriculumContractValidator.collectSnapshotIssues({
      'assets/curriculum/lessons/test.json': _lessonWithExercise({
        'id': 101,
        'lesson_id': 1,
        'type': 'word_order',
        'prompt': 'Arrange the words',
        'data': {
          'type': 'word_order',
          'words': ['Mám', 'hlad'],
          'correct_order': [0, -1, 3],
        },
      }),
    });

    expect(issues, hasLength(1));
    expect(issues.single.exerciseId, 101);
    expect(issues.single.path, r'$.exercises[0].data.correct_order');
    expect(issues.single.message, contains('-1, 3'));
  });

  test(
    'rejects the former declension-table asset shape before installation',
    () {
      final issues = CurriculumContractValidator.collectSnapshotIssues({
        'assets/curriculum/lessons/test.json': _lessonWithExercise({
          'id': 102,
          'lesson_id': 1,
          'type': 'declension_table',
          'prompt': 'Decline žena',
          'data': {
            'type': 'declension_table',
            'noun': 'žena',
            'nominative': 'žena',
            'accusative': 'ženu',
          },
        }),
      });

      expect(
        issues.map((issue) => issue.path),
        containsAll({
          r'$.exercises[0].data.word',
          r'$.exercises[0].data.cases',
          r'$.exercises[0].data.answer_key',
        }),
      );
    },
  );

  test('throws a bounded summary before an invalid snapshot is exposed', () {
    final packs = {
      'assets/curriculum/lessons/test.json': _lessonWithExercise({
        'id': 103,
        'lesson_id': 999,
        'type': 'word_order',
        'prompt': '',
        'data': {
          'type': 'word_order',
          'words': ['—'],
          'correct_order': [0],
        },
      }),
    };

    expect(
      () => CurriculumContractValidator.validateSnapshot(packs),
      throwsA(
        isA<CurriculumContractException>().having(
          (error) => error.toString(),
          'summary',
          allOf(contains('exercise 103'), contains(r'$.exercises[0].prompt')),
        ),
      ),
    );
  });

  test('rejects ambiguous legacy dialogue answers with actionable paths', () {
    final issues = CurriculumContractValidator.collectSnapshotIssues({
      'assets/curriculum/lessons/test.json': _lessonWithExercise({
        'id': 104,
        'lesson_id': 1,
        'type': 'dialogue',
        'prompt': 'Complete the dialogue',
        'data': {
          'type': 'dialogue',
          'accepted_answers': ['Dobrý den|Ahoj'],
          'lines': [
            {'speaker': 'you', 'text_cz': '____'},
          ],
        },
      }),
    });

    expect(
      issues.map((issue) => issue.path),
      containsAll({
        r'$.exercises[0].data.accepted_answers',
        r'$.exercises[0].data.lines[0]',
        r'$.exercises[0].data.lines[0].text',
        r'$.exercises[0].data.lines',
        r'$.exercises[0].data.blank_answers',
      }),
    );
  });

  test('rejects unsafe option, blank, and comprehension contracts', () {
    final lesson = _lessonWithExercise({
      'id': 105,
      'lesson_id': 1,
      'type': 'multiple_choice',
      'prompt': 'Choose',
      'data': {
        'type': 'multiple_choice',
        'options': ['Only option'],
        'correct_index': 4,
      },
    });
    (lesson['exercises'] as List<Map<String, Object?>>).addAll([
      {
        'id': 106,
        'lesson_id': 1,
        'type': 'fill_blank',
        'prompt': 'Complete',
        'data': {
          'type': 'fill_blank',
          'sentence': '___ a ___',
          'blank_count': 2,
          'accepted_answers': ['legacy|shape'],
        },
      },
      {
        'id': 107,
        'lesson_id': 1,
        'type': 'reading_comprehension',
        'prompt': 'Read',
        'data': {
          'type': 'reading_comprehension',
          'text_cz': 'Text',
          'questions': [
            {
              'question_en': 'Question?',
              'options': ['A'],
              'correct_index': -1,
            },
          ],
        },
      },
    ]);

    final issues = CurriculumContractValidator.collectSnapshotIssues({
      'assets/curriculum/lessons/test.json': lesson,
    });

    expect(
      issues.map((issue) => issue.path),
      containsAll({
        r'$.exercises[0].data.correct_index',
        r'$.exercises[1].data.accepted_answers',
        r'$.exercises[1].data.blank_answers',
        r'$.exercises[2].data.questions[0].correct_index',
      }),
    );
  });

  test('rejects a speaking task with no Czech to score against', () {
    final issues = CurriculumContractValidator.collectSnapshotIssues({
      'assets/curriculum/lessons/test.json': _lessonWithExercise({
        'id': 106,
        'lesson_id': 1,
        'type': 'speaking_task',
        'prompt': 'Speak',
        // The exact shape that shipped in unit29_lesson02: real prompts, a
        // real duration, and an English answer_key that the view fell back to
        // and scored Czech speech against.
        'answer_key': 'Full spoken role-play at a government office.',
        'data': {
          'type': 'speaking_task',
          'prompt_cz': 'Mluvte o svem vikendu',
          'prompt_en': 'Talk about your weekend',
          'min_duration_seconds': 90,
        },
      }),
    });

    expect(issues, hasLength(1));
    expect(issues.single.exerciseId, 106);
    expect(issues.single.path, r'$.exercises[0].data.expected_phrases');
  });
}

Map<String, Object?> _lessonWithExercise(Map<String, Object?> exercise) => {
  'id': 1,
  'unit_id': 1,
  'title': 'Test lesson',
  'description': 'Test',
  'order_in_unit': 1,
  'exercises': [exercise],
};
