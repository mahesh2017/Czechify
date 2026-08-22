import 'package:flutter_test/flutter_test.dart';

import 'package:ceskina_pro/core/utils/ipa.dart';
import 'package:ceskina_pro/domain/engines/phoneme_features.dart';
import 'package:ceskina_pro/domain/engines/phoneme_scorer.dart';
import 'package:ceskina_pro/domain/entities/pronunciation_result.dart';

void main() {
  group('IPA tokenizer', () {
    List<String> tok(String s) =>
        IpaTokenizer.tokenize(s).map((p) => p.symbol).toList();

    test('keeps ř as one sound instead of r + orphan diacritic', () {
      // r̝ is r + U+031D. Splitting by character would make ř look like r,
      // hiding the single most important Czech pronunciation error.
      expect(tok('r̝ɛka'), ['r̝', 'ɛ', 'k', 'a']);
    });

    test('keeps a tie-barred affricate together', () {
      expect(tok('t͡ʃaj'), ['t͡ʃ', 'a', 'j']);
    });

    test('attaches the length mark to its vowel', () {
      expect(tok('ˈdobriː'), ['d', 'o', 'b', 'r', 'iː']);
    });

    test('drops stress marks and word spaces', () {
      expect(tok('ˈdobriː dɛn'), ['d', 'o', 'b', 'r', 'iː', 'd', 'ɛ', 'n']);
    });

    test('long and short vowels are distinct symbols', () {
      expect(tok('iː'), isNot(tok('i')));
      expect(const Ipa('iː').isLong, isTrue);
      expect(const Ipa('iː').base, 'i');
    });
  });

  group('articulatory similarity', () {
    test('identical sounds match exactly', () {
      expect(CzechPhonemes.similarity('r̝', 'r̝'), 1.0);
    });

    test('r for ř is a near miss, not a random error', () {
      final near = CzechPhonemes.similarity('r̝', 'r');
      final far = CzechPhonemes.similarity('r̝', 'k');
      expect(near, greaterThan(far));
      expect(near, greaterThan(0.5));
      expect(far, lessThan(0.4));
    });

    test('vowel length is a partial, not total, mismatch', () {
      final s = CzechPhonemes.similarity('iː', 'i');
      expect(s, greaterThan(0.5));
      expect(s, lessThan(1.0));
    });

    test('a vowel and a consonant are never similar', () {
      expect(CzechPhonemes.similarity('a', 'k'), 0.0);
    });

    test('voicing pairs are close but not equal', () {
      final s = CzechPhonemes.similarity('t', 'd');
      expect(s, greaterThan(0.5));
      expect(s, lessThan(1.0));
    });
  });

  group('scoring', () {
    final scorer = PhonemeScorer();

    test('a perfect repetition scores full marks', () {
      final r = scorer.score(
        expectedIpa: 'ˈdobriː dɛn',
        actualIpa: 'dobriː dɛn',
      );
      expect(r.overallScore, 1.0);
      expect(r.band, PronunciationBand.excellent);
      expect(r.tips, isEmpty);
    });

    test('gibberish scores near zero', () {
      final r = scorer.score(expectedIpa: 'ˈdobriː dɛn', actualIpa: 'blaːblaː');
      expect(r.overallScore, lessThan(0.4));
      expect(r.band, PronunciationBand.tryAgain);
    });

    test('silence scores zero', () {
      final r = scorer.score(expectedIpa: 'ˈr̝ɛka', actualIpa: '');
      expect(r.overallScore, 0.0);
    });

    /// The whole point of phoneme-level scoring: this substitution is invisible
    /// to a transcript comparison, because an ASR writes "řeka" either way.
    test('substituting r for ř is caught and named', () {
      final r = scorer.score(expectedIpa: 'ˈr̝ɛka', actualIpa: 'rɛka');
      expect(r.overallScore, lessThan(1.0));
      // The engine names the problem with a code now; the sentence about it
      // lives in the l10n files, where a Czech learner can be told in Czech.
      expect(
        r.tips.first.code,
        PronunciationTipCode.rolledRAsPlainR,
      );
    });

    test('ř errors weigh more than an equally-close error elsewhere', () {
      final rhacek = scorer.score(expectedIpa: 'r̝a', actualIpa: 'ra');
      final plain = scorer.score(expectedIpa: 'ta', actualIpa: 'da');
      expect(rhacek.overallScore, lessThan(plain.overallScore));
    });

    test('shortening a long vowel is flagged as meaning-bearing', () {
      final r = scorer.score(expectedIpa: 'biːt', actualIpa: 'bit');
      expect(r.overallScore, lessThan(1.0));
      expect(r.tips.first.code, PronunciationTipCode.vowelTooShort);
    });

    test('a dropped sound is reported', () {
      final r = scorer.score(expectedIpa: 'dɛn', actualIpa: 'dɛ');
      expect(r.overallScore, lessThan(1.0));
      expect(
        r.tips.map((t) => t.code),
        contains(PronunciationTipCode.soundDropped),
      );
    });

    test('added sounds cannot inflate the score', () {
      final clean = scorer.score(expectedIpa: 'dɛn', actualIpa: 'dɛn');
      final padded = scorer.score(expectedIpa: 'dɛn', actualIpa: 'dɛn aaaaa');
      expect(padded.overallScore, lessThan(clean.overallScore));
    });

    test('feedback stays short enough to act on', () {
      final r = scorer.score(
        expectedIpa: 'ˈr̝ɛkaː ɟɛlaː biːt',
        actualIpa: 'rɛka dela bit',
      );
      expect(r.tips.length, lessThanOrEqualTo(3));
    });

    /// A high average must not tell a learner "good" about the one sound they
    /// cannot yet produce.
    test('missing ř holds the band back even with most sounds right', () {
      final r = scorer.score(expectedIpa: 'ˈr̝ɛka', actualIpa: 'rɛka');
      expect(
        r.overallScore,
        greaterThan(0.65),
        reason: 'most phonemes were right, so the mean stays high',
      );
      expect(r.missedCriticalSound, isTrue);
      expect(
        r.band,
        PronunciationBand.needsWork,
        reason: 'band must not say "good" when ř failed',
      );
    });

    test('shortening a long vowel also holds the band back', () {
      final r = scorer.score(expectedIpa: 'biːt', actualIpa: 'bit');
      expect(r.missedCriticalSound, isTrue);
      expect(r.band, PronunciationBand.needsWork);
    });

    test('a clean attempt is not held back', () {
      final r = scorer.score(expectedIpa: 'ˈr̝ɛka', actualIpa: 'r̝ɛka');
      expect(r.missedCriticalSound, isFalse);
      expect(r.band, PronunciationBand.excellent);
    });

    test('an untied affricate still aligns against the affricate', () {
      // A recogniser writes č as "tʃ" with no tie bar; it must not be blamed
      // on a bare "t" plus a stray "ʃ".
      final r = scorer.score(expectedIpa: 't͡ʃaj', actualIpa: 'tʃaj');
      expect(r.overallScore, 1.0);
    });

    test('c for č is a graded error, not a total mismatch', () {
      final r = scorer.score(expectedIpa: 't͡ʃaj', actualIpa: 'tsaj');
      expect(r.overallScore, greaterThan(0.5));
      expect(r.overallScore, lessThan(1.0));
    });

    test('score never leaves 0..1', () {
      for (final pair in [
        ['ˈr̝ɛka', 'r̝ɛka'],
        ['aːaːaː', 'aaa'],
        ['dɛn', 'xxxxxxxx'],
      ]) {
        final s =
            scorer.score(expectedIpa: pair[0], actualIpa: pair[1]).overallScore;
        expect(s, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
