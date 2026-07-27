import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/review_providers.dart';
import '../../providers/tts_providers.dart';
import '../../../domain/entities/flashcard.dart';
import '../../../domain/entities/srs_card.dart';
import '../../../domain/engines/srs_scheduler.dart';
import '../../../core/theme/app_tokens.dart';
import '../../widgets/common/gender_pill.dart';
import '../../widgets/common/soft_ui.dart';

/// SRS review screen — flashcard interface with simplified SM-2 ratings.
class SrsReviewScreen extends ConsumerStatefulWidget {
  const SrsReviewScreen({super.key});

  @override
  ConsumerState<SrsReviewScreen> createState() => _SrsReviewScreenState();
}

class _SrsReviewScreenState extends ConsumerState<SrsReviewScreen>
    with SingleTickerProviderStateMixin {
  bool _loaded = false;
  String _productionAttempt = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(reviewSessionProvider.notifier).loadDueCards();
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(reviewSessionProvider);

    if (!_loaded || session.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // No due cards
    if (session.dueCards.isEmpty && !session.isComplete) {
      return _NoDueCardsScreen(
        onRefresh: () {
          ref.read(reviewSessionProvider.notifier).loadDueCards();
        },
      );
    }

    // Session complete
    if (session.isComplete) {
      return _ReviewCompleteScreen(
        session: session,
        onRestart: () {
          ref.read(reviewSessionProvider.notifier).restart();
        },
        onExit: () => context.go('/'),
      );
    }

    // Active review
    final card = session.currentCard;
    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: Text('No cards available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: session.progress,
                  minHeight: 8,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${session.remainingCards} left',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        leading: IconButton(
          tooltip: AppLocalizations.of(context).a11yClose,
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirm(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress info
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Text(
                AppLocalizations.of(
                  context,
                ).reviewCardOf(session.currentIndex + 1, session.totalCards),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
              ),
            ),
            const SizedBox(height: 16),

            // Flashcard
            Expanded(
              child: _FlashcardView(
                card: card.flashcard,
                direction: card.direction,
                isFlipped: session.isFlipped,
                onFlip:
                    card.direction != CardDirection.enToCz ||
                            _productionAttempt.trim().isNotEmpty
                        ? () {
                          ref.read(reviewSessionProvider.notifier).flipCard();
                        }
                        : null,
              ),
            ),

            if (!session.isFlipped && card.direction == CardDirection.enToCz)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  key: ValueKey(card.flashcard.id),
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Retrieve the Czech expression',
                    helperText: 'Make an overt attempt before revealing.',
                  ),
                  onChanged:
                      (value) => setState(() => _productionAttempt = value),
                ),
              ),

            // Rating buttons (only after flip)
            if (session.isFlipped)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (session.commitError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        session.commitError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _RatingButtons(
                    intervals: _intervalLabels(card.srs),
                    enabled: !session.isCommitting,
                    onRate: (rating) async {
                      await ref
                          .read(reviewSessionProvider.notifier)
                          .rateCard(rating);
                      if (mounted) setState(() => _productionAttempt = '');
                    },
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton.icon(
                  onPressed:
                      card.direction != CardDirection.enToCz ||
                              _productionAttempt.trim().isNotEmpty
                          ? () {
                            ref.read(reviewSessionProvider.notifier).flipCard();
                          }
                          : null,
                  icon: const Icon(Icons.flip),
                  label: Text(AppLocalizations.of(context).reviewShowAnswer),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Honest interval hints computed from the real scheduler for the
  /// current card. "Again" re-appears within this session, so it shows
  /// "Soon" rather than a day count.
  Map<Rating, String> _intervalLabels(SrsCard card) {
    final scheduler = SrsScheduler();
    final now = DateTime.now();
    String fmt(Rating r) {
      if (r == Rating.again) return 'Soon';
      final days = scheduler.previewIntervalDays(card, r, now);
      if (days <= 0) return '<1d';
      if (days < 30) return '${days}d';
      if (days < 365) return '~${(days / 30).round()}mo';
      return '~${(days / 365).round()}y';
    }

    return {
      Rating.again: fmt(Rating.again),
      Rating.hard: fmt(Rating.hard),
      Rating.good: fmt(Rating.good),
      Rating.easy: fmt(Rating.easy),
    };
  }

  void _showExitConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context).reviewEndTitle),
            content: Text(AppLocalizations.of(context).reviewEndBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).reviewStay),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/');
                },
                child: Text(AppLocalizations.of(context).reviewEnd),
              ),
            ],
          ),
    );
  }
}

/// The flashcard view. The front depends on the card's direction —
/// recognition (CZ), production (EN), or audio-only — and the back always
/// shows the full word with translation, IPA, and example.
class _FlashcardView extends ConsumerWidget {
  final Flashcard card;
  final CardDirection direction;
  final bool isFlipped;
  final VoidCallback? onFlip;

