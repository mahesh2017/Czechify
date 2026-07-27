/// Czech phoneme mapping for pronunciation scoring.
///
/// Maps Czech orthography to approximate IPA and identifies
/// problem sounds that are unique or difficult in Czech.
class PhonemeMapper {
  /// Czech orthography → approximate IPA.
  static const Map<String, String> czechToIpa = {
    'a': 'a',
    'e': 'ɛ',
    'i': 'i',
    'o': 'o',
    'u': 'u',
    'á': 'aː',
    'é': 'ɛː',
    'í': 'iː',
    'ó': 'oː',
    'ú': 'uː',
    'ů': 'uː',
    'ř': 'r̝',
    'ě': 'jɛ',
    'č': 'tʃ',
    'š': 'ʃ',
    'ž': 'ʒ',
    'ď': 'ɟ',
    'ť': 'c',
    'ň': 'ɲ',
    'ch': 'x',
    'h': 'ɦ',
    'g': 'g',
    'c': 'ts',
    'j': 'j',
    'n': 'n',
    'm': 'm',
    'p': 'p',
    'b': 'b',
    't': 't',
    'd': 'd',
    'k': 'k',
    'f': 'f',
    'v': 'v',
    's': 's',
    'z': 'z',
    'l': 'l',
    'r': 'r',
    'w': 'v',
    'q': 'kv',
    'x': 'ks',
    'y': 'i',
  };

  /// Czech-specific problem sounds that need extra scoring weight.
  static const Map<String, double> problemSounds = {
    'ř': 3.0, // highest weight — signature Czech sound
    'ě': 2.5, // softening effect
    'long_vowel': 2.5, // meaning-changing (á/a, é/e, etc.)
    'palatalized': 2.0, // ď, ť, ň
    'other': 1.0,
  };

  /// Long vowels that change meaning.
  static const Set<String> longVowels = {'á', 'é', 'í', 'ó', 'ú', 'ů'};

  /// Palatalized consonants.
  static const Set<String> palatalized = {'ď', 'ť', 'ň', 'č', 'š', 'ž'};

  /// Get problem phonemes in a word.
  List<String> getProblemPhonemes(String word) {
    final problems = <String>[];
    final lower = word.toLowerCase();

    if (lower.contains('ř')) problems.add('ř');
    if (lower.contains('ě')) problems.add('ě');

    // Check for long vowels
    for (final lv in longVowels) {
      if (lower.contains(lv)) {
        problems.add('long_vowel');
        break;
      }
    }

    // Check for palatalized consonants
    for (final p in palatalized) {
      if (lower.contains(p)) {
        problems.add('palatalized');
        break;
      }
    }

    return problems.isEmpty ? ['other'] : problems;
  }

  /// Convert Czech text to approximate IPA.
  String toIpa(String text) {
    var result = text.toLowerCase();
    // Handle digraphs first
    result = result.replaceAll('ch', 'x');
    // Then handle individual characters
    czechToIpa.forEach((cz, ipa) {
      if (cz.length == 1) {
        result = result.replaceAll(cz, ipa);
      }
    });
    return result;
  }

  /// Get the weight for a phoneme in scoring.
  double getWeight(String phoneme) {
    return problemSounds[phoneme] ?? 1.0;
  }
}
