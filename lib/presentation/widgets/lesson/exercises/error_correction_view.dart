import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../common/grammar_tip_card.dart';
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
    final theme = Theme.of(context);
    final data = widget.exercise.data;
    final promptEn = data['prompt_en'] as String?;
    final words = _words;

    // If accepted_answers is present without options, use text input.
    final hasOptions = _options != null || _correctSentence.isNotEmpty;
    final useTextInput = _acceptedAnswers != null && !hasOptions;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prompt
          Text(
            promptEn ?? widget.exercise.prompt,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // Sentence with tappable words
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (int i = 0; i < words.length; i++)
                        _buildWordChip(i, words[i], theme),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Hint reveal
                  if (_hint != null && !_errorRevealed && !answered)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _revealError,
                        icon: const Icon(Icons.lightbulb_outline, size: 18),
                        label: const Text('Show hint'),
                      ),
                    ),

                  if (_errorRevealed && !answered)
                    Text(
                      'The error is in one of the highlighted words above.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: t.amber,
                      ),
                    ),

                  // Options after word selected
                  if (_selectedWordIdx != null && !answered) ...[
                    const SizedBox(height: 16),
                    if (_options != null) ...[
                      Text(
                        'Choose the correct form:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (int i = 0; i < _options!.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton(
                            onPressed:
                                () => setState(() => _selectedOptionIdx = i),
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  _selectedOptionIdx == i
                                      ? theme.colorScheme.primaryContainer
                                      : null,
                              side: BorderSide(
                                color:
                                    _selectedOptionIdx == i
                                        ? theme.colorScheme.primary
                                        : t.line,
                              ),
                            ),
                            child: Text(_options![i]),
                          ),
                        ),
                      if (_selectedOptionIdx != null)
                        FilledButton(
                          onPressed: _submitWithOption,
                          child: Text(AppLocalizations.of(context).check),
                        ),
                    ] else if (useTextInput) ...[
                      _TextInputCorrection(
                        onSubmit: _submitTyped,
                        enabled: !answered,
                      ),
                    ] else ...[
                      FilledButton(
                        onPressed: _submitWithOption,
                        child: Text(AppLocalizations.of(context).check),
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

  Widget _buildWordChip(int idx, String word, ThemeData theme) {
    final t = context.tokens;
    final isSelected = _selectedWordIdx == idx;
    final isDifferent = _wordIsDifferentAt(idx);

    Color? bg;
    Color? border;
    if (answered) {
      if (isDifferent) {
        bg = t.greenSoft;
        border = t.green;
      } else if (isSelected) {
        bg = t.redSoft;
        border = t.red;
      } else {
        bg = t.elev;
        border = Colors.transparent;
      }
    } else if (_errorRevealed && isDifferent) {
      bg = t.amberSoft;
      border = t.amber;
    } else if (isSelected) {
      bg = theme.colorScheme.primaryContainer;
      border = theme.colorScheme.primary;
    } else {
      bg = t.elev;
    }

    return GestureDetector(
      onTap: () => _onWordTap(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: border != null ? Border.all(color: border, width: 2) : null,
        ),
        child: Text(
          word,
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                isSelected || _errorRevealed && isDifferent
                    ? FontWeight.w600
                    : FontWeight.normal,
            decoration:
                _errorRevealed && isDifferent
                    ? TextDecoration.lineThrough
                    : null,
            color: _errorRevealed && isDifferent ? t.amber : null,
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
        Text(
          'Type the correct sentence:',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            hintText: 'Write the corrected sentence...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          textInputAction: TextInputAction.done,
          onSubmitted: widget.enabled ? (v) => widget.onSubmit(v) : null,
        ),
        const SizedBox(height: 8),
        CzechCharBar(controller: _controller, enabled: widget.enabled),
        const SizedBox(height: 12),
        FilledButton(
          onPressed:
              widget.enabled ? () => widget.onSubmit(_controller.text) : null,
          child: Text(AppLocalizations.of(context).check),
        ),
      ],
    );
  }
}
