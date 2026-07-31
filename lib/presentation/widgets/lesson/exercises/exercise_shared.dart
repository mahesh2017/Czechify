import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../domain/entities/exercise_outcome.dart';
import '../../../../domain/entities/learning_evidence.dart';
import '../../../providers/tts_providers.dart';

/// Normalize a typed answer for comparison: lowercase, strip punctuation,
/// collapse whitespace. Diacritics are kept — they're meaningful in Czech.
String normalizeAnswer(String s) => TextNormalizer.normalize(s);

/// Translucent feedback tints that work on light and dark surfaces.
///
/// Context-bound because the base hues come from [AppTokens] — the dark
/// theme's green and red are lighter than the light theme's, so a fixed
/// tint reads as mud on one of the two.
Color correctTint(BuildContext context) =>
    context.tokens.green.withValues(alpha: 0.12);
Color wrongTint(BuildContext context) =>
    context.tokens.red.withValues(alpha: 0.12);

/// How closely a typed answer matched: exact, accents-only difference,
/// or wrong.
enum AnswerMatch { exact, nearMiss, none }

/// Compare a user's typed answer against the accepted answers, allowing a
/// diacritics-only "near miss".
AnswerMatch matchAnswer(List<String> accepted, String user) {
  final u = normalizeAnswer(user);
  if (u.isEmpty) return AnswerMatch.none;
  if (accepted.any((a) => normalizeAnswer(a) == u)) {
    return AnswerMatch.exact;
  }
  if (accepted.any((a) => TextNormalizer.matchesIgnoringDiacritics(a, user))) {
    return AnswerMatch.nearMiss;
  }
  return AnswerMatch.none;
}

/// A horizontal bar of Czech diacritic letters that inserts into the
/// currently-targeted text field at the cursor. Essential when typing on a
/// non-Czech keyboard, where several exercises are otherwise unanswerable.
class CzechCharBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  /// Labelled by default, because an unlabelled strip of accented letters
  /// under a text field does not explain itself.
  final bool showLabel;

  const CzechCharBar({
    super.key,
    required this.controller,
    this.enabled = true,
    this.showLabel = true,
  });

  void _insert(String ch) {
    final sel = controller.selection;
    final text = controller.text;
    if (sel.isValid && sel.start >= 0) {
      final newText = text.replaceRange(sel.start, sel.end, ch);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + ch.length),
      );
    } else {
      controller.text = text + ch;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      decoration: BoxDecoration(
        color: t.elev,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 7),
              child: Text(
                (Localizations.of<AppLocalizations>(
                          context,
                          AppLocalizations,
                        )?.czechLetters ??
                        'Czech letters')
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: t.faint,
                ),
              ),
            ),
          ],
          SizedBox(
            // 46pt keys: the target is the drawn size here, so it has to
            // clear the minimum on its own.
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: TextNormalizer.czechDiacriticChars.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, i) {
                final ch = TextNormalizer.czechDiacriticChars[i];
                return Semantics(
                  button: enabled,
                  label: AppLocalizations.of(context).a11yInsertCharacter(ch),
                  excludeSemantics: true,
                  child: Material(
                    color: enabled ? t.priSoft : t.card,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: enabled ? () => _insert(ch) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 40,
                        height: 46,
                        child: Center(
                          child: Text(
                            ch,
                            style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: enabled ? t.pri : t.faint,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The question at the top of an exercise: the task in display face, with the
/// Czech being asked about underneath and a speaker for it.
///
/// Left-aligned rather than centred — a centred sentence that wraps to three
/// lines is harder to re-read, and every exercise type shares this shape.
class QuestionPrompt extends StatelessWidget {
  const QuestionPrompt({super.key, required this.question, this.czech});

  final String question;

  /// The Czech under test, if the question is about a specific string.
  final String? czech;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.6,
            color: t.ink,
          ),
        ),
        if (czech != null && czech!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  czech!,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: t.pri,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TtsButton(text: czech!, size: 22),
            ],
          ),
        ],
      ],
    );
  }
}

/// Result of an exercise answer submission.
class ExerciseResult {
  final ExerciseOutcome outcome;
  final String? explanation;
  final String? correctAnswer;
  final Set<SupportKind> supports;

  const ExerciseResult({
    required bool isCorrect,
    this.explanation,
    this.correctAnswer,
    this.supports = const {},
  }) : outcome =
           isCorrect ? ExerciseOutcome.correct : ExerciseOutcome.incorrect;

  const ExerciseResult.skipped({
    this.explanation,
    this.correctAnswer,
    this.supports = const {},
  }) : outcome = ExerciseOutcome.skipped;

  bool get isCorrect => outcome == ExerciseOutcome.correct;
  bool get isSkipped => outcome == ExerciseOutcome.skipped;
}

/// Callback type for when an exercise is answered.
typedef OnExerciseAnswered = void Function(ExerciseResult result);

/// Small reusable TTS button that speaks Czech text when tapped.
class TtsButton extends ConsumerWidget {
  final String text;
  final double size;
  final Color? color;
  final VoidCallback? onPlayed;

  const TtsButton({
    super.key,
    required this.text,
    this.size = 24,
    this.color,
    this.onPlayed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () {
        onPlayed?.call();
        ref.read(czechTtsProvider).speak(text);
      },
      icon: Icon(Icons.volume_up, size: size),
      color: color ?? Theme.of(context).colorScheme.primary,
      // Nullable lookup, not AppLocalizations.of(context), which asserts a
      // Localizations ancestor. This is a leaf primitive dropped into bare
      // widget tests and previews; requiring the full app scope to render an
      // audio button is coupling it does not need. The app always supplies
      // the delegates, so the fallback is only ever seen out of app context.
      tooltip:
          Localizations.of<AppLocalizations>(
            context,
            AppLocalizations,
          )?.listen ??
          'Listen',
    );
  }
}
