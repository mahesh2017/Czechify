import 'package:flutter_test/flutter_test.dart';

import 'package:ceskina_pro/core/utils/text_normalizer.dart';

/// TTS must never read fill-in-the-blank markers aloud (they were being spoken
/// as "podtržítko") or editorial hints.
void main() {
  test('strips blank markers and parenthetical hints', () {
    expect(TextNormalizer.forSpeech('Vidím ___ (muž).'), 'Vidím.');
    expect(TextNormalizer.forSpeech('Já ___ student.'), 'Já student.');
    expect(TextNormalizer.forSpeech('Ahoj (informal)'), 'Ahoj');
  });

  test('leaves ordinary sentences unchanged', () {
    expect(TextNormalizer.forSpeech('Ahoj, jak se máš?'), 'Ahoj, jak se máš?');
    expect(TextNormalizer.forSpeech('káva'), 'káva');
  });

  test('collapses whitespace left by removed markers', () {
    expect(TextNormalizer.forSpeech('a  ___  b'), 'a b');
  });
}
