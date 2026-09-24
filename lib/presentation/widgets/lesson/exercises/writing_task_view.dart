import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/learning_evidence.dart';
import '../../../../domain/engines/writing_word_gate.dart';
import '../../common/lesson_ui.dart';
import '../../common/motion_widgets.dart';
import '../../common/slide_deck.dart';
import '../../common/soft_ui.dart';
import '../slides_pilot.dart';
import 'exercise_shared.dart';

/// Writing task exercise — write a short text in Czech based on a prompt.
/// For automated checking, accepted_answers provides keyword/phrase matches;
/// otherwise the exercise is self-assessed or evaluated by the LLM.
class WritingTaskView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;
  final String initialDraft;
  final ValueChanged<String>? onDraftChanged;

  const WritingTaskView({
    super.key,
    required this.exercise,
    required this.onAnswered,
    this.initialDraft = '',
    this.onDraftChanged,
  });

  @override
  State<WritingTaskView> createState() => _WritingTaskViewState();
}

class _WritingTaskViewState extends State<WritingTaskView> {
  final _controller = TextEditingController();
  final _pageFocus = FocusNode();
  bool answered = false;
  int _wordCount = 0;
  bool _meetsMinWords = false;
  String _feedbackText = '';
  String _firstDraft = '';
  bool _revisionStage = false;
  bool _showKeyVocab = false;

  @override
  void initState() {
    super.initState();
    // Listen to the controller rather than only TextField.onChanged so the
    // word count and CTA also react to CzechCharBar's programmatic edits.
    _controller.text = widget.initialDraft;
    _controller.addListener(_draftChanged);
  }

  void _draftChanged() {
    widget.onDraftChanged?.call(_controller.text);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_draftChanged);
    _controller.dispose();
    _pageFocus.dispose();
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

  bool get _hasDraft => _controller.text.trim().isNotEmpty;

  void _submit() {
    final text = _controller.text.trim();
    final wordCount = WritingWordGate.countWords(text);
    final meetsMinWords = _minWords == null || wordCount >= _minWords!;
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
    // Reviewing is stepping back to read: the keyboard goes, so the note on
    // what to check has room to show above the page.
    _pageFocus.unfocus();
    setState(() {
      _firstDraft = text;
      _revisionStage = true;
    });
  }

  // No retry after submitting. The draft is reworked before that, in the
  // review-then-revise step. Once submitted, the result belongs to the lesson,
  // which ignores a second answer while its feedback is showing — a rewrite
  // here was never recorded — and the reference answer is on screen by then,
  // so writing again would mostly be copying it.

