import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// Maps a flashcard `gender` string to a short pill label + token colors.
///
/// Single source of truth for gender colouring. The lesson player and the SRS
/// review screen previously each had their own mapping, and they disagreed —
/// the review screen used raw Material colours that were unreadable in dark
/// mode. Anything that colours a gender goes through here.
({String label, Color bg, Color fg}) genderPill(
  BuildContext context,
  String g,
) {
  final t = context.tokens;
  final v = g.toLowerCase();
  if (v.startsWith('fem')) return (label: 'fem', bg: t.redSoft, fg: t.red);
  if (v.startsWith('neut')) {
    return (label: 'neut', bg: t.amberSoft, fg: t.amber);
  }
  if (v.contains('inanimate')) {
    return (label: 'masc inan', bg: t.violetSoft, fg: t.violet);
  }
  if (v.startsWith('masc')) {
    return (label: 'masc anim', bg: t.priSoft, fg: t.priInk);
  }
  return (label: g, bg: t.chipBg, fg: t.muted);
}

/// The pill itself, rendered from [genderPill].
class GenderPill extends StatelessWidget {
  final String gender;

  /// When false, shows the full gender string rather than the short label —
  /// the flashcard front has room for it, the lesson word card does not.
  final bool abbreviated;

  const GenderPill({super.key, required this.gender, this.abbreviated = true});

  @override
  Widget build(BuildContext context) {
    final pill = genderPill(context, gender);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: pill.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        abbreviated ? pill.label : gender,
        style: TextStyle(
          color: pill.fg,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
