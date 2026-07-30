import 'package:flutter/material.dart';
import '../../../../domain/entities/exercise.dart';
import '../../common/lesson_ui.dart';
import 'exercise_shared.dart';

/// Multiple-choice exercise view. Also used for aspectRecognition and
/// prepositionCase exercise types.
class MultipleChoiceView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const MultipleChoiceView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<MultipleChoiceView> createState() => _MultipleChoiceViewState();
}

class _MultipleChoiceViewState extends State<MultipleChoiceView> {
  int? selectedIdx;
  bool answered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final options = (data['options'] as List<dynamic>).cast<String>();
    final correctIdx = (data['correct_index'] as num).toInt();
    final questionEn = data['question_en'] as String? ?? widget.exercise.prompt;
    final wrong = answered && selectedIdx != correctIdx;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(
            question: questionEn,
            czech: data['question_cz'] as String?,
          ),
          const SizedBox(height: 22),

          // Shakes once as a whole when the answer was wrong; under reduced
          // motion the group flashes a coral outline instead.
          ShakeOnce(
            trigger: wrong ? selectedIdx : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0) const SizedBox(height: 11),
                  QuizOptionTile(
                    keyLabel: String.fromCharCode(65 + i),
                    text: options[i],
                    state: optionState(
                      index: i,
                      correctIndex: correctIdx,
                      selectedIndex: selectedIdx,
                      answered: answered,
                    ),
                    onTap:
                        answered
                            ? null
                            : () {
                              setState(() {
                                selectedIdx = i;
                                answered = true;
                              });
                              // Report immediately — the lesson player shows a
                              // feedback sheet alongside the highlighted
                              // options and the learner advances at their own
                              // pace.
                              widget.onAnswered(
                                ExerciseResult(
                                  isCorrect: i == correctIdx,
                                  explanation: data['explanation'] as String?,
                                  correctAnswer: options[correctIdx],
                                ),
                              );
                            },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
