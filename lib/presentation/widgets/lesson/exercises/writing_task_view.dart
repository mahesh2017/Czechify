import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/learning_evidence.dart';
import '../../common/lesson_ui.dart';
import '../../common/soft_ui.dart';
import 'exercise_shared.dart';

/// Writing task exercise — write a short text in Czech based on a prompt.
/// For automated checking, accepted_answers provides keyword/phrase matches;
/// otherwise the exercise is self-assessed or evaluated by the LLM.
class WritingTaskView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const WritingTaskView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<WritingTaskView> createState() => _WritingTaskViewState();
}

class _WritingTaskViewState extends State<WritingTaskView> {
  final _controller = TextEditingController();
  bool answered = false;
  bool _isCorrect = false;
  int _wordCount = 0;
  bool _meetsMinWords = false;
  String _feedbackText = '';
  String _firstDraft = '';
  bool _revisionStage = false;
  bool _showKeyVocab = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _prompt {
    return (widget.exercise.data['prompt_en'] ?? widget.exercise.prompt)
        as String;
  }

  String? get _promptCz => widget.exercise.data['prompt_cz'] as String?;

  List<String>? get _keyVocab {
    final raw = widget.exercise.data['key_vocab'];
    if (raw is List) return raw.cast<String>();
    return null;
  }

  int? get _minWords => widget.exercise.data['min_words'] as int?;

  String? get _answerKey => widget.exercise.answerKey;

  String? get _sampleAnswer =>
      widget.exercise.data['sample_answer'] as String? ??
      widget.exercise.data['answer_key'] as String?;

  void _submit() {
    final text = _controller.text.trim();
    final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\\s+')).length;
    final meetsMinWords = _minWords == null || wordCount >= _minWords!;
    final hasContent = text.isNotEmpty;

    // Writing tasks are always formative — automated keyword matching can
    // reject valid paraphrases and accept keyword lists, so it must never
    // determine correctness or affect XP, mastery, or exam passes.  The
    // rubric criteria and sample answer are shown for self-assessment.
    final l10n = AppLocalizations.of(context);
    final parts = <String>[
      l10n.writingWroteWords(wordCount),
      if (_minWords != null)
        meetsMinWords
            ? l10n.writingMeetsMinimum(_minWords!)
            : l10n.writingNeedsMinimum(_minWords!),
      l10n.writingUnscoredNote,
      if (_revisionStage && text != _firstDraft) l10n.writingRevisedDraft,
    ];

    setState(() {
      answered = true;
      _isCorrect = false; // Never "correct" — writing is formative
      _wordCount = wordCount;
      _meetsMinWords = meetsMinWords;
      _feedbackText = parts.join(' ');
    });

    final supports =
        _showKeyVocab ? const {SupportKind.hint} : const <SupportKind>{};
    widget.onAnswered(
      ExerciseResult.skipped(
        explanation: _feedbackText,
        correctAnswer: _sampleAnswer,
        supports: supports,
      ),
    );
  }

  void _reviewDraft() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _firstDraft = text;
      _revisionStage = true;
    });
  }

  void _retry() {
    setState(() {
      answered = false;
      _isCorrect = false;
      _wordCount = 0;
      _meetsMinWords = false;
      _feedbackText = '';
      _firstDraft = '';
      _revisionStage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The brief, the page and any feedback scroll together; only the
          // letter bar and the action stay pinned. Writing tasks are the one
          // exercise whose content can outgrow the viewport on its own.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuestionPrompt(question: _prompt, czech: _promptCz),
                  if (_minWords != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.writingWriteAtLeast(_minWords!),
                      style: TextStyle(fontSize: 14, color: t.muted),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Optional vocabulary support is hidden until requested so its use
                  // remains observable rather than silently inflating performance.
                  if (_keyVocab != null &&
                      _keyVocab!.isNotEmpty &&
                      !_showKeyVocab &&
                      !answered) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showKeyVocab = true),
                        icon: const Icon(Icons.lightbulb_outline, size: 18),
                        label: Text(l10n.writingShowVocabSupport),
                        style: TextButton.styleFrom(
                          foregroundColor: t.amberInk,
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  ],
                  if (_keyVocab != null &&
                      _keyVocab!.isNotEmpty &&
                      _showKeyVocab) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.amberSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.writingTryUsing,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: t.amberInk,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final v in _keyVocab!)
                                PillChip(label: v, bg: t.card, fg: t.ink),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_revisionStage && !answered) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.violetSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        l10n.writingReviseNote,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.5,
                          color: t.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // The page to write on: paper-like, and the tallest thing here.
                  // It grows with the answer rather than filling the viewport, so a
                  // long draft and its feedback can both be read.
                  Container(
                    decoration: BoxDecoration(
                      color: t.card,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: t.shadow,
                    ),
                    child: TextField(
                      controller: _controller,
                      enabled: !answered,
                      cursorColor: t.pri,
                      decoration: InputDecoration(
                        hintText: l10n.writingHint,
                        hintStyle: TextStyle(fontSize: 16, color: t.faint),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.all(18),
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.55,
                        color: t.ink,
                      ),
                      maxLines: null,
                      minLines: 6,
                      textAlignVertical: TextAlignVertical.top,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  // Word count sits with the page it counts, not below the button.
                  if (!answered)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_controller.text.trim().isEmpty ? 0 : _controller.text.trim().split(RegExp(r'\s+')).length} words',
                          style: TextStyle(fontSize: 13, color: t.faint),
                        ),
                      ),
                    ),
                  // Feedback after submission
                  if (answered) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isCorrect ? t.greenSoft : t.redSoft,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isCorrect ? Icons.check_circle : Icons.cancel,
                                color: _isCorrect ? t.greenInk : t.redInk,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  // Not "Good!"/"Needs improvement": nothing here read
                                  // the writing. This path is a keyword comparison, and
                                  // the verdict should not imply more than that.
                                  widget.exercise.answerKey == null
                                      ? l10n.writingCycleComplete
                                      : _isCorrect
                                      ? AppLocalizations.of(
                                        context,
                                      ).writingKeyPhrasesFound
                                      : AppLocalizations.of(
                                        context,
                                      ).writingKeyPhrasesMissing,
                                  style: TextStyle(
                                    fontFamily: AppFonts.display,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _isCorrect ? t.greenInk : t.redInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _feedbackText,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: t.ink,
                            ),
                          ),
                          if (widget.exercise.answerKey != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).writingKeywordCheckNote,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: t.muted,
                              ),
                            ),
                          ],
                          if (_minWords != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _meetsMinWords ? Icons.check : Icons.close,
                                  size: 15,
                                  color: _meetsMinWords ? t.greenInk : t.redInk,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  l10n.writingWordCountMin(
                                    _wordCount,
                                    _minWords!,
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Show sample/reference answer if available
                    if (_sampleAnswer != null || _answerKey != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: t.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LessonKicker(
                              l10n.writingReferenceAnswer,
                              color: t.pri,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _sampleAnswer ?? _answerKey!,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.55,
                                color: t.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Retry button
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(AppLocalizations.of(context).tryAgain),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!answered) ...[
            // Unlabelled here: the brief above already says to write in Czech,
            // and the pinned footer has no room to spare.
            CzechCharBar(controller: _controller, showLabel: false),
            const SizedBox(height: 12),
            KeyCta(
              label:
                  _revisionStage
                      ? l10n.writingSubmitRevision
                      : l10n.writingReviewDraft,
              onPressed: _revisionStage ? _submit : _reviewDraft,
            ),
          ],
        ],
      ),
    );
  }
}
