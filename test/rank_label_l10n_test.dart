import 'package:ceskina_pro/domain/entities/gamification_state.dart';
import 'package:ceskina_pro/l10n/app_localizations.dart';
import 'package:ceskina_pro/presentation/providers/gamification_providers.dart';
import 'package:ceskina_pro/presentation/widgets/common/xp_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

/// The tier names were English literals on the enum, so a Czech UI showed
/// "Bronze" next to fully translated chrome.
void main() {
  testWidgets('the rank badge is named in the app language', (tester) async {
    Future<void> pumpIn(Locale locale) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          gamificationProvider.overrideWith(_RankedNotifier.new),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const Scaffold(body: XpBadge()),
        ),
      ),
    );

    await pumpIn(const Locale('en'));
    expect(find.text('Gold'), findsOneWidget);

    await pumpIn(const Locale('cs'));
    expect(find.text('Zlato'), findsOneWidget);
    expect(find.text('Gold'), findsNothing);
  });

  test('every rank has a name in both languages', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final cs = await AppLocalizations.delegate.load(const Locale('cs'));

    for (final rank in Rank.values) {
      for (final l10n in [en, cs]) {
        expect(rankLabelFor(rank, l10n).trim(), isNotEmpty, reason: '$rank');
      }
    }
  });
}

/// Enough lifetime XP to sit in gold, which has a distinct name per language.
class _RankedNotifier extends GamificationNotifier {
  @override
  GamificationState build() =>
      GamificationState(totalXp: Rank.gold.xpThreshold);
}
