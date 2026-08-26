import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/settings_providers.dart';

/// Shared primitives for the learning loop — the surfaces the Czechify 2.0
/// handoff specifies most precisely: the lesson chrome, the teaching card, the
/// quiz option tiles and the answer-feedback sheet.
///
/// The system rules these encode, so they don't have to be restated per screen:
///
///  - Radius is 12 (icon containers, keys), 16 (buttons, inner panels),
///    24 (cards, sheets, hero surfaces) or 999 (pills). Nothing else.
///  - Raw hues are for fills and ≥3:1 graphics; anything holding a glyph uses
///    the matching `*Ink` token, which is what passes 4.5:1 at 17/700.
///  - Tracked uppercase is reserved for step kickers inside a lesson, which is
///    exactly what [LessonKicker] is for — do not reach for it elsewhere.
///  - Every animation here has a reduced-motion variant, checked through
///    [MediaQuery.disableAnimationsOf].

/// The kit's own strings.
///
/// A nullable lookup rather than [AppLocalizations.of], which asserts a
/// Localizations ancestor: these are leaf primitives that get dropped into bare
/// widget tests and previews, and requiring the full app scope to render a play
/// button is coupling they do not need. The app always installs the delegates,
/// so the English fallback is only ever seen out of app context.
AppLocalizations? _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations);

/// Tracked uppercase step kicker — "STEP 1 · MEET THE SOUND".
///
/// The one place in the app where tracked uppercase is allowed.
class LessonKicker extends StatelessWidget {
  const LessonKicker(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.7,
        height: 1.3,
        color: color ?? context.tokens.faint,
      ),
    );
  }
}

/// A 44pt circular control with a hairline border — the leave button on the
/// lesson and review flows, and the back arrow on the full-screen ones.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.line),
            ),
            child: Icon(icon, size: 18, color: t.muted),
          ),
        ),
      ),
    );
  }
}

/// The lesson progress row: one pip per step, the current one widened.
///
/// Replaces a bare [LinearProgressIndicator] because position within a short
/// sequence is easier to read as discrete segments than as a filled fraction.
class SegmentPips extends StatelessWidget {
  const SegmentPips({
    super.key,
    required this.count,
    required this.currentIndex,
    this.height = 5,
    this.color,
  });

