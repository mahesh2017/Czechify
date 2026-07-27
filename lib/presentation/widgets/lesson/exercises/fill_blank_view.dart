import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import 'exercise_shared.dart';

/// Fill-in-the-blank exercise view.
class FillBlankView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const FillBlankView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<FillBlankView> createState() => _FillBlankViewState();
}

class _FillBlankViewState extends State<FillBlankView> {
  // Blanks are written as runs of underscores. Length varies across the
  // content (a single "_" for one missing letter, "___"/"_____" for words),
  // so match one-or-more. Underscores only ever appear as blanks in the
  // sentence text, so this won't over-match.
  static final _blankPattern = RegExp(r'_+');

  final Map<int, TextEditingController> _controllers = {};
  bool answered = false;
  bool? isCorrect;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// One controller per blank, stable across rebuilds.
  TextEditingController _controllerFor(int blankIdx) {
    return _controllers.putIfAbsent(blankIdx, () => TextEditingController());
  }

  void _checkAnswer() {
    final data = widget.exercise.data;
    final accepted =
        (data['blank_answers'] as List<dynamic>)
            .map((answers) => (answers as List<dynamic>).cast<String>())
            .toList();

    final blankIndices = _controllers.keys.toList()..sort();
    final userParts =
        blankIndices
            .map((idx) => normalizeAnswer(_controllers[idx]!.text))
            .toList();

    final correct =
        accepted.length == userParts.length &&
        List.generate(
          userParts.length,
          (index) =>
              accepted[index].map(normalizeAnswer).contains(userParts[index]),
        ).every((matches) => matches);

    setState(() {
      answered = true;
      isCorrect = correct;
    });

    widget.onAnswered(
      ExerciseResult(
        isCorrect: correct,
        explanation: data['explanation'] as String?,
        correctAnswer: _displayAnswer(data),
      ),
    );
  }

  /// First accepted answer, with | separators made readable.
  String _displayAnswer(Map<String, dynamic> data) {
    return (data['blank_answers'] as List<dynamic>)
        .map((answers) => (answers as List<dynamic>).first as String)
        .join(', ');
  }

  /// Input width sized to the longest accepted answer for that blank, so a
  /// one-letter blank ("M_sto") renders letter-sized and a word blank fits
  /// its word. Falls back to a word-ish width when data is missing.
  double _blankWidth(Map<String, dynamic> data, int blankIdx) {
    final answers = data['blank_answers'] as List<dynamic>?;
    if (answers == null || blankIdx >= answers.length) return 100;
    final longest = (answers[blankIdx] as List<dynamic>)
        .map((a) => a.toString().length)
        .fold<int>(1, (max, len) => len > max ? len : max);
    return (longest * 14.0 + 28).clamp(44.0, 160.0);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final sentence = data['sentence'] as String;

    // Split sentence at underscore runs to show blanks visually
    final parts = sentence.split(_blankPattern);

    // Word-level tokens: inside a Wrap a long Text child wraps internally as
    // its own block, which pushed everything after a blank onto a separate
    // "paragraph" line. One Text per word keeps the sentence flowing inline
    // around the input boxes.
    final children = <Widget>[];
    final wordStyle = Theme.of(context).textTheme.bodyLarge;
    for (var i = 0; i < parts.length; i++) {
      final isBlankPrefix =
          i < parts.length - 1 &&
          !parts[i].endsWith(' ') &&
          parts[i].isNotEmpty;
      final isBlankSuffix = i > 0 && !parts[i].startsWith(' ');
      final words = parts[i].trim().split(RegExp(r'\s+'))
        ..removeWhere((w) => w.isEmpty);
      for (var w = 0; w < words.length; w++) {
        // A word fragment glued to the blank ("M" in "M_sto") stays glued:
        // no trailing gap before, no leading gap after.
        final gluedToNextBlank = isBlankPrefix && w == words.length - 1;
        final gluedToPrevBlank = isBlankSuffix && w == 0;
        children.add(
          Padding(
            padding: EdgeInsets.only(
              left: gluedToPrevBlank ? 0 : 3,
              right: gluedToNextBlank ? 0 : 3,
            ),
            child: Text(words[w], style: wordStyle),
          ),
        );
      }
      if (i < parts.length - 1) {
        children.add(
          SizedBox(
            width: _blankWidth(data, i),
            child: TextField(
              controller: _controllerFor(i),
              enabled: !answered,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              style: TextStyle(
                color: isCorrect == false ? context.tokens.red : null,
                fontWeight: FontWeight.bold,
              ),
              onSubmitted: answered ? null : (_) => _checkAnswer(),
            ),
          ),
        );
      }
    }

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

          // Sentence with one inline input per blank
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: children,
          ),
          const SizedBox(height: 24),

          if (!answered)
            FilledButton(onPressed: _checkAnswer, child: const Text('Check')),
        ],
      ),
    );
  }
}
