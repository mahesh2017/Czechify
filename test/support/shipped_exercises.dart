import 'dart:convert';
import 'dart:io';

import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';

/// Every exercise the app actually ships, read straight from the curriculum
/// assets.
///
/// Shared so that any suite rendering the real content — the lesson viewport
/// tests and the small-screen/scaled-text layout tests — measures the same set
/// rather than each keeping its own drifting copy.
List<Exercise> loadShippedExercises() {
  const supportedAssetTypes = {
    'multiple_choice',
    'fill_blank',
    'translation',
    'dictation',
    'pronunciation',
    'dialogue',
    'matching',
    'error_correction',
    'reading_comprehension',
    'listening_comprehension',
    'writing_task',
    'speaking_task',
    'declension_table',
    'word_order',
    'teaching',
  };
  final lessonFiles =
      Directory('assets/curriculum/lessons')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  return [
    for (final file in lessonFiles)
      for (final raw
          in (jsonDecode(file.readAsStringSync())
                  as Map<String, dynamic>)['exercises']
              as List<dynamic>)
        if (supportedAssetTypes.contains((raw as Map)['type']))
          _exerciseFromAsset(Map<String, dynamic>.from(raw)),
  ];
}

Exercise _exerciseFromAsset(Map<String, dynamic> json) {
  return Exercise(
    id: json['id'] as int,
    lessonId: json['lesson_id'] as int,
    type: switch (json['type'] as String) {
      'multiple_choice' => ExerciseType.multipleChoice,
      'fill_blank' => ExerciseType.fillBlank,
      'translation' => ExerciseType.translation,
      'dictation' => ExerciseType.dictation,
      'pronunciation' => ExerciseType.pronunciation,
      'dialogue' => ExerciseType.dialogue,
      'matching' => ExerciseType.matching,
      'error_correction' => ExerciseType.errorCorrection,
      'reading_comprehension' => ExerciseType.readingComprehension,
      'listening_comprehension' => ExerciseType.listeningComprehension,
      'writing_task' => ExerciseType.writingTask,
      'speaking_task' => ExerciseType.speakingTask,
      'declension_table' => ExerciseType.declensionTable,
      'word_order' => ExerciseType.wordOrder,
      'teaching' => ExerciseType.teaching,
      final unsupported =>
        throw FormatException('Unsupported exercise type: $unsupported'),
    },
    prompt: json['prompt'] as String,
    data: Map<String, dynamic>.from(json['data'] as Map),
    answerKey: switch (json['answer_key']) {
      null => null,
      final String value => value,
      final value => jsonEncode(value),
    },
    grammarRuleId: json['grammar_rule_id'] as String?,
    xpReward: json['xp_reward'] as int? ?? 10,
  );
}
