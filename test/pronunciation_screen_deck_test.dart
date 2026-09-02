import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/l10n/app_localizations.dart';
import 'package:czechify/presentation/providers/pronunciation_providers.dart';
import 'package:czechify/presentation/screens/pronunciation/pronunciation_screen.dart';

/// The Pronunciation Lab must practice real deck content, not a hardcoded
/// phrase (previously `/pronunciation/:id` ignored its content entirely).
void main() {
  Future<void> pumpLab(
    WidgetTester tester, {
    List<String>? deck,
    String? expectedText,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (deck != null)
            pronunciationDeckProvider.overrideWith((ref) async => deck),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: PronunciationScreen(
            exerciseId: 'practice',
            expectedText: expectedText,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deck mode shows the first deck phrase and can skip ahead', (
    tester,
  ) async {
    await pumpLab(tester, deck: ['První věta.', 'Druhá věta.']);

    expect(find.text('První věta.'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Druhá věta.'), findsOneWidget);

    // Deck wraps around instead of running out.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('První věta.'), findsOneWidget);
  });

  testWidgets('explicit expectedText pins the phrase (no skip control)', (
    tester,
  ) async {
    await pumpLab(tester, expectedText: 'Zadaná věta.');

    expect(find.text('Zadaná věta.'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('recording has one live pulse, owned by the record button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pronunciationProvider.overrideWith(
            _RecordingPronunciationNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PronunciationScreen(
            exerciseId: 'practice',
            expectedText: 'Ahoj.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Listening...'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Listening...'),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
  });
}

class _RecordingPronunciationNotifier extends PronunciationNotifier {
  @override
  PronunciationState build() =>
      const PronunciationState(expectedText: 'Ahoj.', isRecording: true);

  @override
  void setExpectedText(String text) {
    state = PronunciationState(expectedText: text, isRecording: true);
  }
}
