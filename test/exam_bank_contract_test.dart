import 'dart:convert';
import 'dart:io';

import 'package:czechify/domain/entities/exam_speaking_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every speaking task in all six exam banks has a typed variant', () {
    final tasks = <ExamSpeakingTask>[];
    for (final path in [
      'assets/curriculum/exam_bank_permres_a1.json',
      'assets/curriculum/exam_bank_permres_a2.json',
    ]) {
      final bank = jsonDecode(File(path).readAsStringSync()) as Map;
      for (final exam in bank['exams'] as List) {
        for (final section in (exam as Map)['sections'] as List) {
          if ((section as Map)['type'] != 'speaking') continue;
          for (final question in section['questions'] as List) {
            tasks.add(
              ExamSpeakingTask.fromJson(
                Map<String, dynamic>.from(question as Map),
              ),
            );
          }
        }
      }
    }

    expect(tasks, hasLength(17));
    expect(tasks.whereType<ExamReadAloudTask>(), hasLength(6));
    expect(tasks.whereType<ExamPromptedResponseTask>(), hasLength(5));
    expect(tasks.whereType<ExamOpenResponseTask>(), hasLength(6));
  });

  test('malformed speaking task is rejected before rendering', () {
    expect(
      () => ExamSpeakingTask.fromJson({'prompt': 'Speak', 'points': 5}),
      throwsFormatException,
    );
  });
}
