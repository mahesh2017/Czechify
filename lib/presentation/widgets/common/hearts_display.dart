import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/gamification_providers.dart';

/// Hearts display widget — shows current hearts from persisted state.
class HeartsDisplay extends ConsumerWidget {
  const HeartsDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamification = ref.watch(gamificationProvider);
    final hearts = gamification.hearts;
    final maxHearts = gamification.maxHearts;
    final isFull = hearts >= maxHearts;

    // One label for the pair. Without this a screen reader reads a bare
    // number with no idea it means hearts.
    return Semantics(
      container: true,
      label: AppLocalizations.of(context).a11yHearts(hearts),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite,
            color: hearts > 0 ? context.tokens.red : context.tokens.line,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '$hearts',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: hearts > 0 ? context.tokens.red : context.tokens.muted,
            ),
          ),
          if (!isFull) ...[
            const SizedBox(width: 4),
            Icon(Icons.access_time, size: 12, color: context.tokens.line),
          ],
        ],
      ),
    );
  }
}
