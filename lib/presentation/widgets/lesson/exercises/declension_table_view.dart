import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import 'exercise_shared.dart';

/// Declension-table exercise view (Czech-specific).
class DeclensionTableView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const DeclensionTableView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<DeclensionTableView> createState() => _DeclensionTableViewState();
}

class _DeclensionTableViewState extends State<DeclensionTableView> {
  final Map<String, TextEditingController> _controllers = {};
  bool answered = false;
  int correctCount = 0;
  int totalBlanks = 0;

  @override
  void initState() {
    super.initState();
    final data = widget.exercise.data;
    final cases = (data['cases'] as List<dynamic>).cast<String>();
    totalBlanks = cases.length;
    for (final caseName in cases) {
      _controllers[caseName] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _checkAnswers() {
    final data = widget.exercise.data;
    final answerKey = Map<String, String>.from(
      data['answer_key'] as Map<String, dynamic>,
    );

    correctCount = 0;
    for (final entry in _controllers.entries) {
      final caseName = entry.key;
      final userAnswer = normalizeAnswer(entry.value.text);
      final correctAnswer = normalizeAnswer(answerKey[caseName] ?? '');
      if (userAnswer == correctAnswer) {
        correctCount++;
      }
    }

    setState(() {
      answered = true;
    });

    widget.onAnswered(
      ExerciseResult(
        isCorrect: correctCount == totalBlanks,
        explanation: 'You got $correctCount/$totalBlanks correct.',
        correctAnswer: answerKey.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final word = data['word'] as String;
    final gender = data['gender'] as String?;
    final cases = (data['cases'] as List<dynamic>).cast<String>();
    final answerKey =
        answered
            ? Map<String, String>.from(
              data['answer_key'] as Map<String, dynamic>,
            )
            : null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Decline: $word',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (gender != null)
            Text(
              'Gender: $gender',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),

          // Table
          Table(
            border: TableBorder.all(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(8),
            ),
            children: [
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Case',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Form',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              ...cases.map((caseName) {
                final controller = _controllers[caseName]!;
                final correct = answerKey?[caseName];
                final userAnswer = normalizeAnswer(controller.text);
                final isCorrect =
                    correct != null && userAnswer == normalizeAnswer(correct);

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(caseName),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: TextField(
                        controller: controller,
                        enabled: !answered,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon:
                              answered
                                  ? Icon(
                                    isCorrect ? Icons.check : Icons.close,
                                    color:
                                        isCorrect
                                            ? context.tokens.green
                                            : context.tokens.red,
                                  )
                                  : null,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          if (!answered)
            FilledButton(
              onPressed: _checkAnswers,
              child: const Text('Check All'),
            ),
        ],
      ),
    );
  }
}
