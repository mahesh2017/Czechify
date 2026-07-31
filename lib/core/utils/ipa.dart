/// IPA handling for phoneme-level pronunciation scoring.
///
/// Splitting an IPA string by character is wrong and quietly destroys the
/// sounds that matter most in Czech: `ř` is `r` + U+031D (combining up tack),
/// and `t͡ʃ` is `t` + U+0361 (tie bar) + `ʃ`. Naive splitting turns the
/// signature Czech consonant into a plain `r` plus an orphan mark, so a learner
/// substituting `r` for `ř` would look perfect.
library;

/// One pronounceable unit — a base symbol plus any diacritics, tie-bar
/// partner, and length mark that belong to it.
class Ipa {
  /// The full symbol as written, e.g. `r̝`, `iː`, `t͡ʃ`.
  final String symbol;

  const Ipa(this.symbol);

  /// The symbol without its length mark, so `iː` and `i` share a base.
  String get base => symbol.replaceAll('ː', '');

  /// Czech distinguishes vowel length lexically (`byt` vs `být`), so this is a
  /// meaning-bearing property, not a detail.
  bool get isLong => symbol.contains('ː');

  @override
  String toString() => symbol;

  @override
  bool operator ==(Object other) => other is Ipa && other.symbol == symbol;

  @override
  int get hashCode => symbol.hashCode;
}

class IpaTokenizer {
  IpaTokenizer._();

  static const _stress = {'ˈ', 'ˌ'}; // ˈ primary, ˌ secondary
  static const _length = 'ː'; // ː
  static const _tieBar = '͡'; // ͡ (joins affricates)

  /// Combining diacritics belong to the symbol before them (Unicode Mn).
  static bool _isCombining(int c) =>
      (c >= 0x0300 && c <= 0x036F) || (c >= 0x1AB0 && c <= 0x1AFF);

  /// Split [ipa] into phonemes, dropping stress marks and word spaces.
  ///
  /// Stress is deliberately not scored: Czech stress is fixed on the first
  /// syllable, so it carries no contrastive information and a learner cannot
  /// get it "wrong" in a way worth flagging.
  static List<Ipa> tokenize(String ipa) {
    final runes = ipa.runes.toList();
    final out = <Ipa>[];
    var i = 0;

    while (i < runes.length) {
      final c = runes[i];
      final ch = String.fromCharCode(c);

      // Skip separators and stress marks.
      if (ch.trim().isEmpty || _stress.contains(ch)) {
        i++;
        continue;
      }
      // A combining mark with nothing to attach to is malformed input; drop it.
      if (_isCombining(c)) {
        i++;
        continue;
      }

      final buffer = StringBuffer(ch);
      i++;

      // Absorb diacritics, the length mark, and a tie-barred partner.
      while (i < runes.length) {
        final next = runes[i];
        final nextCh = String.fromCharCode(next);

        if (_isCombining(next) && nextCh != _tieBar) {
          buffer.write(nextCh);
          i++;
        } else if (nextCh == _length) {
          buffer.write(nextCh);
          i++;
        } else if (nextCh == _tieBar) {
          // Tie bar binds this symbol to the following one: t͡ʃ is one sound.
          buffer.write(nextCh);
          i++;
          if (i < runes.length) {
            buffer.write(String.fromCharCode(runes[i]));
            i++;
            while (i < runes.length && _isCombining(runes[i])) {
              buffer.write(String.fromCharCode(runes[i]));
              i++;
            }
          }
        } else {
          break;
        }
      }

      out.add(Ipa(buffer.toString()));
    }

    return _joinAffricates(out);
  }

  /// Czech `c` and `č` are single affricates, but a recogniser often writes
  /// them as two symbols (`ts`, `tʃ`) with no tie bar. Left split, `t͡ʃaj`
  /// spoken as `tsaj` aligns `t͡ʃ` against a bare `t` and blames the wrong
  /// sound. Joining here — on both the expected and the produced side, so the
  /// comparison stays symmetric — keeps one affricate against one affricate.
  static List<Ipa> _joinAffricates(List<Ipa> tokens) {
    const partners = {
      't': {'s', 'ʃ'},
      'd': {'z', 'ʒ'},
    };

    final out = <Ipa>[];
    for (var i = 0; i < tokens.length; i++) {
      final current = tokens[i];
      final next = i + 1 < tokens.length ? tokens[i + 1] : null;
      final follows = partners[current.symbol];
      if (next != null &&
          follows != null &&
          follows.contains(next.base) &&
          !next.isLong) {
        out.add(Ipa('${current.symbol}${next.symbol}'));
        i++;
      } else {
        out.add(current);
      }
    }
    return out;
  }
}
