import 'package:czechify/domain/engines/phoneme_scorer.dart';
import 'package:czechify/domain/engines/pronunciation_scorer.dart';
import 'package:czechify/domain/entities/pronunciation_result.dart';
import 'package:czechify/l10n/app_localizations.dart';
import 'package:czechify/presentation/widgets/common/pronunciation_tip_text.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coaching used to be English prose built inside the scorers, so a learner
/// with the app in Czech was told "Practice the ř sound" in English and no
/// translation could reach it.
void main() {
  late AppLocalizations en;
  late AppLocalizations cs;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    cs = await AppLocalizations.delegate.load(const Locale('cs'));
  });

  test('every tip code says something in both languages', () {
    for (final code in PronunciationTipCode.values) {
      final tip = PronunciationTip(
        code,
        sound: 'ř',
        word: 'řeka',
        heard: 'r',
      );

      for (final entry in {'en': en, 'cs': cs}.entries) {
        final text = tip.localized(entry.value);
        expect(text.trim(), isNotEmpty, reason: '$code has no ${entry.key}');
        expect(
          text,
          isNot(contains('{')),
          reason: '$code left a placeholder unfilled in ${entry.key}',
        );
      }
    }
  });

  test('the same code reads differently in each language', () {
    // Guards against a Czech entry that was copied from English and never
    // translated — which is the state this change exists to end.
    const tip = PronunciationTip(PronunciationTipCode.vowelLength);
    expect(tip.localized(cs), isNot(tip.localized(en)));
  });

  test('the word scorer names a problem sound without writing prose', () {
    final result = PronunciationScorer().score(
      expectedText: 'řeka',
      actualTranscription: 'reka',
    );

    expect(result.tips, isNotEmpty);
    // What the engine hands back is a code; the sentence is chosen later.
    expect(
      localizedTips(result.tips, cs),
      isNot(localizedTips(result.tips, en)),
    );
  });

  test('a phoneme substitution is coached in Czech too', () {
    final assessment = PhonemeScorer().score(
      expectedIpa: 'ˈr̝ɛka',
      actualIpa: 'rɛka',
    );

    expect(assessment.tips.first.code, PronunciationTipCode.rolledRAsPlainR);
    expect(assessment.displayTips.first.localized(cs), contains('ř'));
  });
}
