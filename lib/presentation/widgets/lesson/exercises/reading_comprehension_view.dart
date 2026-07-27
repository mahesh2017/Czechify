import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import 'exercise_shared.dart';

/// Reading comprehension exercise — read a Czech passage, then answer
/// multiple-choice questions about it.
class ReadingComprehensionView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const ReadingComprehensionView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<ReadingComprehensionView> createState() =>
      _ReadingComprehensionViewState();
}

class _ReadingComprehensionViewState extends State<ReadingComprehensionView> {
  final List<int?> _selectedAnswers = [];
  bool answered = false;

  @override
  void initState() {
    super.initState();
    final questions = widget.exercise.data['questions'] as List<dynamic>? ?? [];
    _selectedAnswers.addAll(List.filled(questions.length, null));
  }

  List<Map<String, dynamic>> get _questions {
    final raw = widget.exercise.data['questions'] as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  bool get _allAnswered => _selectedAnswers.every((a) => a != null);

  bool get _allCorrect {
    for (int i = 0; i < _questions.length; i++) {
      final correctIdx = (_questions[i]['correct_index'] as num).toInt();
      if (_selectedAnswers[i] != correctIdx) return false;
    }
    return true;
  }

  void _submit() {
    setState(() => answered = true);

    // Determine correctness per-question to avoid indexOf miscounting
    // when multiple questions share the same selected answer index.
    final List<bool> perQuestionCorrect = [];
    for (int i = 0; i < _questions.length; i++) {
      final correctIdx = (_questions[i]['correct_index'] as num).toInt();
      perQuestionCorrect.add(_selectedAnswers[i] == correctIdx);
    }
    final allCorrect = perQuestionCorrect.every((c) => c);
    final correctCount = perQuestionCorrect.where((c) => c).length;

    widget.onAnswered(
      ExerciseResult(
        isCorrect: allCorrect,
        explanation:
            allCorrect
                ? 'All questions answered correctly!'
                : '$correctCount/${_questions.length} correct.',
        correctAnswer: _questions
            .map(
              (q) =>
                  (q['options'] as List<dynamic>)[(q['correct_index'] as num)
                          .toInt()]
                      as String,
            )
            .join(', '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final data = widget.exercise.data;
    final textCz = data['text_cz'] as String? ?? '';
    final textEn = data['text_en'] as String?;
    final promptEn = data['prompt_en'] as String?;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prompt
          Text(
            promptEn ?? widget.exercise.prompt,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Reading passage
          Expanded(
            child: ListView(
              children: [
                // Passage in Czech
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        textCz,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                      if (textEn != null && textEn.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          textEn,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Questions
                for (int qIdx = 0; qIdx < _questions.length; qIdx++) ...[
                  _buildQuestion(qIdx, theme),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          // Submit
          if (_allAnswered && !answered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Check Answers'),
              ),
            ),

          // Feedback after answer
          if (answered)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    _allCorrect ? Icons.check_circle : Icons.error_outline,
                    color: _allCorrect ? t.green : t.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _allCorrect
                          ? 'All correct!'
                          : 'Some answers are wrong — review below.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _allCorrect ? t.green : t.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestion(int qIdx, ThemeData theme) {
    final t = context.tokens;
    final q = _questions[qIdx];
    final questionEn = q['question_en'] as String? ?? '';
    final questionCz = q['question_cz'] as String? ?? '';
    final options = (q['options'] as List<dynamic>).cast<String>();
    final correctIdx = (q['correct_index'] as num).toInt();
    final selected = _selectedAnswers[qIdx];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${qIdx + 1}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            questionEn,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (questionCz.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              questionCz,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (int i = 0; i < options.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildOption(
                option: options[i],
                index: i,
                isSelected: selected == i,
                isCorrect: answered && i == correctIdx,
                isWrong: answered && selected == i && i != correctIdx,
                onTap:
                    answered
                        ? null
                        : () {
                          setState(() {
                            _selectedAnswers[qIdx] = i;
                          });
                        },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOption({
    required String option,
    required int index,
    required bool isSelected,
    required bool isCorrect,
    required bool isWrong,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final t = context.tokens;

    Color? bg;
    Color? border;
    Widget? trailing;

    if (answered) {
      if (isCorrect) {
        bg = t.greenSoft;
        border = t.green;
        trailing = Icon(Icons.check_circle, color: t.green, size: 20);
      } else if (isWrong) {
        bg = t.redSoft;
        border = t.red;
        trailing = Icon(Icons.cancel, color: t.red, size: 20);
      }
    } else if (isSelected) {
      bg = theme.colorScheme.primaryContainer;
      border = theme.colorScheme.primary;
    } else {
      border = t.line;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg ?? t.elev,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: border ?? t.line,
            width: (isSelected || answered) ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      isSelected || (answered && isCorrect)
                          ? FontWeight.w600
                          : FontWeight.normal,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
