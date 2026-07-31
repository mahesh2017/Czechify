/// Text normalization utilities for pronunciation comparison.
class TextNormalizer {
  TextNormalizer._();

  /// Normalize text: lowercase, strip punctuation, collapse spaces.
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sáčďéěíňóřšťúůýž-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Clean text before it is spoken or synthesized so text-to-speech doesn't
  /// read editorial marks aloud. Fill-in-the-blank markers ("___") were being
  /// read as "podtržítko" (Czech for "underscore"), and parenthetical hints
  /// like "(muž)" aren't part of the sentence. Removes both and collapses
  /// whitespace. Kept identical to `speech_text` in the audio-pack tools so a
  /// pre-generated clip and a runtime request resolve to the same hash.
  static String forSpeech(String text) {
    final collapsed = text
        .replaceAll(RegExp(r'\([^)]*\)'), ' ') // editorial hints, e.g. "(muž)"
        .replaceAll(RegExp(r'_+'), ' ') // fill-in-the-blank markers
        .replaceAll(RegExp(r'\s+'), ' ');
    // replaceAllMapped (not replaceAll) — Dart only expands group references
    // through a callback.
    return collapsed
        .replaceAllMapped(
          RegExp(r'\s+([.,!?;:])'),
          (m) => m.group(1)!,
        ) // no space before punctuation
        .trim();
  }

  /// Strip Czech diacritics for loose comparison.
  static String stripDiacritics(String text) {
    const diacriticsMap = {
      'á': 'a',
      'č': 'c',
      'ď': 'd',
      'é': 'e',
      'ě': 'e',
      'í': 'i',
      'ň': 'n',
      'ó': 'o',
      'ř': 'r',
      'š': 's',
      'ť': 't',
      'ú': 'u',
      'ů': 'u',
      'ý': 'y',
      'ž': 'z',
    };
    var result = text.toLowerCase();
    diacriticsMap.forEach((cz, plain) {
      result = result.replaceAll(cz, plain);
    });
    return result;
  }

  /// The Czech letters with diacritics, for the on-screen character bar.
  static const czechDiacriticChars = [
    'á',
    'č',
    'ď',
    'é',
    'ě',
    'í',
    'ň',
    'ó',
    'ř',
    'š',
    'ť',
    'ú',
    'ů',
    'ý',
    'ž',
  ];

  /// True when [a] and [b] are equal once normalized AND stripped of
  /// diacritics — i.e. the only difference is accent marks. Used to give a
  /// gentle "check your accents" near-miss instead of a hard wrong.
  static bool matchesIgnoringDiacritics(String a, String b) =>
      stripDiacritics(normalize(a)) == stripDiacritics(normalize(b));
}
