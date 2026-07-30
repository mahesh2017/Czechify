import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../common/grammar_tip_card.dart';
import '../../common/lesson_ui.dart';
import 'exercise_shared.dart';
import '../../../../domain/entities/learning_evidence.dart';

/// Error correction exercise — spot the mistake in a Czech sentence and
/// select the correct form.
///
/// Supports two data shapes:
///   {sentence_cz, correct_sentence_cz, error_type, explanation}
///   {sentence_with_error, hint, accepted_answers, explanation}
///   Optionally: {options: [...]}
class ErrorCorrectionView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const ErrorCorrectionView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<ErrorCorrectionView> createState() => _ErrorCorrectionViewState();
}

class _ErrorCorrectionViewState extends State<ErrorCorrectionView> {
  bool answered = false;
  int? _selectedWordIdx;
  int? _selectedOptionIdx;
  bool _errorRevealed = false;
  bool _wasCorrect = false;

  String get _incorrectSentence {
    return (widget.exercise.data['sentence_cz'] ??
            widget.exercise.data['sentence_with_error'] ??
            '')
        as String;
  }

  String get _correctSentence {
    return (widget.exercise.data['correct_sentence_cz'] ?? '') as String;
  }

  String get _explanation {
    return (widget.exercise.data['explanation'] ?? '') as String;
  }

  String? get _hint => widget.exercise.data['hint'] as String?;

  List<String>? get _acceptedAnswers {
    final raw = widget.exercise.data['accepted_answers'];
    if (raw is List) return raw.cast<String>();
    return null;
  }

  List<String>? get _options {
    final raw = widget.exercise.data['options'];
    if (raw is List) return raw.cast<String>();
    return null;
  }

  List<String> get _words => _incorrectSentence.split(' ');

  bool _wordIsDifferentAt(int idx) {
    if (_correctSentence.isEmpty) return false;
    final correctWords = _correctSentence.split(' ');
    if (idx >= correctWords.length) return false;
    return normalizeAnswer(_words[idx]) != normalizeAnswer(correctWords[idx]);
  }

  void _onWordTap(int idx) {
    if (answered || _errorRevealed) return;
    setState(() {
      _selectedWordIdx = idx;
      _selectedOptionIdx = null;
    });
  }

  void _revealError() {
    setState(() => _errorRevealed = true);
  }

  void _submitWithOption() {
    if (_selectedWordIdx == null) return;

    bool isCorrect;
    final options = _options;
    if (options != null && _selectedOptionIdx != null) {
      // Option mode: correct if selected option matches the correct word.
      final correctWord =
          _correctSentence.isNotEmpty
              ? _correctSentence.split(' ')[_selectedWordIdx!]
              : null;
      if (correctWord != null) {
        isCorrect =
            normalizeAnswer(options[_selectedOptionIdx!]) ==
            normalizeAnswer(correctWord);
      } else {
        isCorrect = _wordIsDifferentAt(_selectedWordIdx!);
      }
    } else {
      // Word-only mode: correct if the tapped word is the wrong one.
      isCorrect = _wordIsDifferentAt(_selectedWordIdx!);
    }

    setState(() {
      answered = true;
      _wasCorrect = isCorrect;
    });

    widget.onAnswered(
      ExerciseResult(
        isCorrect: isCorrect,
        explanation: _explanation,
        correctAnswer:
            _correctSentence.isNotEmpty
                ? _correctSentence
                : widget.exercise.answerKey,
      ),
    );
  }

