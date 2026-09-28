import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/learning_evidence.dart';
import '../../../../domain/engines/writing_word_gate.dart';
import '../../common/motion_widgets.dart';
import '../../common/slide_deck.dart';
import '../../common/soft_ui.dart';
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

  /// The text last reported as the draft.
  late String _reported = widget.initialDraft;

  void _draftChanged() {
    // The controller also notifies when only the cursor moves — the page
    // focuses the field as it opens — and a restored draft is not an edit.
    if (_controller.text != _reported) {
      _reported = _controller.text;
      widget.onDraftChanged?.call(_controller.text);
    }
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

  /// The brief on one slide, the page on the next. The page takes the
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
  Widget build(BuildContext context) => _slides(context);
}
