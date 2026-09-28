import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/learning_evidence.dart';
import '../../common/lesson_image.dart';
import '../../common/scrolling_passage.dart';
import '../../common/slide_deck.dart';
import '../../../../l10n/app_localizations.dart';
import 'exercise_shared.dart';
import 'question_steps.dart';

/// Reading comprehension exercise — read a Czech passage, then answer
/// multiple-choice questions about it.
class ReadingComprehensionView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const ReadingComprehensionView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<ReadingComprehensionView> createState() =>
      _ReadingComprehensionViewState();
}

class _ReadingComprehensionViewState extends State<ReadingComprehensionView> {
  /// The passage card shows the English instead of the Czech, and whether it
  /// ever has — reading with the translation is support.
  bool _english = false;
  bool _usedTranslation = false;

  @override
  void didUpdateWidget(covariant ReadingComprehensionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id) {
      _english = false;
      _usedTranslation = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final image = (data['image'] as String?)?.trim();
    final imageLabel = (data['image_label'] as String?)?.trim();
    return _slides(
      context,
      prompt: data['prompt_en'] as String? ?? widget.exercise.prompt,
      textCz: data['text_cz'] as String? ?? '',
      textEn: data['text_en'] as String?,
      image: image,
      imageLabel: imageLabel,
    );
  }

  /// The passage with its translation, then each question under the Czech
  /// text again, or after it when both do not fit.
  Widget _slides(
    BuildContext context, {
    required String prompt,
    required String textCz,
    required String? textEn,
    required String? image,
    required String? imageLabel,
  }) {
    final t = context.tokens;
    return QuestionSteps(
      exerciseId: widget.exercise.id,
      questions:
          (widget.exercise.data['questions'] as List<dynamic>)
              .cast<Map<String, dynamic>>(),
      // One slide: the task, the picture and the passage, whose card takes
      // the room left and scrolls inside when the text is longer. The slide
      // itself scrolls only when not even a few lines of text would fit (at
      // large text sizes).
      intro: [
        FillSlide(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QuestionPrompt(question: prompt),
                    const SizedBox(height: 16),
                    if (image != null && image.isNotEmpty) ...[
                      LessonImage(
                        asset: image,
                        height: 140,
                        semanticLabel:
                            imageLabel == null || imageLabel.isEmpty
                                ? null
                                : imageLabel,
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
              SliverLayoutBuilder(
                builder:
                    (context, constraints) => SliverToBoxAdapter(
                      child: _slidePassage(
                        context,
                        textCz,
                        textEn,
                        maxHeight: math.max(
                          constraints.remainingPaintExtent,
                          ScrollingPassage.minHeight + 64,
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ],
      reminderMaySplit: true,
      reminder: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: BoxDecoration(
          color: t.elev,
          borderRadius: BorderRadius.circular(16),
        ),
        // Blank lines are the passage's layout; the reminder above a question
        // needs its words, not its spacing.
        child: Text(
          textCz.replaceAll(RegExp(r'\n\s*\n'), '\n'),
          style: TextStyle(fontSize: 14, height: 1.4, color: t.ink),
        ),
      ),
      onComplete:
          (isCorrect, explanation, correctAnswer) => widget.onAnswered(
            ExerciseResult(
              isCorrect: isCorrect,
              explanation: explanation,
              correctAnswer: correctAnswer,
              supports: {if (_usedTranslation) SupportKind.translation},
            ),
          ),
    );
  }

  /// The passage in one language at a time: Czech, and the English on request
  /// in its place. At most [maxHeight] tall; a longer text scrolls inside.
  Widget _slidePassage(
    BuildContext context,
    String textCz,
    String? textEn, {
    required double maxHeight,
  }) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final hasEnglish = textEn != null && textEn.isNotEmpty;
    final english = _english && hasEnglish;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: EdgeInsets.fromLTRB(18, hasEnglish ? 6 : 18, 8, 16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.line),
          boxShadow: t.shadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // On top, so it stays in view however far the text scrolls.
            if (hasEnglish)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      () => setState(() {
                        _english = !_english;
                        if (_english) _usedTranslation = true;
                      }),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.translate, size: 18),
                  label: Text(
                    english ? l10n.readingShowCzech : l10n.readingShowEnglish,
                  ),
                ),
              ),
            Flexible(
              child: ScrollingPassage(
                // A new text starts at the top.
                key: ValueKey(english),
                child: Text(
                  english ? textEn : textCz,
                  style:
                      english
                          ? TextStyle(fontSize: 15, height: 1.55, color: t.muted)
                          : TextStyle(fontSize: 17, height: 1.6, color: t.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
