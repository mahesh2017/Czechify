import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../common/lesson_ui.dart';
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
    final t = context.tokens;
    final translationEn = widget.exercise.data['translation_en'] as String?;
    final verdictBorder = switch (isCorrect) {
      true => t.green,
      false => t.red,
      null => t.line,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: widget.exercise.prompt),
          if (translationEn != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.elev,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                translationEn,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: t.ink,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // The sentence being built, on ruled lines. Empty it reads as the
          // place the answer goes, rather than as an empty box.
          ShakeOnce(
            trigger: isCorrect == false ? selected.length : null,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: verdictBorder, width: 1.5),
                borderRadius: BorderRadius.circular(24),
                boxShadow: t.shadow,
              ),
              child:
                  selected.isEmpty
                      ? Center(
                        child: Text(
                          'Tap the words below in order',
                          style: TextStyle(fontSize: 15, color: t.faint),
                        ),
                      )
                      : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in selected.asMap().entries)
                            WordChip(
                              word: entry.value,
                              placed: true,
                              verdict: isCorrect,
                              onTap:
                                  answered
                                      ? null
                                      : () => setState(() {
                                        available.add(
                                          selected.removeAt(entry.key),
                                        );
                                      }),
                            ),
                        ],
                      ),
            ),
          ),
          const SizedBox(height: 18),

          // The words still to place.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in available.asMap().entries)
                WordChip(
                  word: entry.value,
                  onTap:
                      answered
                          ? null
                          : () => setState(() {
                            selected.add(available.removeAt(entry.key));
                          }),
                ),
            ],
          ),
          // No Spacer here: this widget renders inside a scroll view, where
          // flex children have unbounded height and would throw.
          const SizedBox(height: 24),
          if (!answered && selected.isNotEmpty)
            KeyCta(
              label: AppLocalizations.of(context).check,
              onPressed: _checkAnswer,
            ),
        ],
      ),
    );
  }
}

/// One draggable-by-tap word. Raised like a key when it is still in the bank,
/// flat once it has been placed into the sentence.
class WordChip extends StatelessWidget {
  final String word;
  final VoidCallback? onTap;

  /// `true` once the word sits in the answer line.
  final bool placed;

  /// Carries the result colour on placed words after checking.
  final bool? verdict;

  const WordChip({
    super.key,
    required this.word,
    this.onTap,
    this.placed = false,
    this.verdict,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg) = switch (verdict) {
      true when placed => (t.greenSoft, t.greenInk),
      false when placed => (t.redSoft, t.redInk),
      _ when placed => (t.priSoft, t.priInk),
      _ => (t.card, t.ink),
    };

    return Semantics(
      button: onTap != null,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: placed ? Colors.transparent : t.line),
              // The bank sits proud of the page; a placed word lies flat.
              boxShadow:
                  placed
                      ? null
                      : [
                        BoxShadow(
                          color: t.ink.withValues(alpha: 0.12),
                          offset: const Offset(0, 1.5),
                        ),
                      ],
            ),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
