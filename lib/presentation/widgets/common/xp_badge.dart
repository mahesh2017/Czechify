import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/engines/gamification_engine.dart';
import '../../../domain/entities/gamification_state.dart';
import '../../providers/gamification_providers.dart';

/// XP badge widget — shows total XP and current league from persisted state.
class XpBadge extends ConsumerWidget {
  const XpBadge({super.key});

  static final _engine = GamificationEngine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamification = ref.watch(gamificationProvider);
    final totalXp = gamification.totalXp;
    final league = _engine.getLeague(totalXp);

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
            color: _leagueColor(league).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _leagueColor(league).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            league.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _leagueColor(league),
            ),
          ),
        ),
      ],
    );
  }

  Color _leagueColor(League league) {
    return switch (league) {
      League.bronze => const Color(0xFFCD7F32),
      League.silver => const Color(0xFF9AA0A6),
      League.gold => const Color(0xFFD4A017),
      League.platinum => const Color(0xFF4FB3BF),
      League.diamond => const Color(0xFF5B8DEF),
    };
  }
}
