import 'package:czechify/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The delegates every screen-level widget needs in a widget test.
///
/// Widgets that read `AppLocalizations.of(context)` assert on a missing
/// `Localizations` ancestor, which the real app always provides through its
/// `MaterialApp`. A bare `MaterialApp()` in a test does not, so pumping one
/// of those widgets throws on a null check that can never fire in production.
///
/// Spread these into the test's `MaterialApp` rather than reaching for a
/// nullable lookup in the widget — the coupling is real and the app satisfies
/// it; only the harness was under-specified.
const List<LocalizationsDelegate<dynamic>> testLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Locales the test harness offers. English keeps assertions readable.
const List<Locale> testSupportedLocales = [Locale('en'), Locale('cs')];
