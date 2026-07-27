import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
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
    final t = context.tokens;
    final data = widget.exercise.data;
    final options = (data['options'] as List<dynamic>).cast<String>();
    final correctIdx = (data['correct_index'] as num).toInt();
    final questionEn = data['question_en'] as String? ?? widget.exercise.prompt;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question
          Text(
            questionEn,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (data['question_cz'] != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    data['question_cz'] as String,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 4),
                TtsButton(text: data['question_cz'] as String, size: 20),
              ],
            ),
          ],
          const SizedBox(height: 32),

          // Options
          ...List.generate(options.length, (i) {
            final isCorrect = i == correctIdx;
            final isSelected = i == selectedIdx;
            Color? cardColor;
            Color? borderColor;
            IconData? icon;

            if (answered && isCorrect) {
              cardColor = correctTint(context);
              borderColor = t.green;
              icon = Icons.check_circle;
            } else if (answered && isSelected && !isCorrect) {
              cardColor = wrongTint(context);
              borderColor = t.red;
              icon = Icons.cancel;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      borderColor != null
                          ? BorderSide(color: borderColor, width: 2)
                          : BorderSide.none,
                ),
                child: ListTile(
                  leading:
                      icon != null
                          ? Icon(icon, color: isCorrect ? t.green : t.red)
                          : Text(
                            String.fromCharCode(65 + i),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                  title: Text(options[i]),
                  onTap:
                      answered
                          ? null
                          : () {
                            setState(() {
                              selectedIdx = i;
                              answered = true;
                            });
                            // Report immediately — the lesson player shows a
                            // feedback banner alongside the highlighted options
                            // and the learner advances at their own pace.
                            widget.onAnswered(
                              ExerciseResult(
                                isCorrect: i == correctIdx,
                                explanation: data['explanation'] as String?,
                                correctAnswer: options[correctIdx],
                              ),
                            );
                          },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
