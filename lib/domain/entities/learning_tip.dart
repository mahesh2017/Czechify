import 'dart:math';

import '../../l10n/app_localizations.dart';

/// Evidence-based learning tips shown on the home screen.
///
/// Each tip rotates daily so the learner sees a fresh strategy each day.
/// Tips are grounded in spaced repetition, active recall, and motor-memory
/// research — adapted for Czech language learning.
///
/// Identity and emoji here; wording in the ARB. Which tip a learner sees is a
/// function of the date, which needs no locale, while the words are display
/// text and follow the interface language. Keeping the split means the card
/// re-reads them on every build, so changing language updates the tip in
/// place rather than at the next rotation.
class LearningTip {
  /// Position in [all], and the number in the tip's ARB keys.
  final int index;
  final String emoji;

  const LearningTip({required this.index, required this.emoji});

  static const List<LearningTip> all = [
    LearningTip(index: 1, emoji: '✍️'),
    LearningTip(index: 2, emoji: '🔁'),
    LearningTip(index: 3, emoji: '🗣️'),
    LearningTip(index: 4, emoji: '🧠'),
    LearningTip(index: 5, emoji: '🔗'),
    LearningTip(index: 6, emoji: '⏰'),
    LearningTip(index: 7, emoji: '📚'),
    LearningTip(index: 8, emoji: '😴'),
    LearningTip(index: 9, emoji: '🎯'),
    LearningTip(index: 10, emoji: '🎵'),
  ];

  String title(AppLocalizations l10n) => switch (index) {
    1 => l10n.tip1Title,
    2 => l10n.tip2Title,
    3 => l10n.tip3Title,
    4 => l10n.tip4Title,
    5 => l10n.tip5Title,
    6 => l10n.tip6Title,
    7 => l10n.tip7Title,
    8 => l10n.tip8Title,
    9 => l10n.tip9Title,
    _ => l10n.tip10Title,
  };

  String body(AppLocalizations l10n) => switch (index) {
    1 => l10n.tip1Body,
    2 => l10n.tip2Body,
    3 => l10n.tip3Body,
    4 => l10n.tip4Body,
    5 => l10n.tip5Body,
    6 => l10n.tip6Body,
    7 => l10n.tip7Body,
    8 => l10n.tip8Body,
    9 => l10n.tip9Body,
    _ => l10n.tip10Body,
  };

  /// The tip for today, so every learner on a given day sees the same one.
  static LearningTip forToday() {
    final dayOfYear = DateTime.now().difference(DateTime(2026)).inDays;
    return all[dayOfYear % all.length];
  }

  /// Pick a random tip (for variety when the user refreshes).
  static LearningTip random() {
    final rng = Random();
    return all[rng.nextInt(all.length)];
  }
}
