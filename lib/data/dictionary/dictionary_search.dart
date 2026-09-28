import 'dictionary_entry.dart';

/// Lower case without Czech accents: what a learner types on a keyboard
/// without them. "Káva" and "kava" fold to the same "kava".
String foldCzech(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    out.write(_plain[char] ?? char);
  }
  return out.toString();
}

const _plain = {
  'á': 'a', 'č': 'c', 'ď': 'd', 'é': 'e', 'ě': 'e', 'í': 'i', 'ň': 'n',
  'ó': 'o', 'ř': 'r', 'š': 's', 'ť': 't', 'ú': 'u', 'ů': 'u', 'ý': 'y',
  'ž': 'z', 'ä': 'a', 'ö': 'o', 'ü': 'u',
};

final _nonWord = RegExp(r"[^a-z0-9'\- ]+");

/// Why a word matched a search: shown under a result when the match is not
/// obvious from the word itself ("pije" for pít).
class DictionaryHit {
  const DictionaryHit(this.entry, this.score, {this.matchedForm});

  final DictionaryEntry entry;
  final int score;

  /// The form of the word the query matched, when it is not the word
  /// itself: searching "piju" finds pít through "piju".
  final String? matchedForm;
}

/// Precomputed search keys for one entry, so a keystroke does not re-fold
/// every form of every word.
class _Keys {
  _Keys(DictionaryEntry e)
    : entry = e,
      cz = e.cz.toLowerCase(),
      czFold = foldCzech(e.cz),
      forms = e.forms,
      formsFold = [for (final f in e.forms) foldCzech(f)],
      meanings = [for (final m in e.meanings) _english(m)],
      related = [for (final r in e.related) _english(r)];

  final DictionaryEntry entry;
  final String cz;
  final String czFold;
  final List<String> forms;
  final List<String> formsFold;
  final List<String> meanings;
  final List<String> related;

  /// "to go (on foot)" → "to go": the bracketed hint is for reading, not
  /// for matching.
  static String _english(String text) => foldCzech(text)
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(_nonWord, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Searches one level's dictionary by Czech (any form, with or without
/// accents) and by English meaning or related English words.
class DictionarySearch {
  DictionarySearch(DictionaryData data)
    : _keys = [for (final e in data.entries) _Keys(e)];

  final List<_Keys> _keys;

  List<DictionaryHit> search(String query, {int limit = 60}) {
    final raw = query.trim().toLowerCase();
    if (raw.isEmpty) return const [];
    final folded = foldCzech(raw);
    final english = _Keys._english(raw);
    final hits = <DictionaryHit>[];
    for (final k in _keys) {
      final hit = _score(k, raw, folded, english);
      if (hit != null) hits.add(hit);
    }
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      // Among equals, the word met earlier in the course first.
      final ua = a.entry.unit ?? 999, ub = b.entry.unit ?? 999;
      if (ua != ub) return ua.compareTo(ub);
      return a.entry.cz.length.compareTo(b.entry.cz.length);
    });
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  DictionaryHit? _score(_Keys k, String raw, String folded, String english) {
    var best = 0;
    String? form;

    void take(int score, [String? matched]) {
      if (score > best) {
        best = score;
        form = matched;
      }
    }

    // The word itself.
    if (k.cz == raw) take(1000);
    if (k.czFold == folded) take(960);
    if (folded.length >= 2 && k.czFold.startsWith(folded)) {
      take(700 - (k.czFold.length - folded.length).clamp(0, 99));
    }

    // Any of its forms: "piju" finds pít, "kavu" finds káva.
    for (var i = 0; i < k.forms.length; i++) {
      if (k.forms[i] == raw) {
        take(920, k.forms[i]);
      } else if (k.formsFold[i] == folded) {
        take(880, k.forms[i]);
      } else if (folded.length >= 3 && k.formsFold[i].startsWith(folded)) {
        take(480, k.forms[i]);
      }
    }

    // English: a whole meaning, a word in a meaning, the start of a word.
    if (english.isNotEmpty) {
      for (final m in k.meanings) {
        final bare = m.startsWith('to ') ? m.substring(3) : m;
        if (m == english || bare == english) {
          take(850);
        } else if (english.length >= 3 && _hasPhrase(m, english)) {
          take(620);
        } else if (english.length >= 3 && _hasPrefix(m, english)) {
          take(430);
        }
      }
      for (final r in k.related) {
        if (r == english) {
          take(360);
        } else if (english.length >= 3 && _hasPhrase(r, english)) {
          take(300);
        } else if (english.length >= 4 && _hasPrefix(r, english)) {
          take(200);
        }
      }
    }

    if (folded.length >= 3 && k.czFold.contains(folded)) take(150);

    if (best == 0) return null;
    return DictionaryHit(
      k.entry,
      best,
      matchedForm: form == null || form == k.cz ? null : form,
    );
  }

  /// [text] contains [phrase] as whole words: "good day" in "hello good day".
  static bool _hasPhrase(String text, String phrase) =>
      ' $text '.contains(' $phrase ');

  /// Some word of [text] starts with [prefix]: "coff" in "coffee".
  static bool _hasPrefix(String text, String prefix) =>
      ' $text'.contains(' $prefix');
}
