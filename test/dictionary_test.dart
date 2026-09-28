import 'dart:convert';
import 'dart:io';

import 'package:czechify/data/dictionary/dictionary_entry.dart';
import 'package:czechify/data/dictionary/dictionary_search.dart';
import 'package:flutter_test/flutter_test.dart';

DictionaryData _load(String level) => DictionaryData.fromJson(
  jsonDecode(File('assets/dictionary/${level}_dictionary.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// Units of each level, as tool/dictionary/build_dictionary.py counts them.
const _levelUnits = {
  'a1': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 28, 30},
};

/// Lesson fields that hold Czech a learner reads or hears. Kept in step with
/// CZECH_FIELDS in tool/dictionary/build_dictionary.py.
const _czechFields = {
  'cz', 'blank_answers', 'answer_key', 'text', 'left', 'sentence', 'say',
  'transcript_cz', 'words', 'expected_phrases', 'question_cz', 'prompt_cz',
  'text_cz', 'target_text', 'sample_answer', 'expected_text', 'key_vocab',
  'name_say',
};

final _word = RegExp(r'[A-Za-zÁČĎÉĚÍŇÓŘŠŤÚŮÝŽáčďéěíňóřšťúůýž]+');

Iterable<String> _czechStrings(Object? node, [String? key]) sync* {
  if (node is Map) {
    for (final e in node.entries) {
      yield* _czechStrings(e.value, e.key as String);
    }
  } else if (node is List) {
    for (final x in node) {
      yield* _czechStrings(x, key);
    }
  } else if (node is String && _czechFields.contains(key)) {
    yield node;
  }
}

void main() {
  final a1 = _load('a1');
  final search = DictionarySearch(a1);
  String top(String query) => search.search(query).first.entry.cz;

  group('search', () {
    test('finds a word with or without its accents', () {
      expect(top('káva'), 'káva');
      expect(top('kava'), 'káva');
      expect(top('KÁVA'), 'káva');
      expect(top('reka'), 'řeka');
    });

    test('finds a word from any of its forms, and says which form', () {
      final hit = search.search('piju').first;
      expect(hit.entry.cz, 'pít');
      expect(hit.matchedForm, 'piju');
      expect(top('Praze'), 'Praha');
      expect(top('jsem'), 'být');
      expect(top('šla'), 'jít');
      expect(top('kavu'), 'káva');
      expect(top('větší'), 'velký');
      expect(top('nemám'), 'mít');
    });

    test('finds a word from its English meaning', () {
      expect(top('coffee'), 'káva');
      expect(top('to drink'), 'pít');
      expect(top('good day'), 'dobrý den');
      expect(top('Wednesday'), 'středa');
      expect(top('cafe'), 'kavárna');
    });

    test('lists related words after the ones that mean it', () {
      final hits = [for (final h in search.search('drink')) h.entry.cz];
      expect(hits.indexOf('pít'), isNot(-1));
      expect(hits, contains('káva'));
      expect(hits.indexOf('pít'), lessThan(hits.indexOf('káva')));
    });

    test('matches the start of a word while it is being typed', () {
      expect([for (final h in search.search('kav')) h.entry.cz], contains('káva'));
      expect([for (final h in search.search('coff')) h.entry.cz], contains('káva'));
    });

    test('finds nothing for nothing', () {
      expect(search.search('   '), isEmpty);
      expect(search.search('qqxzv'), isEmpty);
    });

    test('folds Czech accents the way a plain keyboard types them', () {
      expect(foldCzech('Příliš žluťoučký kůň'), 'prilis zlutoucky kun');
    });
  });

  group('A1 dictionary', () {
    test('every word has an id of its own, meanings, forms and an example', () {
      final ids = <String>{};
      for (final e in a1.entries) {
        expect(ids.add(e.id), isTrue, reason: 'duplicate id ${e.id}');
        expect(e.meanings, isNotEmpty, reason: e.cz);
        expect(e.forms, isNotEmpty, reason: e.cz);
        expect(e.examples, isNotEmpty, reason: e.cz);
      }
    });

    test('nouns and verbs show their key forms, with full tables behind', () {
      for (final e in a1.entries.where((e) => e.pos == 'noun' || e.pos == 'verb')) {
        expect(e.keyForms, isNotEmpty, reason: e.cz);
        expect(e.tables, isNotEmpty, reason: e.cz);
      }
    });

    test('a word marked plural-only has no singular column', () {
      for (final e in a1.entries.where((e) => e.pluralOnly)) {
        expect(e.tables.single.columns, ['plural'], reason: e.cz);
      }
    });

    test('"see also" only points at words the dictionary has', () {
      for (final e in a1.entries) {
        for (final cz in e.see) {
          expect(a1.byCzech(cz), isNotNull, reason: '${e.cz} → $cz');
        }
      }
    });

    test('every word is placed in a unit of the level, or in none', () {
      for (final e in a1.entries.where((e) => e.unit != null)) {
        expect(_levelUnits['a1'], contains(e.unit), reason: e.cz);
      }
    });

    // The guard the digest test is for content: a lesson or review card that
    // starts using a new word must bring it into the dictionary too, or list
    // it as not a word (a name, a letter, English) in not_words.txt.
    test('covers every Czech word the A1 lessons and review cards use', () {
      final forms = {for (final e in a1.entries) ...e.forms};
      final notWords = {
        for (final line
            in File('tool/dictionary/a1/not_words.txt').readAsLinesSync())
          ...line.split('#').first.split(RegExp(r'\s+')).where((w) => w.isNotEmpty),
      };
      final texts = <String>[];
      for (final file in Directory('assets/curriculum/lessons').listSync()) {
        if (!file.path.endsWith('.json')) continue;
        final lesson =
            jsonDecode(File(file.path).readAsStringSync())
                as Map<String, dynamic>;
        if (_levelUnits['a1']!.contains(lesson['unit_id'])) {
          texts.addAll(_czechStrings(lesson['exercises']));
        }
      }
      final vocabulary =
          jsonDecode(
                File('assets/vocabulary/a1_vocabulary.json').readAsStringSync(),
              )
              as List<dynamic>;
      for (final v in vocabulary.cast<Map<String, dynamic>>()) {
        texts.add(v['word_cz'] as String? ?? '');
        texts.add(v['example_cz'] as String? ?? '');
      }
      final missing = <String>{
        for (final text in texts)
          for (final m in _word.allMatches(text))
            if (!forms.contains(m[0]!.toLowerCase()) &&
                !notWords.contains(m[0]!.toLowerCase()))
              m[0]!.toLowerCase(),
      };
      expect(
        missing,
        isEmpty,
        reason:
            'Add these to tool/dictionary/a1/ (or to not_words.txt) and run '
            'python3 tool/dictionary/build_dictionary.py a1',
      );
    });
  });
}
