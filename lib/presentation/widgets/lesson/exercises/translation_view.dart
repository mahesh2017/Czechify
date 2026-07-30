import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../common/lesson_ui.dart';
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
            ? AppLocalizations.of(context).translationAccentHint(accepted.first)
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
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final data = widget.exercise.data;
    final direction = data['direction'] as String? ?? 'en_to_cz';
    final source = data['source'] as String;
    final toCzech = direction == 'en_to_cz';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(
            question:
                toCzech ? l10n.exerciseSayInCzech : l10n.exerciseSayInEnglish,
          ),
          const SizedBox(height: 14),
          // The sentence to translate, on the neutral panel — it is the given,
          // not the answer.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.elev,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (toCzech ? l10n.labelEnglish : l10n.labelCzech).toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.7,
                    color: t.faint,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        source,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: t.ink,
                        ),
                      ),
                    ),
                    if (!toCzech) ...[
                      const SizedBox(width: 4),
                      TtsButton(text: source, size: 22),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AnswerField(
            controller: _controller,
            enabled: !answered,
            verdict: isCorrect,
            multiline: true,
            semanticLabel:
                toCzech ? l10n.exerciseTypeInCzech : l10n.exerciseTypeInEnglish,
            onSubmitted: answered ? null : (_) => _checkAnswer(),
          ),

          // Czech character helper — only when typing Czech.
          if (toCzech && !answered) ...[
            const SizedBox(height: 12),
            CzechCharBar(controller: _controller, enabled: !answered),
          ],
          const SizedBox(height: 18),

          if (!answered) KeyCta(label: l10n.check, onPressed: _checkAnswer),

          // The lesson player's feedback sheet shows the correct answer.
        ],
      ),
    );
  }
}
