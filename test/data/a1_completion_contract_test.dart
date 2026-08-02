import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const a1UnitIds = <int>[
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    28,
    30,
  ];

  test(
    'every A1 lesson declares an outcome, language, recycling and exit task',
    () {
      for (final unit in a1UnitIds) {
        final paths = _lessonPaths(unit);
        expect(paths, isNotEmpty, reason: 'Unit $unit has no lessons');
        for (final path in paths) {
          final lesson = _read(path);
          expect(
            (lesson['can_do'] as String?)?.trim(),
            isNotEmpty,
            reason: '$path has no can_do',
          );
          expect(
            lesson['new_language'] as List?,
            isNotEmpty,
            reason: '$path has no new_language',
          );
          expect(
            lesson['recycles'] as List?,
            isNotEmpty,
            reason: '$path has no recycles',
          );
          expect(
            (lesson['exit_task'] as String?)?.trim(),
            isNotEmpty,
            reason: '$path has no exit_task',
          );
        }
      }
    },
  );

  test('every image referenced by an A1 lesson is bundled', () {
    for (final unit in a1UnitIds) {
      for (final path in _lessonPaths(unit)) {
        final lesson = _read(path);
        for (final raw in lesson['exercises'] as List<dynamic>) {
          final exercise = raw as Map<String, dynamic>;
          final data = exercise['data'] as Map<String, dynamic>;
          for (final key in const ['image', 'image_path']) {
            final image = data[key] as String?;
            if (image == null || image.isEmpty) continue;
            expect(
              File(image).existsSync(),
              isTrue,
              reason: '$path references missing $image',
            );
          }
        }
      }
    }
  });

  test('A1 independent practice makes no official-exam fidelity claim', () {
    final unit28 = File('assets/curriculum/a1_units.json').readAsStringSync();
    final practiceBank = File(
      'assets/curriculum/exam_bank_permres_a1.json',
    ).readAsStringSync();
    final combined = '$unit28\n$practiceBank';

    expect(combined, contains('not official examination material'));
    expect(combined, isNot(contains('Practice Exam')));
    expect(combined, isNot(contains('vodík dopis')));
    expect(combined, isNot(contains('V líté horko')));
    expect(combined, isNot(contains('odejde třicet')));
  });
}

List<String> _lessonPaths(int unit) {
  final number = unit.toString().padLeft(2, '0');
  return Directory('assets/curriculum/lessons')
      .listSync()
      .whereType<File>()
      .map((file) => file.path)
      .where((path) => path.contains('unit${number}_lesson'))
      .toList()
    ..sort();
}

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