  final int count;
  final int currentIndex;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fill = color ?? t.pri;
    // Above roughly a dozen steps the pips get thinner than the gaps between
    // them, which reads as noise — fall back to a plain track.
    if (count > 12) {
      final value = count == 0 ? 0.0 : (currentIndex + 1) / count;
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: t.line,
          valueColor: AlwaysStoppedAnimation(fill),
        ),
      );
    }

    final instant = MediaQuery.disableAnimationsOf(context);
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            // The current step takes more of the row than the others, so the
            // eye lands on where you are rather than counting segments.
            flex: i == currentIndex ? 24 : 10,
            child: AnimatedContainer(
              duration:
                  instant ? Duration.zero : const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: height,
              decoration: BoxDecoration(
                color: i <= currentIndex ? fill : t.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Hearts remaining, as an outlined pill. Hollow heart once they run out.
class HeartsChip extends StatelessWidget {
  const HeartsChip({super.key, required this.hearts});

  final int hearts;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hearts > 0 ? Icons.favorite : Icons.favorite_border,
            size: 14,
            color: t.red,
          ),
          const SizedBox(width: 5),
          Text(
            '$hearts',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Answer-streak chip — "3 in a row". Amber, because streak and XP are the
/// only things amber is allowed to mean.
class ComboChip extends StatelessWidget {
  const ComboChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t.amberSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 13, color: t.amberInk),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.amberInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "+10 XP" that flies up out of the lesson header on a correct answer.
///
/// Plays once per mount, so give it a [ValueKey] that changes when a new award
/// should animate. Under reduced motion it holds still and fades instead.
class XpFlyUp extends StatefulWidget {
  const XpFlyUp({super.key, required this.label});

  final String label;

  @override
  State<XpFlyUp> createState() => _XpFlyUpState();
}

class _XpFlyUpState extends State<XpFlyUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Text(
      widget.label,
      style: TextStyle(
        fontFamily: AppFonts.display,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: t.amberInk,
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return text;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        // Rises and fades: overshoots to 1.15 early, then drifts up and out.
        final dy = -52 * Curves.easeOut.transform(v);
        final scale =
            v < 0.25 ? 0.8 + 1.4 * v : 1.15 - 0.15 * ((v - 0.25) / 0.75);
        final opacity = v < 0.15 ? v / 0.15 : (v > 0.75 ? (1 - v) / 0.25 : 1.0);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: text,
    );
  }
}

/// The tutor speaking: initial-tile avatar with an online dot, beside a card
/// with one corner notched toward the avatar.
class TutorBubble extends StatelessWidget {
  const TutorBubble({
    super.key,
    required this.initial,
    required this.name,
    required this.text,
    this.accent,
    this.accentSoft,
  });

  final String initial;
  final String name;
  final String text;
  final Color? accent;
  final Color? accentSoft;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = accent ?? t.pri;
    final bg = accentSoft ?? t.priSoft;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: t.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.bg, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              boxShadow: t.shadow,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
                bottomLeft: Radius.circular(6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LessonKicker(name),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: TextStyle(fontSize: 15.5, height: 1.5, color: t.ink),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Hear it" with the playback speed underneath — the audio block that appears
/// on every teaching surface.
///
/// There used to be a "Slower" button beside the play button, replaying the
/// phrase once at 0.6x. It is gone for two reasons. On teaching cards it did
/// nothing at all: play-all is a toggle, so while audio was playing any tap —
/// including that one — stopped it and returned. And even working, a one-off
/// slow replay answers the wrong question. A learner who finds the pace too
/// quick wants it slower until they say otherwise, not for one phrase, and a
/// button gives no clue what speed you are on now.
class AudioPairButtons extends StatelessWidget {
  const AudioPairButtons({
    super.key,
    required this.onPlay,
    this.playLabel,
    this.playing = false,
  });

  final VoidCallback? onPlay;

  /// Overrides the default "Hear it" — lesson content sometimes names the set
  /// it plays ("Play the whole set").
  final String? playLabel;

  /// Swaps the primary button to a stop affordance mid-playback.
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = _l10n(context);
    // IntrinsicHeight + stretch, because the play label comes from lesson
    // content and can be a whole phrase ("Hear the alphabet (letter names)").
    // With fixed heights the wrapped button grew and the two no longer lined
    // up; this way the taller one sets the height and both match it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPlay,
                  icon: Icon(playing ? Icons.stop : Icons.play_arrow, size: 20),
                  label: Text(
                    playing
                        ? (l10n?.audioStop ?? 'Stop')
                        : (playLabel ?? l10n?.audioHearIt ?? 'Hear it'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.priFill,
                    foregroundColor: t.onFill,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const TtsSpeedSelector(),
      ],
    );
  }
}

/// The hero teaching surface: a tinted gradient card with a huge ghost glyph
/// bled off the top-right corner.
class TeachingHeroCard extends StatelessWidget {
  const TeachingHeroCard({
    super.key,
    required this.child,
    this.watermark,
    this.accent,
  });

  final Widget child;

  /// The oversized character painted behind the content — the "ř" moment.
  final String? watermark;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.pri;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [
            t.card,
            Color.alphaBlend(t.priSoft.withValues(alpha: 0.6), t.card),
          ],
        ),
        border: Border.all(color: a.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: t.shadow,
      ),
      child: Stack(
        children: [
          if (watermark != null)
            Positioned(
              right: -8,
              top: -46,
              child: IgnorePointer(
                child: Text(
                  watermark!,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 210,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: a.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

/// How a quiz option is currently being presented.
enum OptionState {
  /// Not chosen, still selectable.
  idle,

  /// Chosen but not yet checked.
  selected,

  /// Revealed as the right answer.
  correct,

  /// Revealed as the learner's wrong answer.
  wrong,

  /// Not chosen, and the question is over.
  dimmed,
}

/// Which [OptionState] an option is in, given the answer so far.
///
/// Shared so every pick-one exercise resolves the five states identically —
/// this was the rule most likely to drift when each view spelled it out.
OptionState optionState({
  required int index,
  required int correctIndex,
  required int? selectedIndex,
  required bool answered,
}) {
  if (!answered) {
    return index == selectedIndex ? OptionState.selected : OptionState.idle;
  }
  if (index == correctIndex) return OptionState.correct;
  if (index == selectedIndex) return OptionState.wrong;
  return OptionState.dimmed;
}

/// One tappable answer in a pick-one question: a key badge and the option text.
///
/// The four states are colour AND glyph, never colour alone — the badge shows
/// the key letter while idle and a check or cross once the answer is revealed.
class QuizOptionTile extends StatelessWidget {
  const QuizOptionTile({
    super.key,
    required this.keyLabel,
    required this.text,
    required this.state,
    this.onTap,
  });

  final String keyLabel;
  final String text;
  final OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final (
      Color bg,
      Color border,
      Color badgeBg,
      Color badgeFg,
    ) = switch (state) {
      OptionState.correct => (t.greenSoft, t.green, t.green, t.onFill),
      OptionState.wrong => (t.redSoft, t.red, t.red, t.onFill),
      OptionState.selected => (t.priSoft, t.pri, t.pri, t.onFill),
      OptionState.dimmed => (t.card, t.line, t.elev, t.faint),
      OptionState.idle => (t.card, t.line, t.elev, t.muted),
    };

    final badgeIcon = switch (state) {
      OptionState.correct => Icons.check,
      OptionState.wrong => Icons.close,
      _ => null,
    };

    final instant = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: state == OptionState.selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration:
                instant ? Duration.zero : const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(24),
              boxShadow: state == OptionState.idle ? t.shadow : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      badgeIcon != null
                          ? Icon(badgeIcon, size: 18, color: badgeFg)
                          : Text(
                            keyLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: badgeFg,
                            ),
                          ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: state == OptionState.dimmed ? t.muted : t.ink,
                    ),
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

/// The listen-first hero on dictation and listening exercises: a wide violet
/// panel whose only job is to be impossible to miss, with a quieter "Slower"
/// beside it.
///
/// Violet because listening back is a memory task — the same meaning the
/// review surfaces carry.
class ListenPanel extends StatefulWidget {
  const ListenPanel({
    super.key,
    required this.onPlay,
    required this.onSlow,
    this.label,
  });

  final VoidCallback onPlay;
  final VoidCallback onSlow;

  /// Overrides the default "Play it again".
  final String? label;

  @override
  State<ListenPanel> createState() => _ListenPanelState();
}

class _ListenPanelState extends State<ListenPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    // Deferred to the first build so the reduced-motion check can gate it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      _pulse.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = _l10n(context);
    final label = widget.label ?? l10n?.audioPlayAgain ?? 'Play it again';
    return Column(
      children: [
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: t.violetSoft,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: widget.onPlay,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.09).animate(_pulse),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: t.violet,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          size: 22,
                          color: t.onFill,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.violetInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: widget.onSlow,
          icon: const Icon(Icons.schedule, size: 16),
          label: Text(l10n?.audioSlower ?? 'Slower'),
          style: TextButton.styleFrom(
            foregroundColor: t.muted,
            minimumSize: const Size(0, 44),
          ),
        ),
      ],
    );
  }
}

/// The writing surface for typed answers: a card with a dashed baseline, the
/// answer set in display face, and a border that carries the verdict.
///
/// This is a real [TextField] rather than the handoff's bespoke on-screen
/// keyboard: the system keyboard is what respects Dynamic Type, dictation,
/// external keyboards and every input language the learner already has. The
/// Czech letters the design puts on its custom keys are available through
/// [CzechCharBar] instead.
class AnswerField extends StatelessWidget {
  const AnswerField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.verdict,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.multiline = false,
    this.autofocus = false,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final bool enabled;

  /// `true` correct, `false` wrong, `null` not yet checked.
  final bool? verdict;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Sentences get a smaller face and room to wrap; single words get the big
  /// one from the comps.
  final bool multiline;
  final bool autofocus;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final border = switch (verdict) {
      true => t.green,
      false => t.red,
      null => t.line,
    };
    final ink = switch (verdict) {
      true => t.greenInk,
      false => t.redInk,
      null => t.ink,
    };
    final size = multiline ? 20.0 : 30.0;

    return Container(
      constraints: BoxConstraints(minHeight: multiline ? 104 : 96),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(24),
        boxShadow: t.shadow,
      ),
      child: Stack(
        children: [
          // The writing line, dashed the way ruled practice paper is.
          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: CustomPaint(
              painter: _DashedLinePainter(color: t.line),
              size: const Size(double.infinity, 1.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
            child: TextField(
              controller: controller,
              enabled: enabled,
              autofocus: autofocus,
              textAlign: TextAlign.center,
              maxLines: multiline ? 3 : 1,
              minLines: 1,
              cursorColor: t.pri,
              cursorWidth: 3,
              cursorRadius: const Radius.circular(2),
              // Room for the Check button below the field.
              //
              // A focused TextField scrolls itself into view with 20px of
              // slack, which put the field just above the keyboard and left
              // the button that submits it underneath — the learner typed an
              // answer and then had to scroll to do anything with it. Reserving
              // the button's height plus the letter row means focusing brings
              // the whole answering apparatus up, not just the box.
              scrollPadding: const EdgeInsets.only(bottom: 180),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction:
                  multiline ? TextInputAction.newline : TextInputAction.done,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  // The hint doubles as the design's tracing guide: the shape
                  // of the answer, faint enough not to be readable as input.
                  color: t.ink.withValues(alpha: 0.13),
                ),
                label: semanticLabel == null ? null : Text(semanticLabel!),
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.5;
    // 7 on, 6 off — the ratio the handoff uses for its ruled line.
    for (var x = 0.0; x < size.width; x += 13) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + 7, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

/// The answer verdict, as a sheet that rises from the bottom of the lesson.
///
/// Correct is green, incorrect coral, and a skipped/"shown" answer is neutral
/// — the learner did not get it wrong, so it is not coloured as an error.
class FeedbackSheet extends StatelessWidget {
  const FeedbackSheet({
    super.key,
    required this.title,
    required this.onContinue,
    required this.continueLabel,
    this.tone = FeedbackTone.correct,
    this.body,
    this.correctAnswer,
    this.tutorInitial,
    this.onPlay,
    this.extra,
    this.busy = false,
    this.continueSemanticsLabel,
  });

  final String title;
  final VoidCallback? onContinue;
  final String continueLabel;
  final String? continueSemanticsLabel;
  final FeedbackTone tone;
  final String? body;
  final String? correctAnswer;
  final String? tutorInitial;
  final VoidCallback? onPlay;

  /// Anything screen-specific that belongs above the Continue button.
  final Widget? extra;

  /// Disables Continue and shows a spinner while the result is being saved.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = _l10n(context);
    final (Color bg, Color hue, Color ink) = switch (tone) {
      FeedbackTone.correct => (t.greenSoft, t.green, t.greenInk),
      FeedbackTone.incorrect => (t.redSoft, t.red, t.redInk),
      FeedbackTone.neutral => (t.elev, t.muted, t.ink),
    };
    final mark = switch (tone) {
      FeedbackTone.correct => Icons.check,
      FeedbackTone.incorrect => Icons.close,
      FeedbackTone.neutral => Icons.visibility_outlined,
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: t.shadowLg,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(mark, size: 18, color: t.onFill),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  if (onPlay != null)
                    TextButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(l10n?.audioHearIt ?? 'Hear it'),
                      style: TextButton.styleFrom(
                        foregroundColor: ink,
                        backgroundColor: hue.withValues(alpha: 0.12),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              if (body != null && body!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tutorInitial != null) ...[
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.card,
                          border: Border.all(
                            color: hue.withValues(alpha: 0.22),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tutorInitial!,
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                    ],
                    Expanded(
                      child: Text(
                        body!,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: t.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (correctAnswer != null &&
                  correctAnswer!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      LessonKicker(l10n?.answerCorrectLabel ?? 'Correct'),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          correctAnswer!,
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (extra != null) ...[const SizedBox(height: 12), extra!],
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: Semantics(
                  label: continueSemanticsLabel ?? continueLabel,
                  button: true,
                  excludeSemantics: true,
                  child: FilledButton(
                    onPressed: busy ? null : onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: t.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child:
                        busy
                            ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(t.card),
                              ),
                            )
                            : Text(continueLabel),
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

/// Which of the three feedback voices a [FeedbackSheet] speaks in.
enum FeedbackTone { correct, incorrect, neutral }

/// Full-width primary action with the pressed-key depth the handoff uses on
/// lesson footers: a light top inner edge, a dark bottom one.
class KeyCta extends StatefulWidget {
  const KeyCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.foreground,
    this.radius = 24,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? foreground;

  /// 24 on the big step-forward keys, 16 where the comp pairs the button with
  /// a sibling of the same size (review's Go again / Done, for one).
  final double radius;

  @override
  State<KeyCta> createState() => _KeyCtaState();
}

class _KeyCtaState extends State<KeyCta> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = widget.onPressed != null;
    final base = widget.color ?? t.priFill;
    final fg = widget.foreground ?? t.onFill;
    final instant = MediaQuery.disableAnimationsOf(context);
    final pressed = _down && !instant;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: instant ? Duration.zero : const Duration(milliseconds: 120),
          transform: Matrix4.translationValues(0, pressed ? 2 : 0, 0),
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            color: enabled ? null : t.elev,
            // The key's depth lives in the gradient: a bright sliver along the
            // top edge and a dark one along the bottom. Drawing those as an
            // actual non-uniform Border is not legal alongside a border
            // radius, and a Stack of hairlines would not follow the corners.
            gradient:
                enabled
                    ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.05, 0.94, 1],
                      colors: [
                        Color.alphaBlend(
                          Colors.white.withValues(alpha: 0.34),
                          base,
                        ),
                        Color.alphaBlend(
                          Colors.white.withValues(alpha: 0.1),
                          base,
                        ),
                        base,
                        Color.alphaBlend(
                          Colors.black.withValues(alpha: 0.2),
                          base,
                        ),
                      ],
                    )
                    : null,
            boxShadow:
                enabled && !pressed
                    ? [
                      BoxShadow(
                        color: base.withValues(alpha: 0.45),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                        spreadRadius: -12,
                      ),
                    ]
                    : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: enabled ? fg : t.faint,
            ),
          ),
        ),
      ),
    );
  }
}

/// The accuracy ring on the lesson-complete screen: a thick sweep with the
/// score in the hole and a tick badge hung off the corner.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.fraction,
    required this.label,
    required this.caption,
    this.color,
    this.showBadge = true,
    this.size = 118,
  });

  /// 0–1. Drives the sweep, not the printed [label].
  final double fraction;
  final String label;
  final String caption;
  final Color? color;
  final bool showBadge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hue = color ?? t.greenInk;
    final inner = size - 20;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              strokeWidth: 10,
              // Flat ends: the comp draws these as conic sweeps, and a round
              // cap makes a 0% ring show a stub of colour it has not earned.
              strokeCap: StrokeCap.butt,
              backgroundColor: t.elev,
              valueColor: AlwaysStoppedAnimation(hue),
            ),
          ),
          Center(
            child: Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                color: t.card,
                shape: BoxShape.circle,
                border: Border.all(color: t.line),
              ),
              // Pad in from the stroke, then let FittedBox shrink the pair
              // rather than overflow the circle. The ring is a fixed size but
              // the text inside it is not: it grows with the device's font
              // scale, and the design system asks for 200% text scaling to
              // work.
              child: Padding(
                padding: EdgeInsets.all(inner * 0.16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 32,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: hue,
                        ),
                      ),
                      const SizedBox(height: 3),
                      LessonKicker(caption, color: t.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              right: -6,
              bottom: -4,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: t.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: hue, width: 2.5),
                  boxShadow: t.shadow,
                ),
                child: Icon(Icons.check, size: 20, color: hue),
              ),
            ),
        ],
      ),
    );
  }
}

