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
import '../../../core/theme/app_motion.dart';
import '../../widgets/common/lesson_ui.dart';
import '../../widgets/common/gender_pill.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/wash_background.dart';
import '../../widgets/common/motion_widgets.dart';

/// SRS review screen — flashcard interface with simplified SM-2 ratings.
class SrsReviewScreen extends ConsumerStatefulWidget {
  const SrsReviewScreen({super.key});

  @override
  ConsumerState<SrsReviewScreen> createState() => _SrsReviewScreenState();
}

class _SrsReviewScreenState extends ConsumerState<SrsReviewScreen> {
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
          title: Text(AppLocalizations.of(context).navReview),
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
        onExit: () => context.go('/'),
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
          title: Text(AppLocalizations.of(context).navReview),
        ),
        body: Center(
          child: Text(AppLocalizations.of(context).reviewNoCardsAvailable),
        ),
      );
    }

    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: WashBackground(
        child: SafeArea(
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
                            l10n.reviewSpacedRepetition,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.faint,
                            ),
                          ),
                          const SizedBox(height: 3),
                          DisplayText(
                            l10n.navReview,
                            size: 27,
                            weight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ],
                      ),
                    ),
                    PillChip(
                      label: l10n.reviewCardsLeft(session.remainingCards),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _DeckCountChip(
                      label: AppLocalizations.of(context).reviewNew,
                      count:
                          session.dueCards
                              .where((c) => c.srs.state == CardState.newCard)
                              .length,
                      color: t.violet,
                      bg: t.violetSoft,
                      ink: t.violetInk,
                    ),
                    _DeckCountChip(
                      label: AppLocalizations.of(context).reviewLearning,
                      count:
                          session.dueCards
                              .where(
                                (c) =>
                                    c.srs.state == CardState.learning ||
                                    c.srs.state == CardState.relearning,
                              )
                              .length,
                      color: t.amber,
                      bg: t.amberSoft,
                      ink: t.amberInk,
                    ),
                    _DeckCountChip(
                      label: AppLocalizations.of(context).reviewDue,
                      count:
                          session.dueCards
                              .where((c) => c.srs.state == CardState.review)
                              .length,
                      color: t.pri,
                      bg: t.priSoft,
                      ink: t.priInk,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Flashcard
              Expanded(
                child: MotionEntrance(
                  key: ValueKey('${session.currentIndex}:${card.flashcard.id}'),
                  offset: const Offset(0.035, 0),
                  child: _FlashcardView(
                    card: card.flashcard,
                    direction: card.direction,
                    isFlipped: session.isFlipped,
                    canReveal:
                        card.direction != CardDirection.enToCz ||
                        _productionAttempt.trim().isNotEmpty,
                    onFlip:
                        card.direction != CardDirection.enToCz ||
                                _productionAttempt.trim().isNotEmpty
                            ? () {
                              ref
                                  .read(reviewSessionProvider.notifier)
                                  .flipCard();
                            }
                            : null,
                  ),
                ),
              ),

              MotionDisclosure(
                visible:
                    !session.isFlipped &&
                    card.direction == CardDirection.enToCz,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LessonKicker(l10n.reviewRetrieveTheCzech),
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
                          hintText: l10n.reviewSayItThenTypeIt,
                          hintStyle: TextStyle(fontSize: 16, color: t.faint),
                          helperText: l10n.reviewOvertAttemptNote,
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
                            (value) =>
                                setState(() => _productionAttempt = value),
                      ),
                    ],
                  ),
                ),
              ),

              // Rating buttons (only after flip)
              MotionEntrance(
                key: ValueKey(
                  session.isFlipped ? 'rating-controls' : 'reveal-control',
                ),
                offset: const Offset(0, 0.025),
                child:
                    session.isFlipped
                        ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (session.commitError != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  session.commitError!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.redInk,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            _RatingButtons(
                              intervals: _intervalLabels(card.srs),
                              enabled: !session.isCommitting,
                              onRate: (rating) async {
                                final ratedCardId = card.flashcard.id;
                                await ref
                                    .read(reviewSessionProvider.notifier)
                                    .rateCard(rating);
                                if (!mounted) return;
                                final current =
                                    ref.read(reviewSessionProvider).currentCard;
                                // Keep a production answer when persistence failed and
                                // the learner is still on the same card. Clear it only
                                // once the committed review actually advanced.
                                if (current?.flashcard.id != ratedCardId) {
                                  setState(() => _productionAttempt = '');
                                }
                              },
                            ),
                          ],
                        )
                        : Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
                          child: KeyCta(
                            label:
                                card.direction == CardDirection.enToCz &&
                                        _productionAttempt.trim().isEmpty
                                    ? l10n.reviewTypeAnswerFirst
                                    : l10n.reviewShowAnswer,
                            onPressed:
                                card.direction != CardDirection.enToCz ||
                                        _productionAttempt.trim().isNotEmpty
                                    ? () {
                                      ref
                                          .read(reviewSessionProvider.notifier)
                                          .flipCard();
                                    }
                                    : null,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Honest interval hints computed from the real scheduler for the
  /// current card. "Again" re-appears within this session, so it shows
  /// "Soon" rather than a day count.
  Map<Rating, String> _intervalLabels(SrsCard card) {
    final now = DateTime.now();
    final soon = AppLocalizations.of(context).reviewIntervalSoon;
    String fmt(Rating r) {
      if (r == Rating.again) return soon;
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

class _DeckCountChip extends StatelessWidget {
  const _DeckCountChip({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
    required this.ink,
  });

  final String label;
  final int count;
  final Color color;
  final Color bg;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(9, 6, 11, 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label  $count',
          style: TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// The flashcard view. The front depends on the card's direction —
/// recognition (CZ), production (EN), or audio-only — and the back always
/// shows the full word with translation, IPA, and example.
class _FlashcardView extends ConsumerWidget {
  final Flashcard card;
  final CardDirection direction;
  final bool isFlipped;
  final bool canReveal;
  final VoidCallback? onFlip;

  const _FlashcardView({
    required this.card,
    required this.direction,
    required this.isFlipped,
    required this.canReveal,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: onFlip != null,
      label: canReveal ? l10n.a11yTapToFlipCard : l10n.reviewTypeAnswerFirst,
      hint: canReveal ? l10n.reviewTapToReveal : l10n.reviewTypeAnswerFirst,
      excludeSemantics: true,
      child: GestureDetector(
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
                child: MotionSwap(
                  offset: Offset.zero,
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
  Widget _tapToReveal(BuildContext context, {bool enabled = true}) {
    final t = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          enabled ? Icons.touch_app_outlined : Icons.keyboard_alt_outlined,
          color: t.faint,
          size: 18,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            enabled
                ? AppLocalizations.of(context).reviewTapToReveal
                : AppLocalizations.of(context).reviewTypeAnswerFirst,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.faint,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFront(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final cloze = _contextualCloze(card);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child:
                    card.gender != null
                        ? GenderPill(gender: card.gender!, abbreviated: false)
                        : LessonKicker(l10n.reviewWhatDoesItMean),
              ),
            ),
            const SizedBox(width: 8),
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

        // The word alone left the card two-thirds empty. The comp answers
        // that with the sentence the word lives in, blanked out — which is
        // also a better prompt: it gives the grammar a context to sit in
        // without giving the meaning away.
        if (cloze != null) ...[
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: t.elev,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LessonKicker(l10n.reviewInASentence),
                const SizedBox(height: 7),
                Text(
                  cloze,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 22),
        _HintRow(card: card),
        const SizedBox(height: 16),
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
          AppLocalizations.of(context).reviewDirectionEnToCz,
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
              ? AppLocalizations.of(context).reviewHowDoYouSayIt
              : card.exampleEn ??
                  AppLocalizations.of(context).reviewCompleteCzechSentence,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.tokens.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 32),
        _tapToReveal(context, enabled: canReveal),
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
          AppLocalizations.of(context).reviewDirectionListening,
          fg: context.tokens.violetInk,
          bg: context.tokens.violetSoft,
        ),
        const SizedBox(height: 26),
        ListenPanel(
          label: AppLocalizations.of(context).audioPlayIt,
          onPlay: () => ref.read(czechTtsProvider).speak(card.wordCz),
          onSlow: () => ref.read(czechTtsProvider).speakSlow(card.wordCz),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context).reviewWhatDoesItMean,
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
        LessonKicker(AppLocalizations.of(context).reviewMeans),
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
                      tooltip:
                          AppLocalizations.of(context).a11yPlayPronunciation,
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
/// The comp's escape hatch on a card you cannot retrieve: ask for a nudge
/// rather than flipping straight to the answer, so the attempt still counts
/// as recall. Collapses back to the button on the next card.
class _HintRow extends StatefulWidget {
  const _HintRow({required this.card});

  final Flashcard card;

  @override
  State<_HintRow> createState() => _HintRowState();
}

class _HintRowState extends State<_HintRow> {
  bool _shown = false;

  @override
  void didUpdateWidget(_HintRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) _shown = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    if (!_shown) {
      return Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _shown = true),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.reviewNeedAHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.muted,
              ),
            ),
          ),
        ),
      );
    }

    // Two letters is enough to unlock recall without handing over the word.
    final start = widget.card.wordCz.characters.take(2).toString();
    final gender = widget.card.gender;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: t.amberSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, size: 14, color: t.amberInk),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              gender == null
                  ? l10n.reviewHintStartsWith(start)
                  : '${l10n.reviewHintStartsWith(start)} · $gender',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      label: AppLocalizations.of(context).a11yPlayPronunciation,
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
                  AppLocalizations.of(context).audioHearIt,
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The rating is also the commit-and-advance action. Say that before
          // presenting the choices so this does not look like an optional
          // self-assessment followed by a missing Next button.
          LessonKicker(l10n.reviewHowWellRecalled),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.arrow_forward_rounded, size: 17, color: t.pri),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  l10n.reviewChooseRatingToContinue,
                  style: TextStyle(
                    color: t.muted,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                      // Coral for "again" is the only error-ish colour here.
                      // "Hard" takes amber, matching both the comp and the
                      // Learning chip at the top of this same screen — amber
                      // is what "still shaky" looks like everywhere else in
                      // the review surface, so violet here read as a fourth
                      // unrelated meaning.
                      color: switch (grade) {
                        Rating.again => t.red,
                        Rating.hard => t.amber,
                        Rating.good => t.green,
                        Rating.easy => t.pri,
                      },
                      ink: switch (grade) {
                        Rating.again => t.redInk,
                        Rating.hard => t.amberInk,
                        Rating.good => t.greenInk,
                        Rating.easy => t.priInk,
                      },
                      tint: switch (grade) {
                        Rating.again => t.redSoft,
                        Rating.hard => t.amberSoft,
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
      child: AnimatedOpacity(
        duration: context.motionDuration(AppMotion.selection),
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
                            horizontal: 5,
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
                              const SizedBox(width: 3),
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
  final VoidCallback onExit;

  const _NoDueCardsScreen({required this.onRefresh, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: WashBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).reviewSpacedRepetition,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.faint,
                            ),
                          ),
                          const SizedBox(height: 3),
                          DisplayText(
                            AppLocalizations.of(context).navReview,
                            size: 27,
                            weight: FontWeight.w800,
                          ),
                        ],
                      ),
                    ),
                    RoundIconButton(
                      icon: Icons.close,
                      tooltip: AppLocalizations.of(context).a11yClose,
                      onTap: onExit,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 112),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: AspectRatio(
                            aspectRatio: 3 / 2,
                            child: Image.asset(
                              'assets/images/review_empty_v2.png',
                              fit: BoxFit.cover,
                              semanticLabel:
                                  'Flashcards, a notebook and a growing plant by a Prague window',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        DisplayText(
                          AppLocalizations.of(context).reviewAllCaughtUp,
                          size: 30,
                          weight: FontWeight.w800,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).reviewNoCardsDue,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: t.muted,
                          ),
                        ),
                        const SizedBox(height: 26),
                        KeyCta(
                          label: AppLocalizations.of(context).reviewCheckAgain,
                          onPressed: onRefresh,
                        ),
                      ],
                    ),
                  ),
                ),
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
    final l10n = AppLocalizations.of(context);
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
      body: WashBackground(
        child: SafeArea(
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
                        caption: l10n.captionRecall,
                        color: accuracyColor,
                        showBadge: accuracy >= 80,
                        size: 104,
                        animateOnMount: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: DisplayText(
                        l10n.reviewDeckCleared,
                        size: 27,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        l10n.reviewCardsReviewed(session.reviewedCount),
                        style: TextStyle(fontSize: 14, color: t.muted),
                      ),
                    ),
                    if (session.heartEarned) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: PillChip(
                          label: l10n.reviewHeartEarned,
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
                          label: l10n.statCards,
                        ),
                        StatCell(
                          value: '${session.goodCount + session.easyCount}',
                          label: l10n.statRecalled,
                          color: t.greenInk,
                        ),
                        StatCell(
                          value: '+${session.totalXp}',
                          label: l10n.statXpEarned,
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
                          SectionLabel(l10n.reviewHowItWent),
                          const SizedBox(height: 14),
                          _RatingRow(
                            color: t.red,
                            label:
                                AppLocalizations.of(context).reviewRatingAgain,
                            count: session.againCount,
                            total: total,
                          ),
                          const SizedBox(height: 12),
                          _RatingRow(
                            color: t.violet,
                            label:
                                AppLocalizations.of(context).reviewRatingHard,
                            count: session.hardCount,
                            total: total,
                          ),
                          const SizedBox(height: 12),
                          _RatingRow(
                            color: t.green,
                            label:
                                AppLocalizations.of(context).reviewRatingGood,
                            count: session.goodCount,
                            total: total,
                          ),
                          const SizedBox(height: 12),
                          _RatingRow(
                            color: t.pri,
                            label:
                                AppLocalizations.of(context).reviewRatingEasy,
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
                              l10n.reviewReschedulingNote,
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
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
                          child: Text(l10n.reviewGoAgain),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: KeyCta(
                        label: l10n.reviewDone,
                        onPressed: onExit,
                        radius: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            borderRadius: BorderRadius.circular(999),
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
