import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/learning_tip.dart';
import 'motion_widgets.dart';
import 'soft_ui.dart';

/// A card on the home screen that shows a daily evidence-based learning tip.
///
/// The tip rotates daily (deterministic by day-of-year). Tapping the card
/// shows a new random tip immediately — for learners who want variety.
class LearningTipCard extends StatefulWidget {
  const LearningTipCard({super.key});

  @override
  State<LearningTipCard> createState() => _LearningTipCardState();
}

class _LearningTipCardState extends State<LearningTipCard> {
  late LearningTip _tip;

  @override
  void initState() {
    super.initState();
    _tip = LearningTip.forToday();
  }

  void _shuffle() {
    setState(() {
      LearningTip next;
      do {
        next = LearningTip.random();
      } while (next.title == _tip.title && LearningTip.all.length > 1);
      _tip = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SoftCard(
      onTap: _shuffle,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: MotionSwap(
        alignment: Alignment.topCenter,
        child: Row(
          key: ValueKey(_tip.title),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: t.amberSoft,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(_tip.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '💡 Tip of the day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: t.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.refresh, size: 14, color: t.faint),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tip.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tip.body,
                    style: TextStyle(fontSize: 15, color: t.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
