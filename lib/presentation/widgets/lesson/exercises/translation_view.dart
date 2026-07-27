import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import 'exercise_shared.dart';

/// Translation exercise view: type the translation of a source sentence.
class TranslationView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const TranslationView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<TranslationView> createState() => _TranslationViewState();
}

class _TranslationViewState extends State<TranslationView> {
  final _controller = TextEditingController();
  bool answered = false;
  bool? isCorrect;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    final data = widget.exercise.data;
    final accepted = (data['accepted_answers'] as List<dynamic>).cast<String>();
    final match = matchAnswer(accepted, _controller.text);
    // A diacritics-only miss still counts (no heart loss) but nudges the
    // learner about accents.
    final correct = match != AnswerMatch.none;

    setState(() {
      answered = true;
      isCorrect = correct;
    });

    final grammarNote = data['grammar_note'] as String?;
    final explanation =
        match == AnswerMatch.nearMiss
            ? 'Almost! Watch your accent marks — the correct spelling is "${accepted.first}".'
            : grammarNote;

    widget.onAnswered(
      ExerciseResult(
        isCorrect: correct,
        explanation: explanation,
        correctAnswer: accepted.first,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final direction = data['direction'] as String? ?? 'en_to_cz';
    final source = data['source'] as String;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Direction label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              direction == 'en_to_cz' ? 'EN → CZ' : 'CZ → EN',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Source text
          Text(
            source,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Input field
          TextField(
            controller: _controller,
            enabled: !answered,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText:
                  direction == 'en_to_cz' ? 'Type in Czech' : 'Type in English',
              suffixIcon:
                  isCorrect == true
                      ? Icon(Icons.check_circle, color: context.tokens.green)
                      : isCorrect == false
                      ? Icon(Icons.cancel, color: context.tokens.red)
                      : null,
            ),
            onSubmitted: answered ? null : (_) => _checkAnswer(),
          ),

          // Czech character helper — only when typing Czech.
          if (direction == 'en_to_cz' && !answered) ...[
            const SizedBox(height: 8),
            CzechCharBar(controller: _controller, enabled: !answered),
          ],
          const SizedBox(height: 16),

          // Submit button
          if (!answered)
            FilledButton(onPressed: _checkAnswer, child: const Text('Check')),

          // The lesson player's feedback banner shows the correct answer.
        ],
      ),
    );
  }
}
