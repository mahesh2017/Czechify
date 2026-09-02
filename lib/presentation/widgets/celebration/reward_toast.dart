import 'package:flutter/material.dart';

import '../../../core/feedback/celebration.dart';
import '../../../core/theme/app_tokens.dart';

/// A badge or streak milestone, announced.
///
/// These were previously written to the database and never mentioned: a
/// learner earning "Week Warrior" found out only if they happened to open the
/// Stats screen. A reward nobody is told about is not a reward.
///
/// Deliberately a toast rather than a takeover — it rides over the completion
/// screen the learner is already reading, adding to that moment instead of
/// interrupting it.
class RewardToast extends StatefulWidget {
  const RewardToast({super.key, required this.celebration});

  final Celebration celebration;

  @override
  State<RewardToast> createState() => _RewardToastState();
}

class _RewardToastState extends State<RewardToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _motionConfigured = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final instant = MediaQuery.disableAnimationsOf(context);
    if (!_motionConfigured) {
      _motionConfigured = true;
      if (instant) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    } else if (instant && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Ink variants, not raw hues: the accent is used for the title text and the
  // card border, both of which need to clear 4.5:1.
  ({String glyph, String title, String subtitle, Color accent}) _content(
    AppTokens tokens,
  ) => switch (widget.celebration) {
    BadgeEarned(:final icon, :final name, :final xpReward) => (
      glyph: icon,
      title: name,
      subtitle: 'Badge earned · +$xpReward XP',
      accent: tokens.amberInk,
    ),
    StreakExtended(:final days) => (
      glyph: '🔥',
      title: '$days-day streak',
      subtitle: 'Přijď zítra zas · come back tomorrow',
      accent: tokens.redInk,
    ),
    // The larger ceremonies own the whole screen and never appear here.
    LessonCompleted() || UnitCompleted() => (
      glyph: '⭐',
      title: 'Well done',
      subtitle: '',
      accent: tokens.priInk,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final content = _content(tokens);
    final instant = MediaQuery.disableAnimationsOf(context);
    final entry = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: entry,
          builder:
              (context, child) => Transform.translate(
                offset: Offset(0, instant ? 0 : -90 * (1 - entry.value)),
                child: Opacity(
                  opacity: instant ? 1 : _controller.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: tokens.card,
              elevation: 8,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: content.accent.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: content.accent.withValues(alpha: 0.16),
                      ),
                      child: Text(
                        content.glyph,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.title,
                            style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: tokens.ink,
                            ),
                          ),
                          if (content.subtitle.isNotEmpty)
                            Text(
                              content.subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
