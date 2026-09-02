import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import 'motion_widgets.dart';

/// Shared building blocks for the "Calm & premium" redesign.
///
/// These mirror the recurring components in the design handoff: soft rounded
/// cards with a diffuse shadow, tinted icon tiles, pill chips, section labels,
/// progress bars, and the primary filled button.

/// A rounded card surface with the design's soft shadow.
///
/// Use instead of Material [Card] when you need padding, tap handling, an
/// optional border, or a non-default radius in one place.
class SoftCard extends StatefulWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.color,
    this.border,
    this.onTap,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = widget.radius;
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: context.motionDuration(AppMotion.press),
        curve: AppMotion.enter,
        child: Container(
          decoration: BoxDecoration(
            color: widget.color ?? t.card,
            borderRadius: BorderRadius.circular(radius),
            border: widget.border,
            boxShadow: widget.shadow ? t.shadow : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(radius),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded square holding an icon over a soft tint — the recurring
/// leading element on list rows and quick actions.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.fg,
    this.size = 40,
    this.radius = 12,
    this.iconSize = 18,
  });

  final IconData icon;
  final Color tint;
  final Color fg;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}

/// Small rounded pill — used for gender tags, level badges, counts.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
    this.iconColor,
    this.border,
    this.shadow,
    this.bold = true,
    this.fontSize = 12,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  /// Defaults to [fg]. On a tinted chip the glyph and the label share the
  /// hue's ink; on a neutral chip the glyph keeps its own meaning — the
  /// streak flame stays amber next to an ink-coloured number.
  final Color? iconColor;
  final Color? border;
  final List<BoxShadow>? shadow;
  final bool bold;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 9, 6, 11, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border!),
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor ?? fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet section heading. Tracked uppercase is reserved for lesson kickers.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: color ?? t.muted,
      ),
    );
  }
}

/// Rounded progress track matching the design (flat, capped fill).
class SoftProgressBar extends StatelessWidget {
  const SoftProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
    this.track,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MotionValueBuilder(
      value: value.clamp(0.0, 1.0),
      builder:
          (context, animated, _) => ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: animated,
              minHeight: height,
              backgroundColor: track ?? t.elev,
              valueColor: AlwaysStoppedAnimation(color ?? t.pri),
            ),
          ),
    );
  }
}

/// The primary full-width action button on the lesson, onboarding, teaching
/// and copybook footers.
///
/// The comp's CTA is a physical object rather than a flat rectangle: a
/// top-to-bottom gradient, a 2pt highlight along the top inside edge, a 3pt
/// shade along the bottom, and a tight drop shadow in the accent's own
/// colour. Flutter has no inset box-shadow, so the two edges are drawn as
/// clipped bands inside the rounded rect — visually identical, and it keeps
/// the corners correct.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.radius = 24,
    this.height = 60,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double radius;
  final double height;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = widget.onPressed != null;
    final fg = enabled ? t.onFill : t.faint;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: context.motionDuration(AppMotion.press),
          curve: AppMotion.enter,
          child: Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow:
                  enabled
                      ? [
                        BoxShadow(
                          color: t.priFill.withValues(alpha: .55),
                          blurRadius: 26,
                          spreadRadius: -12,
                          offset: const Offset(0, 12),
                        ),
                      ]
                      : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient:
                          enabled
                              ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.lerp(t.priFill, Colors.white, .12)!,
                                  t.priFill,
                                ],
                              )
                              : null,
                      color: enabled ? null : t.elev,
                    ),
                  ),
                  if (enabled) ...[
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 2,
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: .28),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 3,
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: .18),
                      ),
                    ),
                  ],
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: widget.onPressed,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, size: 18, color: fg),
                              const SizedBox(width: 10),
                            ],
                            Flexible(
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: fg,
                                ),
                              ),
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
        ),
      ),
    );
  }
}

/// Display-face heading text.
class DisplayText extends StatelessWidget {
  const DisplayText(
    this.text, {
    super.key,
    this.size = 26,
    this.color,
    this.weight = FontWeight.w700,
    this.height,
  });

  final String text;
  final double size;
  final Color? color;
  final FontWeight weight;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.display,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? t.ink,
      ),
    );
  }
}
