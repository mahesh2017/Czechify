import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../providers/tts_providers.dart';
import '../../common/lesson_image.dart';
import '../../common/lesson_ui.dart';
import 'exercise_shared.dart';

/// Dialogue completion exercise view.
class DialogueView extends ConsumerStatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const DialogueView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  ConsumerState<DialogueView> createState() => _DialogueViewState();
}

class _DialogueViewState extends ConsumerState<DialogueView> {
  final List<TextEditingController> _controllers = [];
  bool answered = false;
  bool? isCorrect;

  List<Map<String, dynamic>> get _lines =>
      (widget.exercise.data['lines'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

  List<List<String>> get _blankAnswers =>
      (widget.exercise.data['blank_answers'] as List<dynamic>)
          .map((answers) => (answers as List<dynamic>).cast<String>())
          .toList();

  List<String> get _spokenLines {
    var blankIndex = 0;
    return [
      for (final line in _lines)
        (line['text'] as String).replaceAllMapped(RegExp(r'___'), (_) {
          final answer = _blankAnswers[blankIndex].first;
          blankIndex++;
          return answer;
        }),
    ];
  }

  String get _fullDialogueText => _spokenLines.join(' ');

  @override
  void initState() {
    super.initState();
    final blankCount = _lines.fold<int>(
      0,
      (count, line) => count + '___'.allMatches(line['text'] as String).length,
    );
    _controllers.addAll(
      List.generate(blankCount, (_) => TextEditingController()),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _allFilled =>
      _controllers.isNotEmpty &&
      _controllers.every((controller) => controller.text.trim().isNotEmpty);

  /// Build dialogue lines with an inline field for every `___` marker.
  List<Widget> _buildDialogueLines(
    List<Map<String, dynamic>> lines,
    BuildContext context,
  ) {
    int blankCounter = 0;
    final spokenLines = _spokenLines;
    return lines.indexed.map((entry) {
      final lineIndex = entry.$1;
      final line = entry.$2;
      final text = line['text'] as String;
      final segments = text.split('___');
      final containsBlank = segments.length > 1;
      final isUser = line['speaker'] == 'you' || containsBlank;
      final inline = <Widget>[];
      for (var index = 0; index < segments.length; index++) {
        if (segments[index].isNotEmpty) {
          inline.add(Text(segments[index]));
        }
        if (index < segments.length - 1) {
          final controller = _controllers[blankCounter++];
          inline.add(
            SizedBox(
              width: 180,
              child: TextField(
                controller: controller,
                enabled: !answered,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  hintText: AppLocalizations.of(context).exerciseYourAnswer,
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                onSubmitted:
                    answered
                        ? null
                        : (_) {
                          if (_allFilled) _checkAnswer();
                        },
              ),
            ),
          );
        }
      }

      final t = context.tokens;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUser ? t.priSoft : t.card,
              border: Border.all(color: isUser ? Colors.transparent : t.line),
              // Notched toward its own speaker, so who is talking is legible
              // from the shape alone.
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: Radius.circular(isUser ? 24 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (line['speaker'] as String).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: isUser ? t.priInk : t.faint,
                        ),
                      ),
                    ),
                    TtsButton(text: spokenLines[lineIndex], size: 19),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: inline,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _checkAnswer() {
    if (!_allFilled || answered) return;
    final answers = _blankAnswers;
    final correct =
        answers.length == _controllers.length &&
        List.generate(_controllers.length, (index) {
          final userAnswer = normalizeAnswer(_controllers[index].text);
          return answers[index].map(normalizeAnswer).contains(userAnswer);
        }).every((matches) => matches);

    setState(() {
      answered = true;
      isCorrect = correct;
    });

    widget.onAnswered(
      ExerciseResult(
        isCorrect: correct,
        explanation: widget.exercise.data['explanation'] as String?,
        correctAnswer: answers.map((options) => options.first).join(' | '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final scenario = data['scenario'] as String?;
    final image = (data['image'] as String?)?.trim();
    final imageLabel = (data['image_label'] as String?)?.trim();

    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: widget.exercise.prompt),
          if (scenario != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.elev,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, size: 16, color: t.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scenario,
                      style: TextStyle(fontSize: 14, height: 1.4, color: t.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          if (image != null && image.isNotEmpty) ...[
            LessonImage(
              asset: image,
              aspectRatio: 5 / 4,
              semanticLabel:
                  imageLabel == null || imageLabel.isEmpty ? null : imageLabel,
            ),
            const SizedBox(height: 14),
          ],

          ListenPanel(
            label: AppLocalizations.of(context).listen,
            onPlay: () => ref.read(czechTtsProvider).speak(_fullDialogueText),
            onSlow:
                () => ref.read(czechTtsProvider).speakSlow(_fullDialogueText),
          ),
          const SizedBox(height: 18),

          // Dialogue lines
          ..._buildDialogueLines(_lines, context),

          const SizedBox(height: 18),
          if (!answered)
            KeyCta(
              label: AppLocalizations.of(context).check,
              onPressed: _allFilled ? _checkAnswer : null,
            ),
        ],
      ),
    );
  }
}
