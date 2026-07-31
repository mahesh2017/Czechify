import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Which phrases the acoustic model was *measured* to handle reliably.
///
/// The recogniser is not uniformly good. Measured over 1112 vocabulary items
/// (tool/scan_pronunciation_reliability.py), 73% are safe on two counts: the
/// model transcribes the native reference correctly, and it agrees with itself
/// across two different correct voices. The rest would produce verdicts a
/// learner cannot trust.
///
/// Single letters are the clearest failure — twelve one-character items
/// averaged 117% error, worse than chance ("a" heard as "e", "č" as "tři"),
/// which is why the Unit 1 alphabet card must never be phoneme-scored.
///
/// Telling a learner their correct pronunciation is wrong is worse than not
/// scoring it at all, so anything unmeasured is treated as unsupported.
class PronunciationCoverage {
  PronunciationCoverage._(this._words);

  static const _assetPath =
      'assets/curriculum/pronunciation_reliable_words.json';

  /// Below this length the model is unusable regardless of the list, so short
  /// items are rejected even if something slips into the asset.
  static const _minLength = 4;

  final Set<String> _words;

  static PronunciationCoverage? _instance;

  static Future<PronunciationCoverage> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final words =
          (decoded['words'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .map(_key)
              .toSet();
      return _instance = PronunciationCoverage._(words);
    } catch (_) {
      // Missing or malformed asset means "support nothing", never "support
      // everything" — the safe direction is to fall back to transcript scoring.
      return _instance = PronunciationCoverage._(const {});
    }
  }

  static String _key(String phrase) => phrase.trim().toLowerCase();

  /// Whether [phrase] can be phoneme-scored with a verdict worth showing.
  bool supports(String phrase) {
    final key = _key(phrase);
    if (key.length < _minLength) return false;
    return _words.contains(key);
  }

  int get supportedCount => _words.length;

  /// Test seam — avoids needing the asset bundle in unit tests.
  static PronunciationCoverage forTest(Iterable<String> words) =>
      PronunciationCoverage._(words.map(_key).toSet());
}
