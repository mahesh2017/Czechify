import 'package:flutter_test/flutter_test.dart';
import 'package:ceskina_pro/core/utils/text_normalizer.dart';

void main() {
  group('TextNormalizer.matchesIgnoringDiacritics', () {
    test('exact match is a match', () {
      expect(
        TextNormalizer.matchesIgnoringDiacritics('děkuji', 'děkuji'),
        isTrue,
      );
    });

    test('diacritics-only difference is treated as a match', () {
      expect(
        TextNormalizer.matchesIgnoringDiacritics('děkuji', 'dekuji'),
        isTrue,
      );
      expect(TextNormalizer.matchesIgnoringDiacritics('řeka', 'reka'), isTrue);
    });

    test('is case and whitespace insensitive', () {
      expect(
        TextNormalizer.matchesIgnoringDiacritics('Dobrý  den', 'dobry den'),
        isTrue,
      );
    });

    test('a genuinely different word is not a match', () {
      expect(TextNormalizer.matchesIgnoringDiacritics('pes', 'kočka'), isFalse);
      expect(TextNormalizer.matchesIgnoringDiacritics('máma', 'táta'), isFalse);
    });
  });
}
