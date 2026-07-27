import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../domain/entities/exercise.dart';
import 'exercise_shared.dart';

/// Word-order exercise view: tap words to build the sentence.
class WordOrderView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const WordOrderView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<WordOrderView> createState() => _WordOrderViewState();
}

class _WordOrderViewState extends State<WordOrderView> {
  List<String> available = [];
  List<String> selected = [];
  bool answered = false;
  bool? isCorrect;

  /// The Czech words to arrange. Content packs older than the format
  /// cleanup appended English words after a '—' separator; tolerate both.
  List<String> _czechWords() {
    final allWords =
        (widget.exercise.data['words'] as List<dynamic>).cast<String>();
    final sepIdx = allWords.indexOf('—');
    return sepIdx >= 0 ? allWords.sublist(0, sepIdx) : allWords;
  }

  @override
  void initState() {
    super.initState();
    available = List.of(_czechWords())..shuffle();
  }

  void _checkAnswer() {
    final data = widget.exercise.data;
    final correctOrder = (data['correct_order'] as List<dynamic>).cast<int>();
    final czechWords = _czechWords();

    // Compare by position, not by indexOf (which breaks on duplicate words).
    final correct =
        selected.length == correctOrder.length &&
        _checkOrder(selected, czechWords, correctOrder);

    setState(() {
      answered = true;
      isCorrect = correct;
    });

    final correctSentence = correctOrder.map((i) => czechWords[i]).join(' ');
    widget.onAnswered(
      ExerciseResult(
        isCorrect: correct,
        explanation: data['explanation'] as String?,
        correctAnswer: correctSentence,
      ),
    );
  }

  /// Check that the selected words match the correct order indices.
  /// Handles duplicate words correctly by comparing the word at each
  /// correct_order index to the user's selection at that position.
  bool _checkOrder(
    List<String> selected,
    List<String> czechWords,
    List<int> correctOrder,
  ) {
    if (selected.length != correctOrder.length) return false;
    for (var i = 0; i < correctOrder.length; i++) {
      final expectedWord = czechWords[correctOrder[i]];
      if (selected[i] != expectedWord) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final translationEn = widget.exercise.data['translation_en'] as String?;

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
          if (translationEn != null) ...[
            const SizedBox(height: 8),
            Text(
              '"$translationEn"',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),

          // Selected words area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(minHeight: 60),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  selected.asMap().entries.map((entry) {
                    return WordChip(
                      word: entry.value,
                      onTap:
                          answered
                              ? null
                              : () {
                                setState(() {
                                  available.add(selected.removeAt(entry.key));
                                });
                              },
                      color:
                          answered
                              ? (isCorrect == true
                                  ? correctTint(context)
                                  : wrongTint(context))
                              : null,
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Available words
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                available.asMap().entries.map((entry) {
                  return WordChip(
                    word: entry.value,
                    onTap:
                        answered
                            ? null
                            : () {
                              setState(() {
                                selected.add(available.removeAt(entry.key));
                              });
                            },
                  );
                }).toList(),
          ),
          // No Spacer here: this widget renders inside a scroll view, where
          // flex children have unbounded height and would throw.
          const SizedBox(height: 24),
          if (!answered && selected.isNotEmpty)
            FilledButton(
              onPressed: _checkAnswer,
              child: Text(AppLocalizations.of(context).check),
            ),
        ],
      ),
    );
  }
}

class WordChip extends StatelessWidget {
  final String word;
  final VoidCallback? onTap;
  final Color? color;

  const WordChip({super.key, required this.word, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(word),
      onPressed: onTap,
      backgroundColor:
          color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
