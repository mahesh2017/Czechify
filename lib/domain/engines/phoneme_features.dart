/// Articulatory descriptions of the Czech phoneme inventory.
///
/// Pronunciation scoring needs a notion of *how wrong* a sound was. String
/// equality can't tell that saying `r` for `ř` is a near miss made by every
/// learner, while saying `k` for `ř` is not remotely the same sound. Comparing
/// articulatory features gives a graded distance instead of a boolean.
///
/// Note the separation of concerns: similarity says how acoustically close two
/// sounds are, while [PhonemeMapper]'s weights say how much a given sound
/// *matters* pedagogically. `ř` is both close to `r` and heavily weighted —
/// a small acoustic slip that is still worth telling the learner about.
library;

enum Manner {
  stop,
  affricate,
  fricative,
  nasal,
  trill,
  lateral,
  approximant,
  vowel,
}

enum Place {
  bilabial,
  labiodental,
  alveolar,
  postalveolar,
  palatal,
  velar,
  glottal,
  none,
}

/// Vowel tongue height / backness. Consonants use [none].
enum Height { high, mid, low, none }

enum Backness { front, central, back, none }

class PhonemeFeatures {
  final Manner manner;
  final Place place;
  final bool voiced;
  final Height height;
  final Backness backness;
  final bool long;

  const PhonemeFeatures({
    required this.manner,
    this.place = Place.none,
    this.voiced = true,
    this.height = Height.none,
    this.backness = Backness.none,
    this.long = false,
  });

  bool get isVowel => manner == Manner.vowel;
}

class CzechPhonemes {
  CzechPhonemes._();

  static const _c = Manner.stop;

  /// Base inventory, keyed by the symbol without its length mark.
  static const Map<String, PhonemeFeatures> base = {
    // Stops
    'p': PhonemeFeatures(manner: _c, place: Place.bilabial, voiced: false),
    'b': PhonemeFeatures(manner: _c, place: Place.bilabial),
    't': PhonemeFeatures(manner: _c, place: Place.alveolar, voiced: false),
    'd': PhonemeFeatures(manner: _c, place: Place.alveolar),
    'c': PhonemeFeatures(manner: _c, place: Place.palatal, voiced: false),
    'ɟ': PhonemeFeatures(manner: _c, place: Place.palatal),
    'k': PhonemeFeatures(manner: _c, place: Place.velar, voiced: false),
    'g': PhonemeFeatures(manner: _c, place: Place.velar),
    // Fricatives
    'f': PhonemeFeatures(
      manner: Manner.fricative,
      place: Place.labiodental,
      voiced: false,
    ),
    'v': PhonemeFeatures(manner: Manner.fricative, place: Place.labiodental),
    's': PhonemeFeatures(
      manner: Manner.fricative,
      place: Place.alveolar,
      voiced: false,
    ),
    'z': PhonemeFeatures(manner: Manner.fricative, place: Place.alveolar),
    'ʃ': PhonemeFeatures(
      manner: Manner.fricative,
      place: Place.postalveolar,
      voiced: false,
    ),
    'ʒ': PhonemeFeatures(manner: Manner.fricative, place: Place.postalveolar),
    'x': PhonemeFeatures(
      manner: Manner.fricative,
      place: Place.velar,
      voiced: false,
    ),
    'ɦ': PhonemeFeatures(manner: Manner.fricative, place: Place.glottal),
    'h': PhonemeFeatures(manner: Manner.fricative, place: Place.glottal),
    // Affricates
    'ts': PhonemeFeatures(
      manner: Manner.affricate,
      place: Place.alveolar,
      voiced: false,
    ),
    't͡s': PhonemeFeatures(
      manner: Manner.affricate,
      place: Place.alveolar,
      voiced: false,
    ),
    'tʃ': PhonemeFeatures(
      manner: Manner.affricate,
      place: Place.postalveolar,
      voiced: false,
    ),
    't͡ʃ': PhonemeFeatures(
      manner: Manner.affricate,
      place: Place.postalveolar,
      voiced: false,
    ),
    'd͡z': PhonemeFeatures(manner: Manner.affricate, place: Place.alveolar),
    'd͡ʒ': PhonemeFeatures(manner: Manner.affricate, place: Place.postalveolar),
    // Nasals
    'm': PhonemeFeatures(manner: Manner.nasal, place: Place.bilabial),
    'n': PhonemeFeatures(manner: Manner.nasal, place: Place.alveolar),
    'ɲ': PhonemeFeatures(manner: Manner.nasal, place: Place.palatal),
    'ŋ': PhonemeFeatures(manner: Manner.nasal, place: Place.velar),
    // Liquids and glides
    'r': PhonemeFeatures(manner: Manner.trill, place: Place.alveolar),
    // ř — a raised (fricative) trill. Shares place and voicing with r, differs
    // in manner, which is exactly why learners substitute r for it.
    'r̝': PhonemeFeatures(manner: Manner.fricative, place: Place.alveolar),
    'l': PhonemeFeatures(manner: Manner.lateral, place: Place.alveolar),
    'j': PhonemeFeatures(manner: Manner.approximant, place: Place.palatal),
    // Vowels
    'a': PhonemeFeatures(
      manner: Manner.vowel,
      height: Height.low,
      backness: Backness.central,
    ),
    'ɛ': PhonemeFeatures(
      manner: Manner.vowel,
      height: Height.mid,
      backness: Backness.front,
    ),
    'e': PhonemeFeatures(
      manner: Manner.vowel,
      height: Height.mid,
      backness: Backness.front,
    ),
    'i': PhonemeFeatures(
      manner: Manner.vowel,
      height: Height.high,
      backness: Backness.front,
    ),
    'ɪ': PhonemeFeatures(
      manner: Manner.vowel,
      height: Height.high,
      backness: Backness.front,
    ),
    'o': PhonemeFeatures(
      manner: Manner.vowel,
      height: Height.mid,
      backness: Backness.back,
    ),
    'u': PhonemeFeatures(
      manner: Manner.vowel,
      height: Height.high,
      backness: Backness.back,
    ),
  };

  /// Features for a full symbol, honouring the length mark.
  static PhonemeFeatures? lookup(String symbol) {
    final long = symbol.contains('ː');
    final stripped = symbol.replaceAll('ː', '');
    final f = base[stripped];
    if (f == null) return null;
    return PhonemeFeatures(
      manner: f.manner,
      place: f.place,
      voiced: f.voiced,
      height: f.height,
      backness: f.backness,
      long: long,
    );
  }

  /// How close two sounds are, 0.0–1.0.
  ///
  /// Unknown symbols fall back to string equality rather than guessing — the
  /// recogniser may emit sounds outside the Czech inventory, and inventing a
  /// similarity for them would be worse than admitting ignorance.
  static double similarity(String a, String b) {
    if (a == b) return 1.0;

    final fa = lookup(a);
    final fb = lookup(b);
    if (fa == null || fb == null) return 0.0;

    // A vowel and a consonant are never a near miss.
    if (fa.isVowel != fb.isVowel) return 0.0;

    var matched = 0;
    var total = 0;

    void compare(bool same) {
      total++;
      if (same) matched++;
    }

    if (fa.isVowel) {
      compare(fa.height == fb.height);
      compare(fa.backness == fb.backness);
      compare(fa.long == fb.long);
    } else {
      compare(fa.manner == fb.manner);
      compare(fa.place == fb.place);
      compare(fa.voiced == fb.voiced);
    }

    return matched / total;
  }
}