  void _submitTyped(String userInput) {
    final accepted = _acceptedAnswers;
    final match =
        accepted != null ? matchAnswer(accepted, userInput) : AnswerMatch.none;
    final isCorrect = match != AnswerMatch.none;

    setState(() {
      answered = true;
      _wasCorrect = isCorrect;
    });

    widget.onAnswered(
      ExerciseResult(
        isCorrect: isCorrect,
        explanation: _explanation,
        correctAnswer: accepted?.first ?? _correctSentence,
        supports: _errorRevealed ? const {SupportKind.hint} : const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final data = widget.exercise.data;
    final promptEn = data['prompt_en'] as String?;
    final words = _words;

    // If accepted_answers is present without options, use text input.
    final hasOptions = _options != null || _correctSentence.isNotEmpty;
    final useTextInput = _acceptedAnswers != null && !hasOptions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: promptEn ?? widget.exercise.prompt),
          const SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The sentence, word by word — tap the one that is wrong.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.card,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: t.shadow,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < words.length; i++)
                          _buildWordChip(i, words[i]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Hint reveal
                  if (_hint != null && !_errorRevealed && !answered)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _revealError,
                        icon: const Icon(Icons.lightbulb_outline, size: 18),
                        label: Text(l10n.exerciseShowHint),
                        style: TextButton.styleFrom(
                          foregroundColor: t.amberInk,
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),

                  if (_errorRevealed && !answered)
                    Text(
                      l10n.exerciseErrorInHighlighted,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: t.amberInk,
                      ),
                    ),

                  // Options after word selected
                  if (_selectedWordIdx != null && !answered) ...[
                    const SizedBox(height: 16),
                    if (_options != null) ...[
                      LessonKicker(l10n.exerciseChooseCorrectForm),
                      const SizedBox(height: 10),
                      for (int i = 0; i < _options!.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: QuizOptionTile(
                            keyLabel: String.fromCharCode(65 + i),
                            text: _options![i],
                            state:
                                _selectedOptionIdx == i
                                    ? OptionState.selected
                                    : OptionState.idle,
                            onTap: () => setState(() => _selectedOptionIdx = i),
                          ),
                        ),
                      if (_selectedOptionIdx != null)
                        KeyCta(
                          label: AppLocalizations.of(context).check,
                          onPressed: _submitWithOption,
                        ),
                    ] else if (useTextInput) ...[
                      _TextInputCorrection(
                        onSubmit: _submitTyped,
                        enabled: !answered,
                      ),
                    ] else ...[
                      KeyCta(
                        label: AppLocalizations.of(context).check,
                        onPressed: _submitWithOption,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // Feedback
          if (answered && _explanation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GrammarTipCard(
                isCorrect: _wasCorrect,
                explanation: _explanation,
                correctAnswer:
                    _correctSentence.isNotEmpty
                        ? _correctSentence
                        : widget.exercise.answerKey,
                grammarRuleId: widget.exercise.grammarRuleId,
              ),
            ),

          // Show-answer fallback
          if (_errorRevealed && !answered && !useTextInput && _options == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                onPressed: () {
                  setState(() => answered = true);
                  widget.onAnswered(
                    ExerciseResult(
                      isCorrect: false,
                      explanation: _explanation,
                      correctAnswer: _correctSentence,
                    ),
                  );
                },
                child: Text(AppLocalizations.of(context).reviewShowAnswer),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWordChip(int idx, String word) {
    final t = context.tokens;
    final isSelected = _selectedWordIdx == idx;
    final isDifferent = _wordIsDifferentAt(idx);
    final instant = MediaQuery.disableAnimationsOf(context);
    // The revealed error is struck through as well as tinted, so the hint
    // does not depend on telling amber from neutral.
    final struck = _errorRevealed && !answered && isDifferent;

    final (bg, border, fg) = switch (true) {
      _ when answered && isDifferent => (t.greenSoft, t.green, t.greenInk),
      _ when answered && isSelected => (t.redSoft, t.red, t.redInk),
      _ when answered => (t.elev, Colors.transparent, t.muted),
      _ when struck => (t.amberSoft, t.amberInk, t.amberInk),
      _ when isSelected => (t.priSoft, t.pri, t.priInk),
      _ => (t.elev, Colors.transparent, t.ink),
    };

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onWordTap(idx),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration:
                instant ? Duration.zero : const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    isSelected || struck ? FontWeight.w700 : FontWeight.w500,
                decoration: struck ? TextDecoration.lineThrough : null,
                decorationColor: fg,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text input for typing the corrected sentence.
class _TextInputCorrection extends StatefulWidget {
  final void Function(String) onSubmit;
  final bool enabled;

  const _TextInputCorrection({required this.onSubmit, this.enabled = true});

  @override
  State<_TextInputCorrection> createState() => _TextInputCorrectionState();
}

class _TextInputCorrectionState extends State<_TextInputCorrection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LessonKicker(AppLocalizations.of(context).exerciseTypeCorrectSentence),
        const SizedBox(height: 10),
        AnswerField(
          controller: _controller,
          enabled: widget.enabled,
          multiline: true,
          semanticLabel: AppLocalizations.of(context).exerciseCorrectedSentence,
          onSubmitted: widget.enabled ? widget.onSubmit : null,
        ),
        const SizedBox(height: 12),
        CzechCharBar(controller: _controller, enabled: widget.enabled),
        const SizedBox(height: 14),
        KeyCta(
          label: AppLocalizations.of(context).check,
          onPressed:
              widget.enabled ? () => widget.onSubmit(_controller.text) : null,
        ),
      ],
    );
  }
}
