import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../domain/entities/exercise.dart';
import 'exercise_shared.dart';

/// Dialogue completion exercise view.
class DialogueView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const DialogueView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<DialogueView> createState() => _DialogueViewState();
}

class _DialogueViewState extends State<DialogueView> {
  final List<TextEditingController> _controllers = [];
  bool answered = false;
  bool? isCorrect;

  List<Map<String, dynamic>> get _lines =>
      (widget.exercise.data['lines'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

  List<List<String>> get _blankAnswers =>
      (widget.exercise.data['blank_answers'] as List<dynamic>)
          .map((answers) => (answers as List<dynamic>).cast<String>())
          .toList();

  @override
  void initState() {
    super.initState();
    final blankCount = _lines.fold<int>(
      0,
      (count, line) => count + '___'.allMatches(line['text'] as String).length,
    );
    _controllers.addAll(
      List.generate(blankCount, (_) => TextEditingController()),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _allFilled =>
      _controllers.isNotEmpty &&
      _controllers.every((controller) => controller.text.trim().isNotEmpty);

  /// Build dialogue lines with an inline field for every `___` marker.
  List<Widget> _buildDialogueLines(
    List<Map<String, dynamic>> lines,
    BuildContext context,
  ) {
    int blankCounter = 0;
    return lines.map((line) {
      final text = line['text'] as String;
      final segments = text.split('___');
      final containsBlank = segments.length > 1;
      final isUser = line['speaker'] == 'you' || containsBlank;
      final inline = <Widget>[];
      for (var index = 0; index < segments.length; index++) {
        if (segments[index].isNotEmpty) {
          inline.add(Text(segments[index]));
        }
        if (index < segments.length - 1) {
          final controller = _controllers[blankCounter++];
          inline.add(
            SizedBox(
              width: 180,
              child: TextField(
                controller: controller,
                enabled: !answered,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'Your answer',
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                onSubmitted:
                    answered
                        ? null
                        : (_) {
                          if (_allFilled) _checkAnswer();
                        },
              ),
            ),
          );
        }
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line['speaker'] as String,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: inline,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _checkAnswer() {
    if (!_allFilled || answered) return;
    final answers = _blankAnswers;
    final correct =
        answers.length == _controllers.length &&
        List.generate(_controllers.length, (index) {
          final userAnswer = normalizeAnswer(_controllers[index].text);
          return answers[index].map(normalizeAnswer).contains(userAnswer);
        }).every((matches) => matches);

    setState(() {
      answered = true;
      isCorrect = correct;
    });

    widget.onAnswered(
      ExerciseResult(
        isCorrect: correct,
        explanation: widget.exercise.data['explanation'] as String?,
        correctAnswer: answers.map((options) => options.first).join(' | '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final scenario = data['scenario'] as String?;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scenario != null)
            Text(
              'Scenario: $scenario',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 16),

          // Dialogue lines
          ..._buildDialogueLines(_lines, context),

          const SizedBox(height: 16),
          if (!answered)
            FilledButton(
              onPressed: _allFilled ? _checkAnswer : null,
              child: Text(AppLocalizations.of(context).check),
            ),
        ],
      ),
    );
  }
}
