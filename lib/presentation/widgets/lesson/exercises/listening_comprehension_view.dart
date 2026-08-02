import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/learning_evidence.dart';
import '../../../providers/tts_providers.dart';
import '../../common/lesson_ui.dart';
import 'exercise_shared.dart';

/// Listening comprehension exercise — listen to a Czech dialogue/recording,
/// then answer multiple-choice questions.
///
/// Until audio files are generated, the transcript is shown as a fallback
/// with a TTS button to read it aloud.
class ListeningComprehensionView extends ConsumerStatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const ListeningComprehensionView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  ConsumerState<ListeningComprehensionView> createState() =>
      _ListeningComprehensionViewState();
}

class _ListeningComprehensionViewState
    extends ConsumerState<ListeningComprehensionView> {
  int _playCount = 0;
  bool _transcriptRevealed = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final transcriptCz = data['transcript_cz'] as String? ?? '';
    final promptEn = data['prompt_en'] as String? ?? widget.exercise.prompt;
    final image = (data['image'] as String?)?.trim();
    final imageLabel = (data['image_label'] as String?)?.trim();
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: promptEn),
          const SizedBox(height: 16),

          if (image != null && image.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  cacheWidth: 1024,
                  semanticLabel: imageLabel == null || imageLabel.isEmpty
                      ? null
                      : imageLabel,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Listen first: the audio is the exercise, so it gets the hero.
          if (transcriptCz.isNotEmpty)
            ListenPanel(
              label: _playCount == 0 ? l10n.listen : l10n.audioPlayAgain,
              onPlay: () {
                setState(() => _playCount++);
                ref.read(czechTtsProvider).speak(transcriptCz);
              },
              onSlow: () {
                setState(() => _playCount++);
                ref.read(czechTtsProvider).speakSlow(transcriptCz);
              },
            ),
          const SizedBox(height: 10),
          Text(
            l10n.exerciseGistFirstNote,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.45, color: t.faint),
          ),
          const SizedBox(height: 16),

          if (!_transcriptRevealed)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: transcriptCz.isEmpty
                    ? null
                    : () => setState(() => _transcriptRevealed = true),
                icon: const Icon(Icons.subtitles_outlined, size: 18),
                label: Text(l10n.exerciseRevealTranscript),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.elev,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                transcriptCz,
                style: TextStyle(fontSize: 15, height: 1.6, color: t.ink),
              ),
            ),
          const SizedBox(height: 16),

          // The questions own the rest of the screen: they scroll on their own
          // and their Check action stays pinned, rather than being pushed below
          // the fold by a long question list.
          Expanded(
            child: _ListeningQuestions(
              exerciseId: widget.exercise.id,
              data: data,
              onComplete: (isCorrect, explanation, correctAnswer) {
                widget.onAnswered(
                  ExerciseResult(
                    isCorrect: isCorrect,
                    explanation: explanation,
                    correctAnswer: correctAnswer,
                    supports: {
                      if (_playCount > 1) SupportKind.replay,
                      if (_transcriptRevealed) SupportKind.transcript,
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Questions section extracted from reading comprehension logic.
class _ListeningQuestions extends StatefulWidget {
  final int exerciseId;
  final Map<String, dynamic> data;
  final void Function(
    bool isCorrect,
    String? explanation,
    String? correctAnswer,
  )
  onComplete;

  const _ListeningQuestions({
    required this.exerciseId,
    required this.data,
    required this.onComplete,
  });

  @override
  State<_ListeningQuestions> createState() => _ListeningQuestionsState();
}

class _ListeningQuestionsState extends State<_ListeningQuestions> {
  final List<int?> _selectedAnswers = [];
  late List<Map<String, dynamic>> _presentedQuestions;
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    _prepareQuestions();
  }

  void _prepareQuestions() {
    final raw = widget.data['questions'] as List<dynamic>? ?? [];
    _presentedQuestions = [
      for (final (index, question) in raw.cast<Map<String, dynamic>>().indexed)
        shuffledQuestion(question, seed: widget.exerciseId * 31 + index),
    ];
    _selectedAnswers
      ..clear()
      ..addAll(List.filled(_presentedQuestions.length, null));
  }

  List<Map<String, dynamic>> get _questions => _presentedQuestions;

  @override
  void didUpdateWidget(covariant _ListeningQuestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId) {
      submitted = false;
      _prepareQuestions();
    }
  }

  bool get _allAnswered =>
      _questions.isNotEmpty && _selectedAnswers.every((a) => a != null);

  int get _correctCount {
    int c = 0;
    for (int i = 0; i < _questions.length; i++) {
      final correctIdx = (_questions[i]['correct_index'] as num).toInt();
      if (_selectedAnswers[i] == correctIdx) c++;
    }
    return c;
  }

  bool get _allCorrect =>
      _questions.isNotEmpty && _correctCount == _questions.length;

  void _submit() {
    if (_questions.isEmpty) {
      setState(() => submitted = true);
      widget.onComplete(
        false,
        AppLocalizations.of(context).exerciseNoQuestionsAvailable,
        null,
      );
      return;
    }
    setState(() => submitted = true);
    widget.onComplete(
      _allCorrect,
      _allCorrect
          ? AppLocalizations.of(context).exerciseAllAnsweredCorrectly
          : AppLocalizations.of(
              context,
            ).exerciseYouGotCorrect(_correctCount, _questions.length),
      _questions
          .map(
            (q) =>
                (q['options'] as List<dynamic>)[(q['correct_index'] as num)
                        .toInt()]
                    as String,
          )
          .join(', '),
    );
  }

  void _retry() {
    setState(() {
      for (int i = 0; i < _selectedAnswers.length; i++) {
        _selectedAnswers[i] = null;
      }
      submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    // Empty-questions error state
    if (_questions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.redSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: t.redInk, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).exerciseNoQuestions,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: t.redInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (submitted)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(AppLocalizations.of(context).retry),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, qIdx) =>
                _buildQuestion(context, qIdx, theme),
          ),
        ),
        if (_allAnswered && !submitted)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: KeyCta(
              label: AppLocalizations.of(context).exerciseCheckAnswers,
              onPressed: _submit,
            ),
          ),
        if (submitted) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  _allCorrect ? Icons.check_circle : Icons.error_outline,
                  color: _allCorrect ? t.greenInk : t.redInk,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _allCorrect
                        ? AppLocalizations.of(context).exerciseAllCorrect
                        : AppLocalizations.of(context).exerciseCorrectOfTotal(
                            _correctCount,
                            _questions.length,
                          ),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _allCorrect ? t.greenInk : t.redInk,
                    ),
                  ),
                ),
                if (!_allCorrect)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: kRowButtonMinSize,
                    ),
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(AppLocalizations.of(context).retry),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuestion(BuildContext context, int qIdx, ThemeData theme) {
    final t = context.tokens;
    final q = _questions[qIdx];
    final questionEn = q['question_en'] as String? ?? '';
    final options = (q['options'] as List<dynamic>).cast<String>();
    final correctIdx = (q['correct_index'] as num).toInt();
    final selected = _selectedAnswers[qIdx];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.line),
        boxShadow: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LessonKicker(
            AppLocalizations.of(context).exerciseQuestionNumber(qIdx + 1),
            color: t.pri,
          ),
          const SizedBox(height: 6),
          Text(
            questionEn,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < options.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == options.length - 1 ? 0 : 8),
              child: QuizOptionTile(
                keyLabel: String.fromCharCode(65 + i),
                text: options[i],
                state: optionState(
                  index: i,
                  correctIndex: correctIdx,
                  selectedIndex: selected,
                  answered: submitted,
                ),
                onTap: submitted
                    ? null
                    : () => setState(() => _selectedAnswers[qIdx] = i),
              ),
            ),
        ],
      ),
    );
  }
}
