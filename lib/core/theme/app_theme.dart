import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// App-wide color palette and themes — Czechify 2.0.
///
/// The full design palette lives in [AppTokens] (a [ThemeExtension]); the
/// values below are the seed/primary colors used to derive the Material
/// [ColorScheme]. Screens should read visual tokens from `context.tokens`.
class AppColors {
  AppColors._();

  // Indigo — navigation and primary action.
  static const Color primary = Color(0xFF3355E8);
  static const Color primaryDark = Color(0xFF8098FF);

  // Warm amber — accent.
  static const Color accent = Color(0xFFE9992A);

  // Gamification colors (kept for existing widgets; align with tokens).
  static const Color xpGold = Color(0xFFE9992A);
  static const Color streakOrange = Color(0xFFE9992A);
  static const Color heartsRed = Color(0xFFF0503F);
  static const Color successGreen = Color(0xFF12A272);
  static const Color leaguePurple = Color(0xFF7355DC);
}

ThemeData lightTheme() => _build(Brightness.light, AppTokens.light);
ThemeData darkTheme() => _build(Brightness.dark, AppTokens.dark);

/// Minimum size for a button placed inside a [Row].
///
/// The button themes below use `Size.fromHeight(54)` for the full-width look
/// the design calls for — but that is `Size(double.infinity, 54)`, and a Row
/// gives its non-flex children *unbounded* width. An infinite minimum width
/// under an unbounded constraint is invalid: layout throws, and the whole
/// surrounding subtree renders blank (this is what blanked the mock exam).
///
/// So: any button that sits directly in a Row must pass this as its
/// `minimumSize`, or be wrapped in something that bounds its width
/// ([Expanded], [Flexible], a sized [SizedBox]).
const Size kRowButtonMinSize = Size(64, 54);

ThemeData _build(Brightness brightness, AppTokens t) {
  final isLight = brightness == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: t.pri,
    onPrimary: t.onFill,
    surface: t.card,
    onSurface: t.ink,
    error: t.red,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    fontFamily: AppFonts.body,
    extensions: [t],
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: t.ink, displayColor: t.ink, fontFamily: AppFonts.body)
        .copyWith(
          // Headline/display styles use the display face.
          displayLarge: _display(base, t),
          displayMedium: _display(base, t),
          displaySmall: _display(base, t),
          headlineLarge: _display(base, t),
          headlineMedium: _display(base, t),
          headlineSmall: _display(base, t),
          titleLarge: _display(base, t),
        ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: t.bg,
      foregroundColor: t.ink,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.display,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: t.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: t.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.priFill,
        foregroundColor: t.onFill,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: t.priFill,
        foregroundColor: t.onFill,
        elevation: 0,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: t.pri),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.pri,
        minimumSize: const Size.fromHeight(54),
        side: BorderSide(color: t.pri),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: t.chipBg,
      side: BorderSide.none,
      labelStyle: TextStyle(color: t.ink, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.card,
      indicatorColor: t.priSoft,
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? t.pri : t.faint,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 12.5,
          fontWeight:
              states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? t.pri : t.faint,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t.card,
      indicatorColor: t.priSoft,
      selectedIconTheme: IconThemeData(color: t.pri),
      unselectedIconTheme: IconThemeData(color: t.faint),
      selectedLabelTextStyle: TextStyle(
        color: t.pri,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(color: t.faint),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.pri,
      linearTrackColor: t.elev,
      circularTrackColor: t.elev,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.pri : t.elev,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: t.pri,
      inactiveTrackColor: t.elev,
      thumbColor: t.pri,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    listTileTheme: ListTileThemeData(iconColor: t.muted, textColor: t.ink),
    iconTheme: IconThemeData(color: t.muted),
    splashFactory: isLight ? InkSparkle.splashFactory : InkRipple.splashFactory,
  );
}

TextStyle _display(ThemeData base, AppTokens t) => TextStyle(
  fontFamily: AppFonts.display,
  fontWeight: FontWeight.w700,
  color: t.ink,
);
