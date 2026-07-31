import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../providers/tts_providers.dart';
import '../../common/lesson_ui.dart';
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
            ? AppLocalizations.of(context).dictationAccentHint
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
    final l10n = AppLocalizations.of(context);
    final expected = data['expected_text'] as String;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: widget.exercise.prompt),
          const SizedBox(height: 18),

          ListenPanel(
            onPlay: () => ref.read(czechTtsProvider).speak(expected),
            onSlow: () => ref.read(czechTtsProvider).speakSlow(expected),
          ),
          const SizedBox(height: 14),

          AnswerField(
            controller: _controller,
            enabled: !answered,
            verdict: isCorrect,
            semanticLabel: l10n.exerciseTypeWhatYouHeard,
            onSubmitted: answered ? null : (_) => _checkAnswer(),
          ),
          if (!answered) ...[
            const SizedBox(height: 12),
            CzechCharBar(controller: _controller, enabled: !answered),
            const SizedBox(height: 18),
            KeyCta(label: l10n.check, onPressed: _checkAnswer),
          ],
        ],
      ),
    );
  }
}
