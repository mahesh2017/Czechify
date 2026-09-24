import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../common/lesson_ui.dart';
import '../../common/slide_deck.dart';
import 'exercise_shared.dart';

/// Questions about one passage or recording, on slides: first the passage or
/// recording itself ([intro]), then one question to a slide with [reminder]
/// above it — the text again, or the buttons to hear it again — so nothing
/// has to be held in memory across screens and nothing has to be scrolled.
///
/// Next waits for an answer; the last slide checks them all together, which
/// is still one answer to the lesson. Once checked, the slides stay so the
/// learner can go back over what was right.
class QuestionSteps extends StatefulWidget {
  const QuestionSteps({
    super.key,
    required this.exerciseId,
    required this.questions,
    required this.intro,
    required this.reminder,
    required this.onComplete,
  });

  final int exerciseId;

  /// As stored: `question_en`, optional `question_cz`, `options`,
  /// `correct_index`.
  final List<Map<String, dynamic>> questions;
  final Widget intro;
  final Widget reminder;
  final void Function(
    bool isCorrect,
    String explanation,
    String correctAnswer,
  )
  onComplete;

  @override
  State<QuestionSteps> createState() => _QuestionStepsState();
}

class _QuestionStepsState extends State<QuestionSteps> {
  late List<Map<String, dynamic>> _questions;
  late List<int?> _selected;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Same seed as the one-page views, so a question's options come in the
    // same order whichever way it is shown.
    _questions = [
      for (final (index, question) in widget.questions.indexed)
        shuffledQuestion(question, seed: widget.exerciseId * 31 + index),
    ];
    _selected = List.filled(_questions.length, null);
  }

  int _correct(int q) => (_questions[q]['correct_index'] as num).toInt();

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final right = [
      for (var q = 0; q < _questions.length; q++) _selected[q] == _correct(q),
    ].where((ok) => ok).length;
    final all = right == _questions.length;
    setState(() => _submitted = true);
    widget.onComplete(
      all,
      all
          ? l10n.exerciseAllAnsweredCorrectly
          : l10n.exerciseYouGotCorrect(right, _questions.length),
      [
        for (var q = 0; q < _questions.length; q++)
          (_questions[q]['options'] as List<dynamic>)[_correct(q)] as String,
      ].join(', '),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideDeck(
      slides: [
        widget.intro,
        for (var q = 0; q < _questions.length; q++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.reminder,
              const SizedBox(height: 10),
              _question(context, q),
            ],
          ),
      ],
      // Slide 0 is the passage; slide q + 1 asks question q.
      canAdvance:
          (slide) =>
              slide == 0 ||
              (slide == _questions.length
                  ? _selected.every((s) => s != null)
                  : _selected[slide - 1] != null),
      doneLabel: AppLocalizations.of(context).exerciseCheckAnswers,
      onDone: _submit,
      finished: _submitted,
    );
  }

  Widget _question(BuildContext context, int q) {
    final t = context.tokens;
    final question = _questions[q];
    final questionEn = question['question_en'] as String? ?? '';
    final questionCz = question['question_cz'] as String? ?? '';
    final options = (question['options'] as List<dynamic>).cast<String>();
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
          // No "Question 1" kicker: the dots say where the learner is, and
          // on a small phone its line is the room the question needs.
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
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == options.length - 1 ? 0 : 8),
              child: QuizOptionTile(
                keyLabel: String.fromCharCode(65 + i),
                text: options[i],
                state: optionState(
                  index: i,
                  correctIndex: _correct(q),
                  selectedIndex: _selected[q],
                  answered: _submitted,
                ),
                onTap:
                    _submitted ? null : () => setState(() => _selected[q] = i),
              ),
            ),
        ],
      ),
    );
  }
}
