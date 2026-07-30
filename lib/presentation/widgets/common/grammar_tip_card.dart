import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:go_router/go_router.dart';
import 'lesson_ui.dart';

/// The inline answer verdict, for the exercises that resolve in place rather
/// than handing the result up to the lesson player's [FeedbackSheet].
///
/// Green means correct, coral means wrong and neutral means the answer was
/// shown rather than missed. Amber is not used here at all — in this palette
/// amber means streak and XP, so tinting a mistake amber said "reward" while
/// the copy said "wrong".
class GrammarTipCard extends StatelessWidget {
  final bool isCorrect;
  final bool isSkipped;
  final String? explanation;
  final String? correctAnswer;

  /// When set, shows a link into the grammar reference for this rule.
  final String? grammarRuleId;

  const GrammarTipCard({
    super.key,
    required this.isCorrect,
    this.isSkipped = false,
    this.explanation,
    this.correctAnswer,
    this.grammarRuleId,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final (
      Color bg,
      Color hue,
      Color ink,
      IconData icon,
      String title,
    ) = switch ((isSkipped, isCorrect)) {
      (true, _) => (
        t.elev,
        t.muted,
        t.ink,
        Icons.visibility_outlined,
        'Skipped — no score or heart change',
      ),
      (_, true) => (t.greenSoft, t.green, t.greenInk, Icons.check, 'Správně!'),
      _ => (t.redSoft, t.red, t.redInk, Icons.close, 'Not quite'),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: t.onFill),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
          // Only worth stating when they did not produce it themselves.
          if (!isCorrect &&
              correctAnswer != null &&
              correctAnswer!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LessonKicker('Correct'),
                  const SizedBox(height: 4),
                  Text(
                    correctAnswer!,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (explanation != null && explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              explanation!,
              style: TextStyle(fontSize: 15, height: 1.5, color: t.ink),
            ),
          ],
          if (grammarRuleId != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/grammar?rule=$grammarRuleId'),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('View grammar rule'),
                style: TextButton.styleFrom(
                  foregroundColor: t.ink,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
