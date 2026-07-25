import 'package:flutter_test/flutter_test.dart';

import 'package:ceskina_pro/domain/engines/pronunciation_coverage.dart';

/// The acoustic model is only trustworthy on part of the vocabulary. Being
/// wrongly told you mispronounced something is more damaging than not being
/// scored, so every uncertain case must fall back to transcript scoring rather
/// than guess.
void main() {
  final coverage = PronunciationCoverage.forTest([
    'dobrý den',
    'řeka',
    'Nashledanou',
  ]);

  test('measured-reliable phrases are supported', () {
    expect(coverage.supports('dobrý den'), isTrue);
    expect(coverage.supports('řeka'), isTrue);
  });

  test('matching ignores case and surrounding space', () {
    expect(coverage.supports('  Dobrý Den '), isTrue);
    expect(coverage.supports('nashledanou'), isTrue);
  });

  test('unmeasured phrases are not supported', () {
    expect(coverage.supports('přezkoušení'), isFalse);
  });

  /// Twelve one-character items averaged 117% error when measured — worse than
  /// chance ("a" heard as "e", "č" as "tři"). This is what keeps the Unit 1
  /// alphabet card away from phoneme scoring.
  test('single letters are rejected even if listed', () {
    final withLetters = PronunciationCoverage.forTest(['a', 'č', 'ř', 'z']);
    for (final letter in ['a', 'č', 'ř', 'z']) {
      expect(withLetters.supports(letter), isFalse,
          reason: '"$letter" must never be phoneme-scored');
    }
  });

  test('very short words are rejected', () {
    final short = PronunciationCoverage.forTest(['ano', 'ne', 'byt']);
    expect(short.supports('ne'), isFalse);
    expect(short.supports('ano'), isFalse);
  });

  test('an empty list supports nothing', () {
    final none = PronunciationCoverage.forTest(const []);
    expect(none.supports('dobrý den'), isFalse);
    expect(none.supportedCount, 0);
  });
}
