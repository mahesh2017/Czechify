import 'package:flutter/material.dart';

/// Design tokens for the "Calm & premium" redesign — Vltava teal + warm amber.
///
/// Mirrors the CSS custom properties from the design handoff so every screen
/// reads the same palette and it flips automatically between light and dark.
///
/// Access via `Theme.of(context).extension<AppTokens>()!` or the
/// `context.tokens` extension below.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.card,
    required this.elev,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.pri,
    required this.priFill,
    required this.onFill,
    required this.priSoft,
    required this.priInk,
    required this.amber,
    required this.amberSoft,
    required this.red,
    required this.redSoft,
    required this.green,
    required this.greenSoft,
    required this.violet,
    required this.violetSoft,
    required this.chipBg,
    required this.userBubble,
    required this.userBubbleTxt,
    required this.shadow,
  });

  /// Screen background.
  final Color bg;

  /// Elevated surface / cards.
  final Color card;

  /// Recessed surface (track backgrounds, canvas).
  final Color elev;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color muted;

  /// Tertiary text / disabled icons.
  final Color faint;

  /// Hairline separators.
  final Color line;

  /// Primary accent (teal) for text/icons.
  final Color pri;

  /// Primary fill (solid teal button / hero background).
  final Color priFill;

  /// Text/icon color on top of [priFill].
  final Color onFill;

  /// Soft teal tint (chips, icon tiles).
  final Color priSoft;

  /// Deep teal for text on [priSoft].
  final Color priInk;

  final Color amber;
  final Color amberSoft;
  final Color red;
  final Color redSoft;
  final Color green;
  final Color greenSoft;
  final Color violet;
  final Color violetSoft;

  /// Neutral chip background.
  final Color chipBg;

  /// Outgoing chat bubble background.
  final Color userBubble;

  /// Outgoing chat bubble text.
  final Color userBubbleTxt;

  /// Card shadow list.
  final List<BoxShadow> shadow;

  static const light = AppTokens(
    bg: Color(0xFFF6F4EF),
    card: Color(0xFFFFFFFF),
    elev: Color(0xFFEFECE4),
    ink: Color(0xFF1E1C26),
    muted: Color(0xFF5A5664),
    faint: Color(0xFF85818E),
    line: Color(0x141E1C26), // rgba(30,28,38,.08)
    pri: Color(0xFF1F6F6B),
    priFill: Color(0xFF1F6F6B),
    onFill: Color(0xFFFFFFFF),
    priSoft: Color(0xFFE2EEEC),
    priInk: Color(0xFF14504C),
    amber: Color(0xFFC98A2D),
    amberSoft: Color(0xFFF6EBD8),
    red: Color(0xFFBE4B42),
    redSoft: Color(0xFFF7E4E1),
    green: Color(0xFF48875F),
    greenSoft: Color(0xFFE3EFE6),
    violet: Color(0xFF6B5CA5),
    violetSoft: Color(0xFFEBE7F5),
    chipBg: Color(0xFFF0EEE8),
    userBubble: Color(0xFF1F6F6B),
    userBubbleTxt: Color(0xFFFFFFFF),
    shadow: [
      BoxShadow(color: Color(0x0D1E1C26), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0F1E1C26), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  static const dark = AppTokens(
    bg: Color(0xFF141319),
    card: Color(0xFF1E1C25),
    elev: Color(0xFF282631),
    ink: Color(0xFFF1EFE9),
    muted: Color(0xFFB0ACBB),
    faint: Color(0xFF868294),
    line: Color(0x17F1EFE9), // rgba(241,239,233,.09)
    pri: Color(0xFF63BFB8),
    priFill: Color(0xFF2A6A66),
    onFill: Color(0xFFF1EFE9),
    priSoft: Color(0xFF1E3532),
    priInk: Color(0xFF9ADDD6),
    amber: Color(0xFFE4AF5E),
    amberSoft: Color(0xFF332A1B),
    red: Color(0xFFE1786E),
    redSoft: Color(0xFF37211F),
    green: Color(0xFF7DBC93),
    greenSoft: Color(0xFF20301F),
    violet: Color(0xFFA79ADB),
    violetSoft: Color(0xFF292440),
    chipBg: Color(0xFF26242E),
    userBubble: Color(0xFF2A6A66),
    userBubbleTxt: Color(0xFFF1EFE9),
    shadow: [
      BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(
        color: Color(0x59000000),
        blurRadius: 28,
        offset: Offset(0, 10),
      ),
    ],
  );

  @override
  AppTokens copyWith({
    Color? bg,
    Color? card,
    Color? elev,
    Color? ink,
    Color? muted,
    Color? faint,
    Color? line,
    Color? pri,
    Color? priFill,
    Color? onFill,
    Color? priSoft,
    Color? priInk,
    Color? amber,
    Color? amberSoft,
    Color? red,
    Color? redSoft,
    Color? green,
    Color? greenSoft,
    Color? violet,
    Color? violetSoft,
    Color? chipBg,
    Color? userBubble,
    Color? userBubbleTxt,
    List<BoxShadow>? shadow,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      elev: elev ?? this.elev,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      line: line ?? this.line,
      pri: pri ?? this.pri,
      priFill: priFill ?? this.priFill,
      onFill: onFill ?? this.onFill,
      priSoft: priSoft ?? this.priSoft,
      priInk: priInk ?? this.priInk,
      amber: amber ?? this.amber,
      amberSoft: amberSoft ?? this.amberSoft,
      red: red ?? this.red,
      redSoft: redSoft ?? this.redSoft,
      green: green ?? this.green,
      greenSoft: greenSoft ?? this.greenSoft,
      violet: violet ?? this.violet,
      violetSoft: violetSoft ?? this.violetSoft,
      chipBg: chipBg ?? this.chipBg,
      userBubble: userBubble ?? this.userBubble,
      userBubbleTxt: userBubbleTxt ?? this.userBubbleTxt,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      bg: c(bg, other.bg),
      card: c(card, other.card),
      elev: c(elev, other.elev),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      faint: c(faint, other.faint),
      line: c(line, other.line),
      pri: c(pri, other.pri),
      priFill: c(priFill, other.priFill),
      onFill: c(onFill, other.onFill),
      priSoft: c(priSoft, other.priSoft),
      priInk: c(priInk, other.priInk),
      amber: c(amber, other.amber),
      amberSoft: c(amberSoft, other.amberSoft),
      red: c(red, other.red),
      redSoft: c(redSoft, other.redSoft),
      green: c(green, other.green),
      greenSoft: c(greenSoft, other.greenSoft),
      violet: c(violet, other.violet),
      violetSoft: c(violetSoft, other.violetSoft),
      chipBg: c(chipBg, other.chipBg),
      userBubble: c(userBubble, other.userBubble),
      userBubbleTxt: c(userBubbleTxt, other.userBubbleTxt),
      shadow: t < 0.5 ? shadow : other.shadow,
    );
  }
}

/// Font family constants — bundled variable fonts.
class AppFonts {
  AppFonts._();

  /// Display / headings.
  static const display = 'Bricolage Grotesque';

  /// Body / UI.
  static const body = 'Schibsted Grotesk';
}

/// Convenience accessor: `context.tokens`.
extension AppTokensX on BuildContext {
  /// Falls back to the light/dark constants when the ambient theme carries no
  /// [AppTokens] extension. The app always installs one, but widgets are also
  /// pumped bare in tests and can appear under a plain [Theme] — a matching
  /// fallback beats a null-check crash, and picking by brightness keeps the
  /// colours readable either way.
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ??
        (theme.brightness == Brightness.dark
            ? AppTokens.dark
            : AppTokens.light);
  }
}
