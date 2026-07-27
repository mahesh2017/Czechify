import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/learning_evidence.dart';
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
    final acceptedAnswers =
        widget.exercise.answerKey != null
            ? [widget.exercise.answerKey!]
            : <String>[];

    // Simple keyword-based checking
    final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    final meetsMinWords = _minWords == null || wordCount >= _minWords!;
    final hasContent = text.isNotEmpty;

    // Check keyword overlap if accepted answers exist
    bool keywordMatched = false;
    if (acceptedAnswers.isNotEmpty && hasContent) {
      final userWords = text.toLowerCase().split(RegExp(r'\s+')).toSet();
      for (final answer in acceptedAnswers) {
        final answerWords = answer.toLowerCase().split(RegExp(r'\s+')).toSet();
        final overlap = userWords.intersection(answerWords);
        if (overlap.length / answerWords.length >= 0.5) {
          keywordMatched = true;
          break;
        }
      }
    }

    final isScored = acceptedAnswers.isNotEmpty;
    final isCorrect = isScored && hasContent && meetsMinWords && keywordMatched;

    final feedback = StringBuffer();
    feedback.write('You wrote $wordCount words. ');
    if (_minWords != null) {
      feedback.write(
        meetsMinWords
            ? '✓ Meets the $_minWords-word minimum. '
            : '✗ Needs at least $_minWords words. ',
      );
    }
    if (acceptedAnswers.isNotEmpty) {
      feedback.write(
        keywordMatched
            ? 'Good keyword coverage. '
            : 'Key phrases not detected. ',
      );
    } else {
      feedback.write(
        'Completed as unscored writing practice; no automatic proficiency '
        'claim is made. ',
      );
    }
    if (_revisionStage && text != _firstDraft) {
      feedback.write('✓ You revised the first draft. ');
    }

    setState(() {
      answered = true;
      _isCorrect = isCorrect;
      _wordCount = wordCount;
      _meetsMinWords = meetsMinWords;
      _feedbackText = feedback.toString().trim();
    });

    final supports =
        _showKeyVocab ? const {SupportKind.hint} : const <SupportKind>{};
    widget.onAnswered(
      isScored
          ? ExerciseResult(
            isCorrect: isCorrect,
            explanation: _feedbackText,
            correctAnswer: _sampleAnswer ?? acceptedAnswers.firstOrNull,
            supports: supports,
          )
          : ExerciseResult.skipped(
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prompt
          Text(
            _prompt,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_promptCz != null) ...[
            const SizedBox(height: 4),
            Text(
              _promptCz!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_minWords != null) ...[
            const SizedBox(height: 8),
            Text(
              'Write at least $_minWords words.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),

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
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Show vocabulary support'),
              ),
            ),
          ],
          if (_keyVocab != null && _keyVocab!.isNotEmpty && _showKeyVocab) ...[
            Row(
              children: [
                Text(
                  'Try using: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children:
                        _keyVocab!
                            .map(
                              (v) => Chip(
                                label: Text(
                                  v,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          if (_revisionStage && !answered) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Revise: check the communicative goal, verb forms, case '
                'endings, word order, and register. Improve the message, not '
                'only its length.',
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Writing area
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !answered,
              decoration: const InputDecoration(
                hintText: 'Write your answer in Czech...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(16),
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(height: 8),
          if (!answered) CzechCharBar(controller: _controller),

          // Submit
          if (!answered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: FilledButton(
                onPressed: _revisionStage ? _submit : _reviewDraft,
                child: Text(
                  _revisionStage ? 'Submit revision' : 'Review draft',
                ),
              ),
            ),

          // Word count (live, before submission)
          if (!answered)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_controller.text.trim().isEmpty ? 0 : _controller.text.trim().split(RegExp(r'\s+')).length} words',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // Feedback after submission
          if (answered) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isCorrect ? correctTint(context) : wrongTint(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isCorrect ? t.green : t.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isCorrect ? Icons.check_circle : Icons.cancel,
                        color: _isCorrect ? t.green : t.red,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.exercise.answerKey == null
                            ? 'Writing cycle complete'
                            : _isCorrect
                            ? 'Good!'
                            : 'Needs improvement',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _isCorrect ? t.green : t.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_feedbackText, style: theme.textTheme.bodyMedium),
                  if (_minWords != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Word count: $_wordCount / min $_minWords ${_meetsMinWords ? "✓" : "✗"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Show sample/reference answer if available
            if (_sampleAnswer != null || _answerKey != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reference answer',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _sampleAnswer ?? _answerKey!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.5,
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
              label: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }
}
