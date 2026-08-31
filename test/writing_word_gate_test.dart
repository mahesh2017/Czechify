import 'package:czechify/domain/engines/writing_word_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WritingWordGate.countWords', () {
    test('counts whitespace-separated words', () {
      expect(WritingWordGate.countWords('Dobrý den, jak se máte?'), 5);
    });

    test('collapses irregular whitespace and newlines', () {
      expect(WritingWordGate.countWords('  ahoj\n\n  světe   '), 2);
    });

    test('ignores stray punctuation tokens', () {
      expect(WritingWordGate.countWords('ano — ne . tak'), 3);
    });

    test('empty or blank text is zero words', () {
      expect(WritingWordGate.countWords(''), 0);
      expect(WritingWordGate.countWords('   '), 0);
    });

    test('counts Czech diacritics as letters', () {
      expect(WritingWordGate.countWords('řeka teče přes město'), 4);
    });
  });

  group('WritingWordGate.belowMinimum', () {
    test('true when fewer words than the minimum', () {
      expect(WritingWordGate.belowMinimum('jen tři slova tady', 35), isTrue);
    });

    test('false when exactly at the minimum', () {
      final text = List.filled(35, 'slovo').join(' ');
      expect(WritingWordGate.belowMinimum(text, 35), isFalse);
    });

    test('false when above the minimum', () {
      final text = List.filled(40, 'slovo').join(' ');
      expect(WritingWordGate.belowMinimum(text, 35), isFalse);
    });

    test('no gate when minWords is null or non-positive', () {
      expect(WritingWordGate.belowMinimum('', null), isFalse);
      expect(WritingWordGate.belowMinimum('', 0), isFalse);
      expect(WritingWordGate.belowMinimum('x', -5), isFalse);
    });
  });
}
