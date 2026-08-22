import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/engines/gamification_engine.dart';
import '../../../domain/entities/gamification_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/gamification_providers.dart';

/// XP badge widget — shows total XP and current league from persisted state.
class XpBadge extends ConsumerWidget {
  const XpBadge({super.key});

  static final _engine = GamificationEngine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamification = ref.watch(gamificationProvider);
    final totalXp = gamification.totalXp;
    final rank = _engine.rankFor(totalXp);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, color: context.tokens.amber, size: 18),
        const SizedBox(width: 4),
        Text(
          '$totalXp',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: context.tokens.amber,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _rankColor(rank).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _rankColor(rank).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            rankLabelFor(rank, AppLocalizations.of(context)),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _rankColor(rank),
            ),
          ),
        ),
      ],
    );
  }

  Color _rankColor(Rank rank) {
    return switch (rank) {
      Rank.bronze => const Color(0xFFCD7F32),
      Rank.silver => const Color(0xFF9AA0A6),
      Rank.gold => const Color(0xFFD4A017),
      Rank.platinum => const Color(0xFF4FB3BF),
      Rank.diamond => const Color(0xFF5B8DEF),
    };
  }
}

/// The tier's name in the learner's language.
///
/// These were English literals on the [Rank] enum itself, so a Czech UI showed
/// "Bronze" beside fully translated chrome. Same shape as the pronunciation
/// coaching: the domain names the tier, the wording lives with the rest of the
/// translations.
String rankLabelFor(Rank rank, AppLocalizations l10n) => switch (rank) {
  Rank.bronze => l10n.rankBronze,
  Rank.silver => l10n.rankSilver,
  Rank.gold => l10n.rankGold,
  Rank.platinum => l10n.rankPlatinum,
  Rank.diamond => l10n.rankDiamond,
};
