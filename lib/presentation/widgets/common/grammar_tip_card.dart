import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:go_router/go_router.dart';

/// Grammar tip card shown after answering — displays explanation on wrong answers,
/// positive feedback on correct ones.
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
    if (isSkipped) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.skip_next),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Skipped — no score or heart change',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (explanation != null) ...[
                    const SizedBox(height: 4),
                    Text(explanation!),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (isCorrect && explanation == null) {
      // Just positive feedback
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.greenSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.green.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: t.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Správně! Correct!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: t.green,
                    ),
                  ),
                  if (explanation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        explanation!,
                        style: TextStyle(color: t.green, fontSize: 15),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Wrong answer — show explanation
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect ? t.greenSoft : t.amberSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isCorrect ? t.green : t.amber).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.lightbulb,
                color: isCorrect ? t.green : t.amber,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isCorrect ? 'Správně! Correct!' : 'Not quite right',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? t.green : t.amber,
                  ),
                ),
              ),
            ],
          ),
          if (correctAnswer != null && !isCorrect) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.greenSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Correct answer: $correctAnswer',
                style: TextStyle(color: t.green, fontWeight: FontWeight.w500),
              ),
            ),
          ],
          if (explanation != null) ...[
            const SizedBox(height: 12),
            Text(
              '💡 Grammar tip:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCorrect ? t.green : t.amber,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              explanation!,
              style: TextStyle(
                color: isCorrect ? t.green : t.amber,
                fontSize: 15,
              ),
            ),
          ],
          if (grammarRuleId != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/grammar?rule=$grammarRuleId'),
                icon: const Icon(Icons.menu_book, size: 18),
                label: const Text('View grammar rule'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