/// A row of figures divided by hairlines — the results strip under the score
/// ring, and the same shape wherever two to four numbers sit side by side.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.cells});

  final List<StatCell> cells;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.line,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(24),
      ),
      // IntrinsicHeight because the strip is normally a child of a scroll
      // view: a stretching Row needs a bounded height, and without one this
      // asserted on every frame and painted nothing at all.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, cell) in cells.indexed) ...[
              // 1px of the container's own colour showing through is the
              // divider.
              if (i > 0) const SizedBox(width: 1),
              Expanded(
                child: Container(
                  color: t.card,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 15,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cell.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: cell.color ?? t.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cell.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One figure in a [StatStrip].
class StatCell {
  const StatCell({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;
}

/// Shakes its child once, horizontally — the wrong-answer tell.
///
/// Under reduced motion the shake becomes a coral outline flash, as the design
/// system requires of every named animation.
class ShakeOnce extends StatefulWidget {
  const ShakeOnce({super.key, required this.child, required this.trigger});

  final Widget child;

  /// Change this value to replay the shake.
  final Object? trigger;

  @override
  State<ShakeOnce> createState() => _ShakeOnceState();
}

class _ShakeOnceState extends State<ShakeOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    if (widget.trigger != null) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant ShakeOnce old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && widget.trigger != null) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (MediaQuery.disableAnimationsOf(context)) {
      return AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final flashing = widget.trigger != null && _c.value < 1;
          return Container(
            foregroundDecoration:
                flashing
                    ? BoxDecoration(
                      border: Border.all(color: t.redInk, width: 2),
                      borderRadius: BorderRadius.circular(24),
                    )
                    : null,
            child: child,
          );
        },
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Four decaying swings, matching the handoff's shakeX keyframes.
        final v = _c.value;
        final dx = v >= 1 ? 0.0 : -9 * (1 - v) * math.sin(v * 4 * math.pi);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Playback speed, shown as three visible choices rather than hidden behind a
/// button you have to press to discover.
///
/// The pace problem is not "make this one phrase slower" — it is "this is too
/// quick for me". So the control is a setting you can see the state of, it
/// applies to everything spoken afterwards, and it writes the same stored
/// value the Settings slider edits so the two can never disagree.
///
/// Three stops, not a slider: mid-lesson a learner wants one tap and a result,
/// and the Settings slider is still there for anyone who wants finer control.
class TtsSpeedSelector extends ConsumerWidget {
  const TtsSpeedSelector({super.key, this.stops = kTtsQuickSpeedStops});

  /// Which speeds to offer. Lessons show three; Settings shows all of them.
  final List<double> stops;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final rate = ref.watch(
      settingsProvider.select((settings) => settings.ttsSpeechRate),
    );
    final selected = nearestStopIndex(rate, stops: stops);

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Icon(Icons.speed_rounded, size: 18, color: t.faint),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  for (var i = 0; i < stops.length; i++)
                    Expanded(
                      child: _SpeedSegment(
                        label: formatSpeedMultiplier(stops[i]),
                        selected: i == selected,
                        onTap:
                            () => ref
                                .read(settingsProvider.notifier)
                                .setTtsSpeechRate(
                                  kNativeTtsSpeechRate * stops[i],
                                ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Which stop a stored rate belongs to.
  ///
  /// Nearest rather than exact: the Settings slider moves in steps that do not
  /// land on these stops, so a learner can leave the rate between two and the
  /// control still has to show something true.
  static int nearestStopIndex(
    double rate, {
    List<double> stops = kTtsQuickSpeedStops,
  }) {
    final multiplier = rate / kNativeTtsSpeechRate;
    var index = 0;
    for (var i = 1; i < stops.length; i++) {
      if ((stops[i] - multiplier).abs() < (stops[index] - multiplier).abs()) {
        index = i;
      }
    }
    return index;
  }
}

class _SpeedSegment extends StatelessWidget {
  const _SpeedSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Playback speed $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? t.priFill : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? t.onFill : t.muted,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