  const _FlashcardView({
    required this.card,
    required this.direction,
    required this.isFlipped,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isFlipped ? null : onFlip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder:
                  (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
              child: KeyedSubtree(
                key: ValueKey(isFlipped),
                child:
                    isFlipped
                        ? _buildBack(context, ref)
                        : switch (direction) {
                          CardDirection.czToEn => _buildFront(context, ref),
                          CardDirection.enToCz => _buildFrontProduction(
                            context,
                          ),
                          CardDirection.audio => _buildFrontAudio(context, ref),
                        },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Small pill naming the recall direction of the current card.
  Widget _directionBadge(String label, {required Color fg, required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 14)),
    );
  }

  /// Shared "tap the card to see the answer" affordance, identical on all
  /// three card fronts.
  Widget _tapToReveal(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app, color: t.faint, size: 20),
        const SizedBox(width: 8),
        Text(
          AppLocalizations.of(context).reviewTapToReveal,
          style: TextStyle(color: t.faint, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildFront(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Gender badge
        if (card.gender != null)
          GenderPill(gender: card.gender!, abbreviated: false),
        const SizedBox(height: 24),

        // Czech word
        Text(
          card.wordCz,
          style: Theme.of(
            context,
          ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),

        // IPA
        if (card.ipa != null) ...[
          const SizedBox(height: 12),
          Text(
            '/${card.ipa}/',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.tokens.muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],

        const SizedBox(height: 40),

        // Hint to flip
        _tapToReveal(context),

        // Audio button — speaks the Czech word via TTS
        const SizedBox(height: 16),
        IconButton(
          tooltip: AppLocalizations.of(context).a11yPlayAudio,
          onPressed: () {
            ref.read(czechTtsProvider).speak(card.wordCz);
          },
          icon: const Icon(Icons.volume_up, size: 32),
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  /// Production front — English shown, learner recalls the Czech word.
  Widget _buildFrontProduction(BuildContext context) {
    final contextualPrompt = _contextualCloze(card);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _directionBadge(
          'EN → CZ',
          fg: context.tokens.violet,
          bg: context.tokens.violetSoft,
        ),
        const SizedBox(height: 24),
        Text(
          contextualPrompt ?? card.wordEn,
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          contextualPrompt == null
              ? 'How do you say it in Czech?'
              : card.exampleEn ?? 'Complete the Czech sentence.',
          style: TextStyle(color: context.tokens.muted, fontSize: 14),
        ),
        const SizedBox(height: 40),
        _tapToReveal(context),
      ],
    );
  }

  /// Audio front — learner listens and recalls the meaning.
  Widget _buildFrontAudio(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _directionBadge(
          'LISTENING',
          fg: context.tokens.priInk,
          bg: context.tokens.priSoft,
        ),
        const SizedBox(height: 32),
        IconButton.filled(
          tooltip: AppLocalizations.of(context).a11yPlayAudio,
          onPressed: () {
            ref.read(czechTtsProvider).speak(card.wordCz);
          },
          icon: const Icon(Icons.volume_up, size: 48),
          padding: const EdgeInsets.all(24),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            ref.read(czechTtsProvider).speakSlow(card.wordCz);
          },
          icon: const Icon(Icons.slow_motion_video, size: 18),
          label: const Text('Slower'),
        ),
        const SizedBox(height: 16),
        Text(
          'Listen — what does it mean?',
          style: TextStyle(color: context.tokens.muted, fontSize: 14),
        ),
        const SizedBox(height: 32),
        _tapToReveal(context),
      ],
    );
  }

  Widget _buildBack(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Czech word (smaller, at top)
        Text(
          card.wordCz,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: context.tokens.muted),
        ),
        const SizedBox(height: 8),
        if (card.ipa != null)
          Text(
            '/${card.ipa}/',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        const Divider(height: 32),

        // English translation
        Text(
          card.wordEn,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),

        // Example sentence
        if (card.exampleCz != null) ...[
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  card.exampleCz!,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (card.exampleEn != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    card.exampleEn!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.tokens.muted,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          // TTS button for example sentence
          if (card.exampleCz != null) ...[
            const SizedBox(height: 8),
            IconButton(
              tooltip: AppLocalizations.of(context).a11yPlayAudio,
              onPressed: () {
                ref.read(czechTtsProvider).speak(card.exampleCz!);
              },
              icon: const Icon(Icons.volume_up, size: 20),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ],
    );
  }
}

String? _contextualCloze(Flashcard card) {
  final example = card.exampleCz;
  if (example == null || example.trim().isEmpty) return null;
  final target = RegExp(RegExp.escape(card.wordCz), caseSensitive: false);
  if (!target.hasMatch(example)) return null;
  return example.replaceFirst(target, '_____');
}

/// Rating buttons — Again / Hard / Good / Easy.
class _RatingButtons extends StatelessWidget {
  final Future<void> Function(Rating) onRate;
  final Map<Rating, String> intervals;
  final bool enabled;

  const _RatingButtons({
    required this.onRate,
    required this.intervals,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _RatingButton(
              label: AppLocalizations.of(context).reviewRatingAgain,
              subtitle: intervals[Rating.again] ?? '',
              color: t.red,
              icon: Icons.refresh,
              onTap: enabled ? () => onRate(Rating.again) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RatingButton(
              label: AppLocalizations.of(context).reviewRatingHard,
              subtitle: intervals[Rating.hard] ?? '',
              color: t.amber,
              icon: Icons.flag,
              onTap: enabled ? () => onRate(Rating.hard) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RatingButton(
              label: AppLocalizations.of(context).reviewRatingGood,
              subtitle: intervals[Rating.good] ?? '',
              color: t.green,
              icon: Icons.check,
              onTap: enabled ? () => onRate(Rating.good) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RatingButton(
              label: AppLocalizations.of(context).reviewRatingEasy,
              subtitle: intervals[Rating.easy] ?? '',
              color: t.pri,
              icon: Icons.star,
              onTap: enabled ? () => onRate(Rating.easy) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _RatingButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The visible face is an icon, a one-word label and an interval like
    // "3d" — read out raw that is meaningless. The label says what the
    // button does; the interval stays as the hint.
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).a11yRateCard(label),
      hint: subtitle,
      excludeSemantics: true,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.1),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(subtitle, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

/// Screen shown when there are no due cards.
class _NoDueCardsScreen extends StatelessWidget {
  final VoidCallback onRefresh;

  const _NoDueCardsScreen({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 80, color: context.tokens.green),
              const SizedBox(height: 24),
              Text(
                'All caught up!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).reviewNoCardsDue,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.tokens.muted),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen shown when the review session is complete.
class _ReviewCompleteScreen extends StatelessWidget {
  final ReviewSessionState session;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const _ReviewCompleteScreen({
    required this.session,
    required this.onRestart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accuracy = (session.accuracy * 100).round();
    final total = session.reviewedCount == 0 ? 1 : session.reviewedCount;
    final accuracyColor =
        accuracy >= 80
            ? t.green
            : accuracy >= 60
            ? t.amber
            : t.red;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 12),
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: t.amberSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.emoji_events_outlined,
                        size: 40,
                        color: t.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(child: DisplayText('Review complete', size: 27)),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Nice work — ${session.reviewedCount} '
                      '${session.reviewedCount == 1 ? 'card' : 'cards'} reviewed',
                      style: TextStyle(fontSize: 14, color: t.muted),
                    ),
                  ),
                  if (session.heartEarned) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: PillChip(
                        label: '+1 heart earned',
                        bg: t.redSoft,
                        fg: t.red,
                        icon: Icons.favorite,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          value: '${session.reviewedCount}',
                          label: 'Cards',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          value: '$accuracy%',
                          label: 'Accuracy',
                          color: accuracyColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          value: '+${session.totalXp}',
                          label: 'XP',
                          color: t.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('How it went'),
                        const SizedBox(height: 14),
                        _RatingRow(
                          color: t.red,
                          label: AppLocalizations.of(context).reviewRatingAgain,
                          count: session.againCount,
                          total: total,
                        ),
                        const SizedBox(height: 12),
                        _RatingRow(
                          color: t.amber,
                          label: AppLocalizations.of(context).reviewRatingHard,
                          count: session.hardCount,
                          total: total,
                        ),
                        const SizedBox(height: 12),
                        _RatingRow(
                          color: t.green,
                          label: AppLocalizations.of(context).reviewRatingGood,
                          count: session.goodCount,
                          total: total,
                        ),
                        const SizedBox(height: 12),
                        _RatingRow(
                          color: t.pri,
                          label: AppLocalizations.of(context).reviewRatingEasy,
                          count: session.easyCount,
                          total: total,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: t.priSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: t.pri),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'These cards are rescheduled with spaced repetition — '
                            'we\'ll surface them again right on time.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t.priInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Back to home',
                    icon: Icons.home_outlined,
                    onPressed: onExit,
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onRestart,
                    child: Text(
                      'Review again',
                      style: TextStyle(
                        color: t.pri,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
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

/// A single big-number stat tile used on the review summary.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: color ?? t.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: t.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the "How it went" breakdown: dot, label, bar, count.
class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });

  final Color color;
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(label, style: TextStyle(fontSize: 14, color: t.ink)),
        ),
        Expanded(
          flex: 4,
          child: SoftProgressBar(
            value: total == 0 ? 0 : count / total,
            color: color,
          ),
        ),
        SizedBox(
          width: 26,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
        ),
      ],
    );
  }
}
