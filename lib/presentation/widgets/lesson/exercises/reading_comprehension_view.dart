import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../common/lesson_ui.dart';
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
    final data = widget.exercise.data;
    final textCz = data['text_cz'] as String? ?? '';
    final textEn = data['text_en'] as String?;
    final promptEn = data['prompt_en'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: promptEn ?? widget.exercise.prompt),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              children: [
                // The passage. Reading length, so it gets the generous line
                // height and the calmest surface on the screen.
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: t.line),
                    boxShadow: t.shadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        textCz,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.6,
                          color: t.ink,
                        ),
                      ),
                      if (textEn != null && textEn.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Divider(color: t.line, height: 1),
                        const SizedBox(height: 14),
                        Text(
                          textEn,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: t.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                for (int qIdx = 0; qIdx < _questions.length; qIdx++) ...[
                  _buildQuestion(qIdx),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          if (_allAnswered && !answered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: KeyCta(label: 'Check answers', onPressed: _submit),
            ),

          if (answered)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    _allCorrect ? Icons.check_circle : Icons.error_outline,
                    color: _allCorrect ? t.greenInk : t.redInk,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _allCorrect
                          ? 'All correct'
                          : 'Some answers are wrong — review below.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _allCorrect ? t.greenInk : t.redInk,
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

  Widget _buildQuestion(int qIdx) {
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
        color: t.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.line),
        boxShadow: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LessonKicker('Question ${qIdx + 1}', color: t.pri),
          const SizedBox(height: 6),
          Text(
            questionEn,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: t.ink,
            ),
          ),
          if (questionCz.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              questionCz,
              style: TextStyle(fontSize: 14, height: 1.35, color: t.muted),
            ),
          ],
          const SizedBox(height: 12),
          for (int i = 0; i < options.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == options.length - 1 ? 0 : 8),
              child: QuizOptionTile(
                keyLabel: String.fromCharCode(65 + i),
                text: options[i],
                state: optionState(
                  index: i,
                  correctIndex: correctIdx,
                  selectedIndex: selected,
                  answered: answered,
                ),
                onTap:
                    answered
                        ? null
                        : () => setState(() => _selectedAnswers[qIdx] = i),
              ),
            ),
        ],
      ),
    );
  }
}
