import 'dictionary_search.dart' show foldCzech;

/// One word of the in-app dictionary, as built by
/// `tool/dictionary/build_dictionary.py` into `assets/dictionary/`.
///
/// The file is generated; the words, forms and notes are written in
/// `tool/dictionary/<level>/*.txt`, and examples and units are taken from the
/// course itself at build time.
class DictionaryEntry {
  const DictionaryEntry({
    required this.id,
    required this.cz,
    required this.pos,
    required this.posLabel,
    required this.meanings,
    required this.forms,
    this.gender,
    this.genderLabel,
    this.pluralOnly = false,
    this.aspect,
    this.related = const [],
    this.note,
    this.caseGoverned,
    this.keyForms = const [],
    this.tables = const [],
    this.examples = const [],
    this.see = const [],
    this.unit,
    this.unitNo,
    this.level = 'A1',
  });

  final String id;

  /// The word as the dictionary lists it: káva, pít, učit se, dobrý den.
  final String cz;

  /// noun, verb, adj, pron, num, adv, prep, conj, part, interj, phrase.
  final String pos;

  /// What to show a learner for [pos]: "noun", "adjective"…
  final String posLabel;
  final List<String> meanings;

  /// Related English words, for search only.
  final List<String> related;

  /// Every form of the word, lower case: what search matches Czech against.
  final List<String> forms;
  final String? gender;
  final String? genderLabel;
  final bool pluralOnly;
  final String? aspect;
  final String? note;

  /// What a preposition is followed by: "+ 2 (do školy)".
  final String? caseGoverned;
  final List<DictionaryKeyForm> keyForms;
  final List<DictionaryTable> tables;
  final List<DictionaryExample> examples;

  /// Other dictionary words worth a look, by their [cz].
  final List<String> see;

  /// The unit where a learner first meets the word, if the course uses it:
  /// the course's unit id, which unlocking uses.
  final int? unit;

  /// That unit as the learner sees it numbered, within its level (A2's
  /// Unit 1 is course unit 16).
  final int? unitNo;

  /// The level the word belongs to: "A1", "A2".
  final String level;

  bool get hasTables => tables.isNotEmpty;

  factory DictionaryEntry.fromJson(
    Map<String, dynamic> json, {
    String level = 'A1',
  }) {
    List<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? const []).cast<String>();
    return DictionaryEntry(
      id: json['id'] as String,
      cz: json['cz'] as String,
      pos: json['pos'] as String,
      posLabel: json['pos_label'] as String,
      meanings: strings('meanings'),
      forms: strings('forms'),
      gender: json['gender'] as String?,
      genderLabel: json['gender_label'] as String?,
      pluralOnly: json['plural_only'] as bool? ?? false,
      aspect: json['aspect'] as String?,
      related: strings('related'),
      note: json['note'] as String?,
      caseGoverned: json['case'] as String?,
      keyForms: [
        for (final k in json['key_forms'] as List<dynamic>? ?? const [])
          DictionaryKeyForm(
            label: (k as Map<String, dynamic>)['label'] as String,
            cz: k['cz'] as String,
          ),
      ],
      tables: [
        for (final t in json['tables'] as List<dynamic>? ?? const [])
          DictionaryTable.fromJson(t as Map<String, dynamic>),
      ],
      examples: [
        for (final e in json['examples'] as List<dynamic>? ?? const [])
          DictionaryExample(
            cz: (e as Map<String, dynamic>)['cz'] as String,
            en: e['en'] as String,
          ),
      ],
      see: strings('see'),
      unit: json['unit'] as int?,
      unitNo: json['unit_no'] as int? ?? json['unit'] as int?,
      level: level,
    );
  }
}

/// A form shown at the top of a word's page: "plural → kávy".
class DictionaryKeyForm {
  const DictionaryKeyForm({required this.label, required this.cz});

  final String label;
  final String cz;
}

class DictionaryExample {
  const DictionaryExample({required this.cz, required this.en});

  final String cz;
  final String en;
}

/// A table of forms: the cases of a noun, a verb's present tense…
class DictionaryTable {
  const DictionaryTable({
    required this.title,
    required this.columns,
    required this.rows,
  });

  final String title;

  /// Column headings; a single empty heading means the table has one
  /// column and no heading row.
  final List<String> columns;
  final List<DictionaryRow> rows;

  bool get hasHeadings => columns.any((c) => c.trim().isNotEmpty);

  factory DictionaryTable.fromJson(Map<String, dynamic> json) {
    return DictionaryTable(
      title: json['title'] as String,
      columns: (json['columns'] as List<dynamic>).cast<String>(),
      rows: [
        for (final r in json['rows'] as List<dynamic>)
          DictionaryRow(
            label: (r as Map<String, dynamic>)['label'] as String,
            cells: (r['cells'] as List<dynamic>).cast<String>(),
          ),
      ],
    );
  }
}

class DictionaryRow {
  const DictionaryRow({required this.label, required this.cells});

  final String label;
  final List<String> cells;
}

/// A learner's dictionary: one level's words, as loaded from its asset, or
/// an A2 learner's A1 and A2 words together ([DictionaryData.merged]).
class DictionaryData {
  const DictionaryData({
    required this.level,
    required this.entries,
    this.levels = const [],
  });

  /// The learner's level: "A1", "A2".
  final String level;

  /// Every level whose words are here, in course order: ["A1", "A2"] for an
  /// A2 learner. Empty means just [level].
  final List<String> levels;

  /// "A1", or "A1 + A2".
  String get label => (levels.isEmpty ? [level] : levels).join(' + ');

  /// A word of an earlier level than the learner's: the app keeps a learner
  /// on one level, so it cannot send them to that word's unit.
  bool isEarlier(DictionaryEntry entry) => entry.level != level;

  /// [lower]'s words and [upper]'s in one A–Z list, as [upper]'s learner
  /// sees them.
  factory DictionaryData.merged(DictionaryData lower, DictionaryData upper) {
    final entries = [...lower.entries, ...upper.entries]..sort(
      (a, b) {
        final byFolded = foldCzech(a.cz).compareTo(foldCzech(b.cz));
        return byFolded != 0 ? byFolded : a.cz.compareTo(b.cz);
      },
    );
    return DictionaryData(
      level: upper.level,
      entries: entries,
      levels: [lower.label, upper.level],
    );
  }

  /// Sorted as a dictionary is: by the word without accents, then with.
  final List<DictionaryEntry> entries;

  DictionaryEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  DictionaryEntry? byCzech(String cz) {
    for (final e in entries) {
      if (e.cz == cz) return e;
    }
    return null;
  }

  factory DictionaryData.fromJson(Map<String, dynamic> json) {
    final level = json['level'] as String;
    return DictionaryData(
      level: level,
      entries: [
        for (final e in json['entries'] as List<dynamic>)
          DictionaryEntry.fromJson(e as Map<String, dynamic>, level: level),
      ],
    );
  }
}
