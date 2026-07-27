import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../providers/tts_providers.dart';
import 'exercise_shared.dart';

/// Dictation exercise view: listen and type. Also used for the listening
/// exercise type.
class DictationView extends ConsumerStatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const DictationView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  ConsumerState<DictationView> createState() => _DictationViewState();
}

class _DictationViewState extends ConsumerState<DictationView> {
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
    final expected = data['expected_text'] as String;
    final match = matchAnswer([expected], _controller.text);
    final correct = match != AnswerMatch.none;

    setState(() {
      answered = true;
      isCorrect = correct;
    });

    final explanation =
        match == AnswerMatch.nearMiss
            ? 'Almost! Watch your accent marks — you wrote it correctly apart from the diacritics.'
            : data['note'] as String?;

    widget.onAnswered(
      ExerciseResult(
        isCorrect: correct,
        explanation: explanation,
        correctAnswer: expected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.exercise.prompt,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Audio play button — speaks the Czech text via TTS
          TtsButton(text: data['expected_text'] as String, size: 48),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  ref
                      .read(czechTtsProvider)
                      .speak(data['expected_text'] as String);
                },
                icon: const Icon(Icons.replay),
                label: const Text('Play again'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  ref
                      .read(czechTtsProvider)
                      .speakSlow(data['expected_text'] as String);
                },
                icon: const Icon(Icons.slow_motion_video),
                label: const Text('Slower'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Input field
          TextField(
            controller: _controller,
            enabled: !answered,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Type what you heard',
              suffixIcon:
                  isCorrect == true
                      ? Icon(Icons.check_circle, color: context.tokens.green)
                      : isCorrect == false
                      ? Icon(Icons.cancel, color: context.tokens.red)
                      : null,
            ),
            onSubmitted: answered ? null : (_) => _checkAnswer(),
          ),
          if (!answered) ...[
            const SizedBox(height: 8),
            CzechCharBar(controller: _controller, enabled: !answered),
          ],
          const SizedBox(height: 16),

          if (!answered)
            FilledButton(onPressed: _checkAnswer, child: const Text('Check')),
        ],
      ),
    );
  }
}