  /// The brief's optional word support: a button until asked for, then the
  /// words. Asking is recorded as a hint.
  Widget _vocabSupport(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_keyVocab != null &&
            _keyVocab!.isNotEmpty &&
            !_showKeyVocab &&
            !answered)
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
        MotionDisclosure(
          visible: _keyVocab != null && _keyVocab!.isNotEmpty && _showKeyVocab,
          child: Container(
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
                    for (final v in _keyVocab ?? const <String>[])
                      PillChip(label: v, bg: t.card, fg: t.ink),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Pilot: the brief on one slide, the page on the next. The page takes the
  /// room that is left, which on a small phone with the keyboard up is about
  /// three lines — enough for a few sentences, and the brief is one swipe
  /// back. What the learner wrote is judged in the lesson's feedback sheet,
  /// which carries the word count and the reference answer, so nothing is
  /// added here once it is sent.
  Widget _slides(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final words = WritingWordGate.countWords(_controller.text);
    final brief = _promptCz ?? _prompt;
    return SlideDeck(
      slides: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuestionPrompt(
              question: _prompt,
              czech: _promptCz,
              instruction: true,
            ),
            if (_minWords != null) ...[
              const SizedBox(height: 10),
              Text(
                l10n.writingWriteAtLeast(_minWords!),
                style: TextStyle(fontSize: 14, color: t.muted),
              ),
            ],
            const SizedBox(height: 14),
            _vocabSupport(context),
          ],
        ),
        FillSlide(
          child: KeyboardUpBuilder(
            builder: (context, typing) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // While typing, every line goes to the page.
              if (!typing) ...[
                if (_revisionStage && !answered)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.violetSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      l10n.writingReviseNote,
                      style: TextStyle(fontSize: 14, height: 1.45, color: t.ink),
                    ),
                  )
                else
                  Text(
                    brief,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: t.muted,
                    ),
                  ),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: t.shadow,
                  ),
                  // The field's own fill is square; the page is not.
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      TextField(
                        controller: _controller,
                        focusNode: _pageFocus,
                        enabled: !answered,
                        cursorColor: t.pri,
                        expands: true,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: l10n.writingHint,
                          hintStyle: TextStyle(fontSize: 16, color: t.faint),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(
                            18,
                            16,
                            18,
                            26,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.55,
                          color: t.ink,
                        ),
                        textAlignVertical: TextAlignVertical.top,
                        textInputAction: TextInputAction.newline,
                      ),
                      // The count sits in the page's corner, so it costs the
                      // page no line.
                      Positioned(
                        right: 14,
                        bottom: 8,
                        child: IgnorePointer(
                          child: Text(
                            l10n.writingWordsSoFar(words),
                            style: TextStyle(fontSize: 12, color: t.faint),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!answered) ...[
                const SizedBox(height: 8),
                CzechCharBar(controller: _controller, showLabel: false),
              ],
            ],
          ),
          ),
        ),
      ],
      // The page is the step: it opens ready to type.
      onSlideChanged: (slide) {
        if (slide != 1 || answered) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pageFocus.requestFocus();
        });
      },
      canAdvance: (slide) => slide == 0 || _hasDraft,
      doneLabel:
          _revisionStage ? l10n.writingSubmitRevision : l10n.writingReviewDraft,
      onDone: _revisionStage ? _submit : _reviewDraft,
      finished: answered,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    if (showsAsSlides(widget.exercise)) return _slides(context);

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
                  MotionDisclosure(
                    visible:
                        _keyVocab != null &&
                        _keyVocab!.isNotEmpty &&
                        _showKeyVocab,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                                  for (final v in _keyVocab ?? const <String>[])
                                    PillChip(label: v, bg: t.card, fg: t.ink),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),

                  MotionDisclosure(
                    visible: _revisionStage && !answered,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                    ),
                  ),

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
                          '${WritingWordGate.countWords(_controller.text)} words',
                          style: TextStyle(fontSize: 13, color: t.faint),
                        ),
                      ),
                    ),
                  // Feedback after submission
                  if (answered)
                    MotionEntrance(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          // Neutral, because nothing here graded the writing.
                          //
                          // This panel used to be a verdict: green/check when
                          // correct, red/cancel otherwise. Writing is
                          // deliberately formative and never scored, so the
                          // correct branch was unreachable and every learner
                          // finished every task on a red failure card. With an
                          // answer key present — as all 97 shipped writing
                          // tasks have — it also read "Key phrases not found",
                          // which no code had checked; submitting the answer
                          // key verbatim produced it.
                          //
                          // Violet for an unscored outcome follows the exam
                          // result screen; amber stays reserved for streak
                          // and XP.
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: t.violetSoft,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: t.violetInk,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l10n.writingCycleComplete,
                                        style: TextStyle(
                                          fontFamily: AppFonts.display,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: t.violetInk,
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
                                // No keyword-check note here either. It told
                                // the learner their words had been compared
                                // against the expected phrases; nothing ever
                                // ran that comparison. What is actually true —
                                // that this is unscored practice — is already
                                // in [_feedbackText] above.
                                if (_minWords != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        _meetsMinWords
                                            ? Icons.check
                                            : Icons.close,
                                        size: 15,
                                        color:
                                            _meetsMinWords
                                                ? t.greenInk
                                                : t.redInk,
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
                        ],
                      ),
                    ),
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
              onPressed:
                  !_hasDraft ? null : (_revisionStage ? _submit : _reviewDraft),
            ),
          ],
        ],
      ),
    );
  }
}
