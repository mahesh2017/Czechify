import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../common/lesson_ui.dart';
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
  final Map<int, FocusNode> _focusNodes = {};

  /// Which blank the Czech letter bar should type into. The bar sits outside
  /// the fields, so tapping it would otherwise steal focus and leave the
  /// character with nowhere to go.
  int _activeBlank = 0;

  bool answered = false;
  bool? isCorrect;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  /// One controller per blank, stable across rebuilds.
  TextEditingController _controllerFor(int blankIdx) {
    return _controllers.putIfAbsent(blankIdx, () => TextEditingController());
  }

  FocusNode _focusFor(int blankIdx) {
    return _focusNodes.putIfAbsent(blankIdx, () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus && _activeBlank != blankIdx) {
          setState(() => _activeBlank = blankIdx);
        }
      });
      return node;
    });
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
    final t = context.tokens;
    final children = <Widget>[];
    final wordStyle = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: t.ink,
    );
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
        // The blank is a filled slot with a ruled underline, so it reads as a
        // gap in the sentence rather than as a form field dropped into prose.
        children.add(
          SizedBox(
            width: _blankWidth(data, i),
            child: TextField(
              controller: _controllerFor(i),
              focusNode: _focusFor(i),
              enabled: !answered,
              textAlign: TextAlign.center,
              cursorColor: t.pri,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: t.elev,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.pri, width: 1.5),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: switch (isCorrect) {
                      true => t.green,
                      false => t.red,
                      null => t.line,
                    },
                    width: 1.5,
                  ),
                ),
              ),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: switch (isCorrect) {
                  true => t.greenInk,
                  false => t.redInk,
                  null => t.ink,
                },
              ),
              textInputAction:
                  i < parts.length - 2
                      ? TextInputAction.next
                      : TextInputAction.done,
              onSubmitted:
                  answered
                      ? null
                      : (_) {
                        if (i < parts.length - 2) {
                          _focusFor(i + 1).requestFocus();
                        } else {
                          _checkAnswer();
                        }
                      },
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: widget.exercise.prompt),
          const SizedBox(height: 20),

          // The sentence, with one inline input per blank.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(24),
              boxShadow: t.shadow,
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              children: children,
            ),
          ),
          const SizedBox(height: 14),
          if (!answered) ...[
            // Types into whichever blank was last focused.
            CzechCharBar(
              controller: _controllerFor(_activeBlank),
              enabled: !answered,
            ),
            const SizedBox(height: 18),
            KeyCta(
              label: AppLocalizations.of(context).check,
              onPressed: _checkAnswer,
            ),
          ],
        ],
      ),
    );
  }
}
