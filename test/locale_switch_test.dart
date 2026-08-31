import 'package:czechify/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ARB files can be in perfect parity and the app can still ship
/// English-only — if `cs` never reaches `supportedLocales`, or a screen holds
/// a hardcoded string, nothing fails. These tests exercise the real lookup.
void main() {
  Widget host(Locale? locale, Widget child) => MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  test('Czech is an offered locale', () {
    expect(
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      containsAll(<String>['en', 'cs']),
    );
  });

  testWidgets('navigation labels resolve per locale', (tester) async {
    Future<List<String>> labelsFor(Locale locale) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        host(
          locale,
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return [l10n.navHome, l10n.navLearn, l10n.navReview, l10n.navStats];
    }

    expect(await labelsFor(const Locale('en')), [
      'Home',
      'Learn',
      'Review',
      'Stats',
    ]);
    expect(await labelsFor(const Locale('cs')), [
      'Domů',
      'Učit se',
      'Opakování',
      'Statistiky',
    ]);
  });

  testWidgets('Czech plurals use one/few/other, not a single form', (
    tester,
  ) async {
    late AppLocalizations cs;
    await tester.pumpWidget(
      host(
        const Locale('cs'),
        Builder(
          builder: (context) {
            cs = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // Czech inflects across three bands; English would collapse 2 and 5.
    expect(cs.homeDayStreak(1), '1 den v řadě');
    expect(cs.homeDayStreak(3), '3 dny v řadě');
    expect(cs.homeDayStreak(7), '7 dní v řadě');

    expect(cs.homeHeartsRemaining(1), 'Zbývá 1 srdíčko');
    expect(cs.homeHeartsRemaining(2), 'Zbývají 2 srdíčka');
    expect(cs.homeHeartsRemaining(5), 'Zbývá 5 srdíček');
  });

  testWidgets('placeholders survive translation', (tester) async {
    late AppLocalizations cs;
    await tester.pumpWidget(
      host(
        const Locale('cs'),
        Builder(
          builder: (context) {
            cs = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(cs.lessonQuestionOf(2, 10), 'Otázka 2 z 10');
    expect(cs.reviewCardOf(3, 12), 'Karta 3 z 12');
    expect(cs.settingsXpPerDay(50), '50 XP denně');
  });
}
