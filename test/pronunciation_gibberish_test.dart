import 'package:flutter_test/flutter_test.dart';

import 'package:czechify/domain/engines/pronunciation_scorer.dart';

/// A learner reported passing scores (~95%) while deliberately speaking
/// gibberish. These tests pin down what the *scorer* must do when it is handed
/// an honest transcript, so that the scoring layer can never be the thing that
/// rewards nonsense.
void main() {
  final scorer = PronunciationScorer();

  double pct(String expected, String actual) =>
      scorer
          .score(expectedText: expected, actualTranscription: actual)
          .overallScore *
      100;

  group('gibberish must not pass', () {
    test('completely unrelated words score far below a pass', () {
      final score = pct('Dobrý den, jak se máte?', 'blah blah wibble wobble');
      expect(score, lessThan(40), reason: 'gibberish scored $score%');
    });

    test('nonsense syllables score near zero', () {
      final score = pct('Potřebuji lékaře.', 'ba da ga la');
      expect(score, lessThan(40), reason: 'nonsense scored $score%');
    });

    test('silence (empty transcript) scores zero', () {
      expect(pct('Dobrý den', ''), 0);
    });

    test('saying only one word of five does not pass', () {
      final score = pct('Dobrý den jak se máte', 'dobrý');
      expect(score, lessThan(50), reason: 'one of five scored $score%');
    });
  });

  group('correct speech still scores well', () {
    test('exact match is full marks', () {
      expect(pct('Dobrý den', 'Dobrý den'), 100);
    });

    test('punctuation and case are ignored', () {
      expect(pct('Dobrý den, jak se máte?', 'dobrý den jak se máte'), 100);
    });

    test('a single mispronounced word still scores well overall', () {
      final score = pct('Dobrý den jak se máte', 'dobrý den jak se mate');
      expect(score, greaterThan(70));
      expect(score, lessThan(100));
    });
  });

  group('padding the answer must not be free', () {
    test('correct phrase buried in extra words is penalised', () {
      final clean = pct('Dobrý den', 'dobrý den');
      final padded = pct(
        'Dobrý den',
        'dobrý den a taky nevím co říkám tady je hodně slov',
      );
      expect(
        padded,
        lessThan(clean),
        reason: 'padding scored $padded vs clean $clean',
      );
    });

    /// The Whisper path re-derives the overall score after blending in
    /// per-word confidence. It needs this count to keep the same denominator
    /// as the scorer; without it, padding became free again downstream.
    test('extra words are reported so re-scoring can still penalise them', () {
      final result = scorer.score(
        expectedText: 'Dobrý den',
        actualTranscription: 'dobrý den a ještě něco navíc',
      );
      expect(result.insertionCount, 4);
    });

    test('a clean answer reports no extra words', () {
      final result = scorer.score(
        expectedText: 'Dobrý den',
        actualTranscription: 'dobrý den',
      );
      expect(result.insertionCount, 0);
    });
  });

  test('a score can never exceed 100%', () {
    for (final pair in [
      ['Dobrý den', 'dobrý den'],
      ['ano ano ano', 'ano ano ano'],
      ['To je to', 'to je to'],
    ]) {
      expect(pct(pair[0], pair[1]), lessThanOrEqualTo(100));
    }
  });
}
