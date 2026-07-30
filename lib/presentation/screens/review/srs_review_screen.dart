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
import '../../widgets/common/lesson_ui.dart';
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

  /// Stateless, so one instance serves the whole session — it was being
  /// constructed once per card render.
  final _scheduler = SrsScheduler();

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
        backgroundColor: context.tokens.bg,
        appBar: AppBar(
          backgroundColor: context.tokens.bg,
          title: const Text('Review'),
        ),
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
        backgroundColor: context.tokens.bg,
        appBar: AppBar(
          backgroundColor: context.tokens.bg,
          title: const Text('Review'),
        ),
        body: const Center(child: Text('No cards available.')),
      );
    }

    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: what this screen is, how far in, and the way out.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spaced repetition',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.faint,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const DisplayText(
                          'Review',
                          size: 27,
                          weight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ],
                    ),
                  ),
                  PillChip(
                    label: '${session.remainingCards} left',
                    bg: t.chipBg,
                    fg: t.muted,
                  ),
                  const SizedBox(width: 9),
                  RoundIconButton(
                    icon: Icons.close,
                    tooltip: AppLocalizations.of(context).a11yClose,
                    onTap: () => _showExitConfirm(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Semantics(
                label: AppLocalizations.of(
                  context,
                ).reviewCardOf(session.currentIndex + 1, session.totalCards),
                excludeSemantics: true,
                child: SegmentPips(
                  count: session.totalCards,
                  currentIndex: session.currentIndex,
                ),
              ),
            ),
            const SizedBox(height: 14),

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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LessonKicker('Retrieve the Czech'),
                    const SizedBox(height: 8),
                    TextField(
                      key: ValueKey(card.flashcard.id),
                      autocorrect: false,
                      cursorColor: t.pri,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: t.card,
                        hintText: 'Say it, then type it',
                        hintStyle: TextStyle(fontSize: 16, color: t.faint),
                        helperText: 'Make an overt attempt before revealing.',
                        helperStyle: TextStyle(fontSize: 12, color: t.faint),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: t.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: t.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: t.pri, width: 1.5),
                        ),
                      ),
                      onChanged:
                          (value) => setState(() => _productionAttempt = value),
                    ),
                  ],
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
                        style: TextStyle(fontSize: 13, color: t.redInk),
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: KeyCta(
                  label: AppLocalizations.of(context).reviewShowAnswer,
                  onPressed:
                      card.direction != CardDirection.enToCz ||
                              _productionAttempt.trim().isNotEmpty
                          ? () {
                            ref.read(reviewSessionProvider.notifier).flipCard();
                          }
                          : null,
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
    final now = DateTime.now();
    String fmt(Rating r) {
      if (r == Rating.again) return 'Soon';
      final days = _scheduler.previewIntervalDays(card, r, now);
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
    final t = context.tokens;
    return GestureDetector(
      onTap: isFlipped ? null : onFlip,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Stack(
          children: [
            // Two hints of the cards still to come, so the deck has depth and
            // "how many left" is felt as well as counted.
            const Positioned(
              left: 16,
              right: 16,
              bottom: -11,
              child: _DeckShadowCard(opacity: 0.5),
            ),
            const Positioned(
              left: 8,
              right: 8,
              bottom: -6,
              child: _DeckShadowCard(opacity: 0.8),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(24),
                boxShadow: t.shadowLg,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder:
                    (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.96,
                          end: 1.0,
                        ).animate(anim),
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
                            CardDirection.audio => _buildFrontAudio(
                              context,
                              ref,
                            ),
                          },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Small pill naming the recall direction of the current card.
  Widget _directionBadge(
    BuildContext context,
    String label, {
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: fg,
        ),
      ),
    );
  }

  /// Shared "tap the card to see the answer" affordance, identical on all
  /// three card fronts.
  Widget _tapToReveal(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_outlined, color: t.faint, size: 18),
        const SizedBox(width: 8),
        Text(
          AppLocalizations.of(context).reviewTapToReveal,
          style: TextStyle(
            color: t.faint,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFront(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (card.gender != null)
              GenderPill(gender: card.gender!, abbreviated: false)
            else
              const LessonKicker('What does it mean?'),
            _AudioPill(text: card.wordCz),
          ],
        ),
        const SizedBox(height: 28),

        // The word, as large as the card allows — this is the whole question.
        Text(
          card.wordCz,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 44,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -1,
            color: t.ink,
          ),
        ),

        // Respelling notation, set in mono so it does not read as Czech.
        if (card.ipa != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: t.elev,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              card.ipa!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: t.pri,
              ),
            ),
          ),
        ],

        const SizedBox(height: 32),
        _tapToReveal(context),
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
          context,
          'EN → CZ',
          fg: context.tokens.violetInk,
          bg: context.tokens.violetSoft,
        ),
        const SizedBox(height: 26),
        Text(
          contextualPrompt ?? card.wordEn,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.7,
            color: context.tokens.ink,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          contextualPrompt == null
              ? 'How do you say it in Czech?'
              : card.exampleEn ?? 'Complete the Czech sentence.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.tokens.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 32),
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
          context,
          'Listening',
          fg: context.tokens.violetInk,
          bg: context.tokens.violetSoft,
        ),
        const SizedBox(height: 26),
        ListenPanel(
          label: 'Play it',
          onPlay: () => ref.read(czechTtsProvider).speak(card.wordCz),
          onSlow: () => ref.read(czechTtsProvider).speakSlow(card.wordCz),
        ),
        const SizedBox(height: 8),
        Text(
          'What does it mean?',
          style: TextStyle(color: context.tokens.muted, fontSize: 15),
        ),
        const SizedBox(height: 26),
        _tapToReveal(context),
      ],
    );
  }

  Widget _buildBack(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LessonKicker('Means'),
        const SizedBox(height: 10),

        // The meaning leads; the Czech and its notation sit under it as the
        // thing that was being recalled.
        Text(
          card.wordEn,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.08,
            letterSpacing: -0.6,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                card.wordCz,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: t.muted,
                ),
              ),
            ),
            _AudioPill(text: card.wordCz),
          ],
        ),
        if (card.ipa != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: t.elev,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                card.ipa!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: t.pri,
                ),
              ),
            ),
          ),
        ],

        if (card.exampleCz != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.elev,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.exampleCz!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: t.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).a11yPlayAudio,
                      onPressed:
                          () =>
                              ref.read(czechTtsProvider).speak(card.exampleCz!),
                      icon: const Icon(Icons.volume_up_outlined, size: 20),
                      color: t.pri,
                    ),
                  ],
                ),
                if (card.exampleEn != null)
                  Text(
                    card.exampleEn!,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: t.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One of the faint cards peeking out from under the current one.
class _DeckShadowCard extends StatelessWidget {
  const _DeckShadowCard({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: opacity,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

/// The play control on a flashcard: drawn small, but with a 44pt target.
class _AudioPill extends ConsumerWidget {
  const _AudioPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).a11yPlayAudio,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => ref.read(czechTtsProvider).speak(text),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          // The pill is drawn at 34pt to stay quiet beside the word; the
          // padding is what carries it to the 44pt minimum.
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 5, 13, 5),
            decoration: BoxDecoration(
              color: t.priSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: t.pri,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow, size: 15, color: t.onFill),
                ),
                const SizedBox(width: 7),
                Text(
                  'Hear it',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: t.priInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Say what the four buttons actually do — they schedule the card,
          // they are not a score.
          const LessonKicker(
            'How well did you recall it? · sets when it returns',
          ),
          const SizedBox(height: 9),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, grade) in Rating.values.indexed) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: _RatingButton(
                      label: switch (grade) {
                        Rating.again => l10n.reviewRatingAgain,
                        Rating.hard => l10n.reviewRatingHard,
                        Rating.good => l10n.reviewRatingGood,
                        Rating.easy => l10n.reviewRatingEasy,
                      },
                      subtitle: intervals[grade] ?? '',
                      // Coral for "again" is the only error-ish colour here;
                      // hard, good and easy are all successful recalls at
                      // different strengths, so they get violet, green and blue.
                      color: switch (grade) {
                        Rating.again => t.red,
                        Rating.hard => t.violet,
                        Rating.good => t.green,
                        Rating.easy => t.pri,
                      },
                      ink: switch (grade) {
                        Rating.again => t.redInk,
                        Rating.hard => t.violetInk,
                        Rating.good => t.greenInk,
                        Rating.easy => t.priInk,
                      },
                      tint: switch (grade) {
                        Rating.again => t.redSoft,
                        Rating.hard => t.violetSoft,
                        Rating.good => t.greenSoft,
                        Rating.easy => t.priSoft,
                      },
                      onTap: enabled ? () => onRate(grade) : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One grade button: a coloured cap, the verdict, and when the card returns.
///
/// The interval chip is the point of the control — the learner is scheduling
/// the card, not scoring themselves — so it is on the face, not just in the
/// accessibility hint.
class _RatingButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final Color ink;
  final Color tint;
  final VoidCallback? onTap;

  const _RatingButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.ink,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;

    // The visible face is a one-word label and an interval like "3d" — read
    // out raw that is meaningless. The label says what the button does; the
    // interval stays as the hint.
    return Semantics(
      button: true,
      enabled: enabled,
      label: AppLocalizations.of(context).a11yRateCard(label),
      hint: subtitle,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.line),
                boxShadow: t.shadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A 3pt cap of the grade's colour: colour without putting a
                  // hue behind any glyph.
                  Container(height: 3, color: color),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 11, 4, 10),
                    child: Column(
                      children: [
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule, size: 11, color: ink),
                              const SizedBox(width: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                            ],
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
    );
  }
}

