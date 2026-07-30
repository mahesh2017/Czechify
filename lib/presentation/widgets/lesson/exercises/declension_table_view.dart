import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/exercise.dart';
import '../../common/lesson_ui.dart';
import '../../common/soft_ui.dart';
import 'exercise_shared.dart';

/// Declension-table exercise view (Czech-specific).
class DeclensionTableView extends StatefulWidget {
  final Exercise exercise;
  final OnExerciseAnswered onAnswered;

  const DeclensionTableView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  @override
  State<DeclensionTableView> createState() => _DeclensionTableViewState();
}

class _DeclensionTableViewState extends State<DeclensionTableView> {
  final Map<String, TextEditingController> _controllers = {};
  bool answered = false;
  int correctCount = 0;
  int totalBlanks = 0;

  @override
  void initState() {
    super.initState();
    final data = widget.exercise.data;
    final cases = (data['cases'] as List<dynamic>).cast<String>();
    totalBlanks = cases.length;
    for (final caseName in cases) {
      _controllers[caseName] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _checkAnswers() {
    final data = widget.exercise.data;
    final answerKey = Map<String, String>.from(
      data['answer_key'] as Map<String, dynamic>,
    );

    correctCount = 0;
    for (final entry in _controllers.entries) {
      final caseName = entry.key;
      final userAnswer = normalizeAnswer(entry.value.text);
      final correctAnswer = normalizeAnswer(answerKey[caseName] ?? '');
      if (userAnswer == correctAnswer) {
        correctCount++;
      }
    }

    setState(() {
      answered = true;
    });

    widget.onAnswered(
      ExerciseResult(
        isCorrect: correctCount == totalBlanks,
        explanation: 'You got $correctCount/$totalBlanks correct.',
        correctAnswer: answerKey.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.exercise.data;
    final word = data['word'] as String;
    final gender = data['gender'] as String?;
    final cases = (data['cases'] as List<dynamic>).cast<String>();
    final answerKey =
        answered
            ? Map<String, String>.from(
              data['answer_key'] as Map<String, dynamic>,
            )
            : null;

    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionPrompt(question: 'Decline $word'),
          if (gender != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: PillChip(label: gender, bg: t.violetSoft, fg: t.violetInk),
            ),
          ],
          const SizedBox(height: 20),

          // One row per case. A Table would keep the two columns aligned but
          // cannot give a 44pt row on a narrow screen without clipping the
          // field, so the rows are laid out directly.
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(24),
              boxShadow: t.shadow,
            ),
            child: Column(
              children: [
                for (final (i, caseName) in cases.indexed) ...[
                  if (i > 0) Divider(height: 1, color: t.line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            caseName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: t.muted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _CaseField(
                            controller: _controllers[caseName]!,
                            enabled: !answered,
                            verdict:
                                !answered || answerKey?[caseName] == null
                                    ? null
                                    : normalizeAnswer(
                                          _controllers[caseName]!.text,
                                        ) ==
                                        normalizeAnswer(answerKey![caseName]!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (!answered) KeyCta(label: 'Check all', onPressed: _checkAnswers),
        ],
      ),
    );
  }
}

/// One declension cell: a compact field that carries its own verdict border
/// and mark once the table has been checked.
class _CaseField extends StatelessWidget {
  const _CaseField({
    required this.controller,
    required this.enabled,
    required this.verdict,
  });

  final TextEditingController controller;
  final bool enabled;

  /// `true` right, `false` wrong, `null` not checked (or no answer key).
  final bool? verdict;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final border = switch (verdict) {
      true => t.green,
      false => t.red,
      null => t.line,
    };

    return TextField(
      controller: controller,
      enabled: enabled,
      cursorColor: t.pri,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: switch (verdict) {
          true => t.greenInk,
          false => t.redInk,
          null => t.ink,
        },
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: t.elev,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.pri, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        suffixIcon:
            verdict == null
                ? null
                : Icon(
                  verdict! ? Icons.check : Icons.close,
                  size: 18,
                  color: verdict! ? t.greenInk : t.redInk,
                ),
        suffixIconConstraints: const BoxConstraints(minWidth: 34),
      ),
    );
  }
}
