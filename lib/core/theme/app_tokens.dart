import 'package:flutter/material.dart';

/// Design tokens for the Czechify 2.0 redesign.
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
    required this.amberInk,
    required this.red,
    required this.redSoft,
    required this.redInk,
    required this.green,
    required this.greenSoft,
    required this.greenInk,
    required this.violet,
    required this.violetSoft,
    required this.violetInk,
    required this.chipBg,
    required this.userBubble,
    required this.userBubbleTxt,
    required this.shadow,
    required this.shadowLg,
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
  final Color amberInk;
  final Color red;
  final Color redSoft;
  final Color redInk;
  final Color green;
  final Color greenSoft;
  final Color greenInk;
  final Color violet;
  final Color violetSoft;
  final Color violetInk;

  /// Neutral chip background.
  final Color chipBg;

  /// Outgoing chat bubble background.
  final Color userBubble;

  /// Outgoing chat bubble text.
  final Color userBubbleTxt;

  /// Card shadow list.
  final List<BoxShadow> shadow;

  /// Elevated sheets and hero surfaces.
  final List<BoxShadow> shadowLg;

  static const light = AppTokens(
    bg: Color(0xFFFAF7F2),
    card: Color(0xFFFFFFFF),
    elev: Color(0xFFF2EDE4),
    ink: Color(0xFF17161C),
    muted: Color(0xFF5B5765),
    faint: Color(0xFF6E6979),
    line: Color(0xFFE8E2D7),
    pri: Color(0xFF3355E8),
    priFill: Color(0xFF3355E8),
    onFill: Color(0xFFFFFFFF),
    priSoft: Color(0xFFE7EBFF),
    priInk: Color(0xFF22308C),
    amber: Color(0xFFE9992A),
    amberSoft: Color(0xFFFFF0D9),
    // The comp says #9C6206, which lands at 4.496:1 on amberSoft — under the
    // 4.5:1 the design's own ink rule exists to guarantee. Kept a shade
    // darker so the rule actually holds; see app_tokens_test.dart.
    amberInk: Color(0xFF985F00),
    red: Color(0xFFF0503F),
    redSoft: Color(0xFFFFE9E5),
    redInk: Color(0xFFC8321F),
    green: Color(0xFF12A272),
    greenSoft: Color(0xFFE0F6EE),
    greenInk: Color(0xFF0A7A56),
    violet: Color(0xFF7355DC),
    violetSoft: Color(0xFFEEE9FF),
    violetInk: Color(0xFF5B3FBF),
    chipBg: Color(0xFFF2EDE4),
    userBubble: Color(0xFF3355E8),
    userBubbleTxt: Color(0xFFFFFFFF),
    // `0 1px 2px rgba(23,22,28,.05), 0 10px 28px -14px rgba(23,22,28,.28)`.
    // The negative spread is what keeps the ambient layer tight under the
    // card instead of haloing out from it — without it the same alpha reads
    // as a much weaker shadow, which is why cards looked flat.
    shadow: [
      BoxShadow(color: Color(0x0D17161C), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(
        color: Color(0x4717161C),
        blurRadius: 28,
        spreadRadius: -14,
        offset: Offset(0, 10),
      ),
    ],
    // `0 2px 4px rgba(23,22,28,.05), 0 28px 52px -28px rgba(23,22,28,.45)`.
    shadowLg: [
      BoxShadow(color: Color(0x0D17161C), blurRadius: 4, offset: Offset(0, 2)),
      BoxShadow(
        color: Color(0x7317161C),
        blurRadius: 52,
        spreadRadius: -28,
        offset: Offset(0, 28),
      ),
    ],
  );

  static const dark = AppTokens(
    bg: Color(0xFF0C0B11),
    card: Color(0xFF1B1A26),
    elev: Color(0xFF2B2937),
    ink: Color(0xFFF2F0EA),
    muted: Color(0xFFAFAABC),
    faint: Color(0xFF8A8598),
    line: Color(0xFF3E3B4E),
    pri: Color(0xFF8098FF),
    priFill: Color(0xFF425CCE),
    onFill: Color(0xFFFFFFFF),
    priSoft: Color(0xFF1F2549),
    priInk: Color(0xFFAFBEFF),
    amber: Color(0xFFF3BE6B),
    amberSoft: Color(0xFF382A12),
    amberInk: Color(0xFFF2BC66),
    red: Color(0xFFFF7D6D),
    redSoft: Color(0xFF3B201C),
    redInk: Color(0xFFFF9E8E),
    green: Color(0xFF4ECB9B),
    greenSoft: Color(0xFF123027),
    greenInk: Color(0xFF54DCA9),
    violet: Color(0xFFA897F5),
    violetSoft: Color(0xFF251F44),
    violetInk: Color(0xFFC2B2FF),
    chipBg: Color(0xFF2B2937),
    userBubble: Color(0xFF425CCE),
    userBubbleTxt: Color(0xFFFFFFFF),
    // `0 1px 2px rgba(0,0,0,.5), 0 12px 30px -16px rgba(0,0,0,.8)`.
    shadow: [
      BoxShadow(color: Color(0x80000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(
        color: Color(0xCC000000),
        blurRadius: 30,
        spreadRadius: -16,
        offset: Offset(0, 12),
      ),
    ],
    // `0 2px 6px rgba(0,0,0,.55), 0 30px 56px -28px rgba(0,0,0,.9)`.
    shadowLg: [
      BoxShadow(color: Color(0x8C000000), blurRadius: 6, offset: Offset(0, 2)),
      BoxShadow(
        color: Color(0xE6000000),
        blurRadius: 56,
        spreadRadius: -28,
        offset: Offset(0, 30),
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
    Color? amberInk,
    Color? red,
    Color? redSoft,
    Color? redInk,
    Color? green,
    Color? greenSoft,
    Color? greenInk,
    Color? violet,
    Color? violetSoft,
    Color? violetInk,
    Color? chipBg,
    Color? userBubble,
    Color? userBubbleTxt,
    List<BoxShadow>? shadow,
    List<BoxShadow>? shadowLg,
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
      amberInk: amberInk ?? this.amberInk,
      red: red ?? this.red,
      redSoft: redSoft ?? this.redSoft,
      redInk: redInk ?? this.redInk,
      green: green ?? this.green,
      greenSoft: greenSoft ?? this.greenSoft,
      greenInk: greenInk ?? this.greenInk,
      violet: violet ?? this.violet,
      violetSoft: violetSoft ?? this.violetSoft,
      violetInk: violetInk ?? this.violetInk,
      chipBg: chipBg ?? this.chipBg,
      userBubble: userBubble ?? this.userBubble,
      userBubbleTxt: userBubbleTxt ?? this.userBubbleTxt,
      shadow: shadow ?? this.shadow,
      shadowLg: shadowLg ?? this.shadowLg,
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
      amberInk: c(amberInk, other.amberInk),
      red: c(red, other.red),
      redSoft: c(redSoft, other.redSoft),
      redInk: c(redInk, other.redInk),
      green: c(green, other.green),
      greenSoft: c(greenSoft, other.greenSoft),
      greenInk: c(greenInk, other.greenInk),
      violet: c(violet, other.violet),
      violetSoft: c(violetSoft, other.violetSoft),
      violetInk: c(violetInk, other.violetInk),
      chipBg: c(chipBg, other.chipBg),
      userBubble: c(userBubble, other.userBubble),
      userBubbleTxt: c(userBubbleTxt, other.userBubbleTxt),
      shadow: t < 0.5 ? shadow : other.shadow,
      shadowLg: t < 0.5 ? shadowLg : other.shadowLg,
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