class _NoDueCardsScreen extends StatelessWidget {
  final VoidCallback onRefresh;

  const _NoDueCardsScreen({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTile(
                  icon: Icons.check_rounded,
                  tint: t.greenSoft,
                  fg: t.greenInk,
                  size: 72,
                  radius: 24,
                  iconSize: 34,
                ),
                const SizedBox(height: 20),
                const DisplayText(
                  'All caught up',
                  size: 30,
                  weight: FontWeight.w800,
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).reviewNoCardsDue,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: t.muted),
                ),
                const SizedBox(height: 26),
                KeyCta(label: 'Check again', onPressed: onRefresh),
              ],
            ),
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
    // Amber means streak and XP in this palette, so a middling recall is
    // violet — the memory colour — rather than a warning.
    final accuracyColor =
        accuracy >= 80
            ? t.greenInk
            : accuracy >= 60
            ? t.violetInk
            : t.redInk;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                // Bottom padding clears the pinned footer: with only 12 the
                // last card was cut mid-sentence and read as a rendering bug
                // rather than as something still to scroll.
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                children: [
                  // Recall, as a ring — the same shape every accuracy figure
                  // in the app uses.
                  Center(
                    child: ScoreRing(
                      fraction: session.accuracy,
                      label: '$accuracy%',
                      caption: 'recall',
                      color: accuracyColor,
                      showBadge: accuracy >= 80,
                      size: 104,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: DisplayText(
                      'Deck cleared',
                      size: 27,
                      weight: FontWeight.w800,
                    ),
                  ),
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
                        fg: t.redInk,
                        icon: Icons.favorite,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  StatStrip(
                    cells: [
                      StatCell(
                        value: '${session.reviewedCount}',
                        label: 'Cards',
                      ),
                      StatCell(
                        value: '${session.goodCount + session.easyCount}',
                        label: 'Recalled',
                        color: t.greenInk,
                      ),
                      StatCell(
                        value: '+${session.totalXp}',
                        label: 'XP',
                        color: t.amberInk,
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
                          color: t.violet,
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
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: t.priSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: t.priInk),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'These cards are rescheduled with spaced repetition '
                            '— each one comes back right when it is about to '
                            'slip.',
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
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
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 58,
                      child: OutlinedButton(
                        onPressed: onRestart,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: t.line, width: 1.5),
                          foregroundColor: t.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Go again'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: KeyCta(label: 'Done', onPressed: onExit)),
                ],
              ),
            ),
          ],
        ),
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
