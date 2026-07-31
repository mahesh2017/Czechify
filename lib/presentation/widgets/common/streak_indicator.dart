import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/gamification_providers.dart';

/// Streak indicator widget — shows current streak from persisted state.
class StreakIndicator extends ConsumerWidget {
  const StreakIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamification = ref.watch(gamificationProvider);
    final streak = gamification.currentStreak;

    return Semantics(
      container: true,
      label: AppLocalizations.of(context).a11yStreak(streak),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: streak > 0 ? context.tokens.amber : context.tokens.line,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: streak > 0 ? context.tokens.amber : context.tokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}
