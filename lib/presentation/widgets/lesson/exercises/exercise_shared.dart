import 'package:flutter/material.dart';
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

  const CzechCharBar({
    super.key,
    required this.controller,
    this.enabled = true,
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
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: TextNormalizer.czechDiacriticChars.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final ch = TextNormalizer.czechDiacriticChars[i];
          return OutlinedButton(
            onPressed: enabled ? () => _insert(ch) : null,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(ch, style: const TextStyle(fontSize: 16)),
          );
        },
      ),
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
      tooltip: 'Listen',
    );
  }
}
