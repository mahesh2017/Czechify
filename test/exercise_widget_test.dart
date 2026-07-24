import 'package:ceskina_pro/domain/entities/enums.dart';
import 'package:ceskina_pro/domain/entities/exercise.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercise_widget.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/declension_table_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/dialogue_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/dictation_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/error_correction_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/fill_blank_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/listening_comprehension_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/matching_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/multiple_choice_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/pronunciation_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/reading_comprehension_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/speaking_task_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/teaching_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/translation_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/word_order_view.dart';
import 'package:ceskina_pro/presentation/widgets/lesson/exercises/writing_task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <ExerciseType, Type>{
    ExerciseType.multipleChoice: MultipleChoiceView,
    ExerciseType.translation: TranslationView,
    ExerciseType.fillBlank: FillBlankView,
    ExerciseType.wordOrder: WordOrderView,
    ExerciseType.dictation: DictationView,
    ExerciseType.pronunciation: PronunciationView,
    ExerciseType.dialogue: DialogueView,
    ExerciseType.declensionTable: DeclensionTableView,
    ExerciseType.aspectRecognition: MultipleChoiceView,
    ExerciseType.prepositionCase: MultipleChoiceView,
    ExerciseType.listening: DictationView,
    ExerciseType.matching: MatchingView,
    ExerciseType.errorCorrection: ErrorCorrectionView,
    ExerciseType.readingComprehension: ReadingComprehensionView,
    ExerciseType.listeningComprehension: ListeningComprehensionView,
    ExerciseType.writingTask: WritingTaskView,
    ExerciseType.speakingTask: SpeakingTaskView,
    ExerciseType.teaching: TeachingView,
  };

  for (final entry in cases.entries) {
    testWidgets('dispatches ${entry.key.name} to its extracted view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExerciseWidget(
                exercise: Exercise(
                  id: 1,
                  lessonId: 1,
                  type: entry.key,
                  prompt: 'Prompt',
                  data: _dataFor(entry.key),
                ),
                onAnswered: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Map<String, dynamic> _dataFor(ExerciseType type) => switch (type) {
  ExerciseType.multipleChoice ||
  ExerciseType.aspectRecognition ||
  ExerciseType.prepositionCase => {
    'options': ['ano', 'ne'],
    'correct_index': 0,
  },
  ExerciseType.translation => {
    'accepted_answers': ['ahoj'],
    'source': 'hello',
  },
  ExerciseType.fillBlank => {
    'accepted_answers': ['jsem'],
    'sentence': 'Já ___ student.',
  },
  ExerciseType.wordOrder => {
    'words': ['Já', 'jsem', 'student'],
    'correct_order': [0, 1, 2],
  },
  ExerciseType.dictation ||
  ExerciseType.listening => {'expected_text': 'Dobrý den'},
  ExerciseType.pronunciation => {
    'target_text': 'Dobrý den',
    'focus_sounds': <String>[],
  },
  ExerciseType.dialogue => {
    'accepted_answers': ['Dobrý den'],
    'lines': <Map<String, dynamic>>[
      {'speaker': 'tutor', 'text': 'Dobrý den'},
    ],
  },
  ExerciseType.declensionTable => {
    'word': 'žena',
    'cases': ['nominative'],
    'answer_key': <String, dynamic>{'nominative': 'žena'},
  },
  ExerciseType.matching => {
    'pairs': [
      {'left': 'ahoj', 'right': 'hello'},
      {'left': 'nazdar', 'right': 'hi'},
    ],
  },
  ExerciseType.errorCorrection => {
    'sentence_cz': 'Ty musí jít domů.',
    'correct_sentence_cz': 'Ty musíš jít domů.',
  },
  ExerciseType.readingComprehension ||
  ExerciseType.listeningComprehension => {
    'text_cz': 'Dnes je hezky.',
    'questions': [
      {
        'question_en': 'How is the weather?',
        'options': ['Nice', 'Bad'],
        'correct_index': 0,
      },
    ],
  },
  ExerciseType.writingTask => {
    'prompt_en': 'Write a short greeting.',
    'min_words': 2,
  },
  ExerciseType.speakingTask => {
    'prompt_en': 'Introduce yourself.',
    'expected_phrases': ['Ahoj'],
  },
  ExerciseType.teaching => {
    'heading': 'The Czech Alphabet',
    'items': [
      {'symbol': 'a', 'sound': 'like u in cup', 'example': 'matka'},
    ],
  },
};
