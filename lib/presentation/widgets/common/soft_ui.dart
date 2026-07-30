import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// Shared building blocks for the "Calm & premium" redesign.
///
/// These mirror the recurring components in the design handoff: soft rounded
/// cards with a diffuse shadow, tinted icon tiles, pill chips, section labels,
/// progress bars, and the primary filled button.

/// A rounded card surface with the design's soft shadow.
///
/// Use instead of Material [Card] when you need padding, tap handling, an
/// optional border, or a non-default radius in one place.
class SoftCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = context.tokens;
    final decorated = Container(
      decoration: BoxDecoration(
        color: color ?? t.card,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadow ? t.shadow : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return decorated;
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
    this.bold = true,
    this.fontSize = 12,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final bool bold;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 10 : 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: track ?? t.elev,
        valueColor: AlwaysStoppedAnimation(color ?? t.pri),
      ),
    );
  }
}

/// The primary full-width filled action button used on lesson/quiz/review
/// footers, with an optional leading icon.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: t.onFill),
              const SizedBox(width: 10),
            ],
            Text(label),
          ],
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
