import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Content rules for the v1.2 lessons (docs/CURRICULUM_V1_2_PLAN_2026-09-24.md
/// §6): teach before testing, a notebook step in every lesson, and nothing
/// outside the official A1/A2 scope.
///
/// Most rules apply to lessons rebuilt for v1.2, marked `"format": 2`. A unit
/// is rebuilt whole, so a half-converted unit fails here rather than shipping
/// with two teaching styles. The scope guard applies to every lesson and
/// word, with [pendingScopeUnits] as the backlog of units not yet rebuilt.
void main() {
  final lessons = [
    for (final file in Directory('assets/curriculum/lessons').listSync())
      if (file is File && file.path.endsWith('.json'))
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
  ];
  final rules = {
    for (final rule
        in (_json('assets/curriculum/grammar_rules.json')['rules'] as List))
      rule['id'] as String: rule as Map<String, dynamic>,
  };
  final units = {
    for (final path in [
      'assets/curriculum/a1_units.json',
      'assets/curriculum/a2_units.json',
    ])
      for (final unit in (_json(path)['units'] as List))
        unit['id'] as int: unit as Map<String, dynamic>,
  };
  final vocabulary = [
    for (final path in [
      'assets/vocabulary/a1_vocabulary.json',
      'assets/vocabulary/a2_vocabulary.json',
    ])
      ...switch (jsonDecode(File(path).readAsStringSync())) {
        final List<dynamic> list => list,
        final Map<String, dynamic> map => map.values.first as List,
        _ => const [],
      }.cast<Map<String, dynamic>>(),
  ];
  final scope = _json('tool/curriculum_scope/level_scope.json');

  List<Map<String, dynamic>> lessonsOf(int unitId) =>
      lessons.where((l) => l['unit_id'] == unitId).toList()..sort(
        (a, b) =>
            (a['order_in_unit'] as int).compareTo(b['order_in_unit'] as int),
      );
  bool rebuilt(Map<String, dynamic> lesson) => lesson['format'] == 2;
  List<Map<String, dynamic>> exercisesOf(Map<String, dynamic> lesson) =>
      (lesson['exercises'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic> dataOf(Map<String, dynamic> exercise) =>
      exercise['data'] as Map<String, dynamic>;
  bool isLecture(Map<String, dynamic> e) =>
      e['type'] == 'teaching' && dataOf(e)['style'] == 'lecture';
  bool isNotebook(Map<String, dynamic> e) =>
      e['type'] == 'teaching' && dataOf(e)['style'] == 'notebook';
  bool isScored(Map<String, dynamic> e) =>
      e['type'] != 'teaching' && dataOf(e)['mode'] == null;

  final rebuiltUnits = {
    for (final lesson in lessons)
      if (rebuilt(lesson)) lesson['unit_id'] as int,
  };
  // Standard units follow the four-lesson pattern; 28–31 are skills and
  // review units with their own shape (plan §3.5).
  bool standard(int unitId) => unitId <= 27;

  test('a lesson plays in the order it is written', () {
    // The app orders a lesson's exercises by id (curriculum_dao.dart), so an
    // id out of sequence silently moves that item. Twelve A2 lessons played
    // their introduction card last this way, after every question.
    for (final lesson in lessons) {
      final ids = [for (final e in exercisesOf(lesson)) e['id'] as int];
      expect(
        ids,
        [...ids]..sort(),
        reason: 'lesson ${lesson['id']}: exercise ids must ascend in file order',
      );
    }
  });

  test('V1 a rebuilt unit is rebuilt whole', () {
    for (final unitId in rebuiltUnits) {
      final all = lessonsOf(unitId);
      expect(all.every(rebuilt), isTrue, reason: 'unit $unitId is half-converted');
      if (standard(unitId)) {
        expect(
          all.map((l) => l['order_in_unit']),
          [0, 1, 2, 3],
          reason: 'unit $unitId needs lessons A–D',
        );
      }
    }
  });

  test('rebuilt lessons state what the learner will be able to do', () {
    for (final lesson in lessons.where(rebuilt)) {
      for (final field in ['can_do', 'new_language', 'recycles', 'exit_task']) {
        final value = lesson[field];
        expect(
          value is String ? value.trim().isNotEmpty : (value as List?)?.isNotEmpty,
          isTrue,
          reason: 'lesson ${lesson['id']} has no $field',
        );
      }
    }
  });

  test('a mode is spelled right, and guided items carry their hint', () {
    // An unrecognised mode counts as scored, so a typo would quietly put a
    // heart on a question meant to be practice.
    for (final lesson in lessons) {
      for (final exercise in exercisesOf(lesson)) {
        final mode = dataOf(exercise)['mode'];
        if (mode == null) continue;
        expect(
          ['predict', 'check', 'guided'],
          contains(mode),
          reason: 'exercise ${exercise['id']}',
        );
        if (mode == 'guided') {
          expect(
            (dataOf(exercise)['hint'] as String? ?? '').trim(),
            isNotEmpty,
            reason: 'guided exercise ${exercise['id']} has no hint',
          );
        }
      }
    }
  });

  test('V2 lesson B teaches in 2–3 lecture steps, each checked at once', () {
    for (final unitId in rebuiltUnits.where(standard)) {
      final b = lessonsOf(unitId)[1];
      final items = exercisesOf(b);
      final lectureAt = [
        for (var i = 0; i < items.length; i++)
          if (isLecture(items[i])) i,
      ];
      expect(
        lectureAt.length,
        inInclusiveRange(2, 3),
        reason: 'unit $unitId lesson B has ${lectureAt.length} lecture steps',
      );
      for (final i in lectureAt) {
        expect(
          i + 1 < items.length && dataOf(items[i + 1])['mode'] == 'check',
          isTrue,
          reason: 'unit $unitId: lecture ${items[i]['id']} is not followed '
              'by a check',
        );
      }
    }
  });

  test('V3 every scored item is taught before it is tested', () {
    final unitOrder = [...units.keys]..sort(
      (a, b) => (units[a]!['order_index'] as int).compareTo(
        units[b]!['order_index'] as int,
      ),
    );
    final lectured = <String>{};
    for (final unitId in unitOrder) {
      for (final lesson in lessonsOf(unitId)) {
        final role = lesson['order_in_unit'] as int;
        for (final exercise in exercisesOf(lesson)) {
          final data = dataOf(exercise);
          if (isLecture(exercise)) {
            lectured.add(data['grammar_rule_id'] as String);
            continue;
          }
          if (!rebuilt(lesson) || role == 0 || !isScored(exercise)) continue;
          final ruleId = exercise['grammar_rule_id'] as String?;
          expect(
            ruleId != null || data['targets'] == 'vocab',
            isTrue,
            reason: 'exercise ${exercise['id']} says neither which rule nor '
                'that it tests vocabulary',
          );
          if (ruleId == null) continue;
          // A rule from a unit not yet rebuilt has no lecture card to point
          // at; it was taught the old way and is held to the old standard.
          final ruleUnit = rules[ruleId]?['unit_id'] as int?;
          if (ruleUnit != null && !rebuiltUnits.contains(ruleUnit)) continue;
          expect(
            lectured,
            contains(ruleId),
            reason: 'exercise ${exercise['id']} tests $ruleId before any '
                'lecture teaches it',
          );
        }
      }
    }
  });

  test('V5 each lesson has the notebook steps its role needs', () {
    const expected = {
      0: ['capture'],
      1: ['recall', 'capture'],
      2: ['recall', 'my_sentences'],
      3: ['unit_check'],
    };
    for (final unitId in rebuiltUnits.where(standard)) {
      for (final lesson in lessonsOf(unitId)) {
        final steps = [
          for (final e in exercisesOf(lesson))
            if (isNotebook(e) && dataOf(e)['kind'] != 'setup') e,
        ];
        expect(
          steps.map((e) => dataOf(e)['kind']),
          expected[lesson['order_in_unit']],
          reason: 'lesson ${lesson['id']}',
        );
        for (final step in steps) {
          final data = dataOf(step);
          expect(
            (data['instruction'] as String? ?? '').trim(),
            isNotEmpty,
            reason: 'notebook step ${step['id']} has no instruction',
          );
          expect(
            (data['items'] as List? ?? const []),
            isNotEmpty,
            reason: 'notebook step ${step['id']} has no model to check against',
          );
        }
      }
    }
  });

  test('V6 nothing outside the A1/A2 scope', () {
    final forbidden =
        (scope['forbidden_on_main_path']['A1_and_A2'] as List)
            .cast<Map<String, dynamic>>()
            .where((f) => f['pattern'] != null)
            .toList();
    final findings = <String>[];
    String withoutAllowed(Map<String, dynamic> rule, String text) {
      var out = text;
      for (final phrase in (rule['allow'] as List? ?? const [])) {
        out = out.replaceAll(RegExp(RegExp.escape('$phrase'), caseSensitive: false), '');
      }
      return out;
    }

    for (final rule in forbidden) {
      final pattern = _pattern(rule['pattern'] as String);
      final vocabularyOnly = rule['field'] == 'vocabulary.word_cz';
      if (!vocabularyOnly) {
        for (final lesson in lessons) {
          if (pendingScopeUnits.contains(lesson['unit_id'])) continue;
          final text = withoutAllowed(rule, _strings(lesson).join('\n'));
          if (pattern.hasMatch(text)) {
            findings.add('${rule['key']}: lesson ${lesson['id']}');
          }
        }
      }
      for (final entry in vocabulary) {
        if (pendingScopeUnits.contains(entry['unit_id'])) continue;
        final text =
            vocabularyOnly
                ? '${entry['word_cz']}'
                : withoutAllowed(
                  rule,
                  '${entry['word_cz']}\n${entry['example_cz'] ?? ''}',
                );
        if (pattern.hasMatch(text)) {
          findings.add('${rule['key']}: vocabulary ${entry['id']}');
        }
      }
    }
    expect(findings, isEmpty);
  });

  test('the scope backlog only lists units that still need it', () {
    // Emptying the list is the goal; a unit stays on it only while it still
    // contains something out of scope.
    for (final unitId in pendingScopeUnits) {
      expect(
        rebuiltUnits.contains(unitId),
        isFalse,
        reason: 'unit $unitId is rebuilt: take it off pendingScopeUnits',
      );
    }
  });

  test('V8 a rebuilt lesson introduces at most 8 vocabulary cards', () {
    for (final lesson in lessons.where(rebuilt)) {
      final cards = vocabulary.where((v) => v['lesson_id'] == lesson['id']);
      expect(cards.length, lessThanOrEqualTo(8), reason: 'lesson ${lesson['id']}');
    }
  });

  test('V9 a lecture step is one small idea, matching its grammar rule', () {
    for (final lesson in lessons) {
      for (final card in exercisesOf(lesson).where(isLecture)) {
        final data = dataOf(card);
        final id = card['id'];
        final rule = rules[data['grammar_rule_id']];
        expect(rule, isNotNull, reason: 'lecture $id names no known rule');
        final steps = (rule!['lecture'] as List? ?? const []);
        final index = data['rule_step'];
        expect(
          index is int && index >= 1 && index <= steps.length,
          isTrue,
          reason: 'lecture $id points at a missing rule step',
        );
        final step = steps[(index as int) - 1] as Map<String, dynamic>;
        for (final field in [
          'heading',
          'say',
          'table',
          'examples',
          'common_mistake',
        ]) {
          expect(
            data[field],
            step[field],
            reason: 'lecture $id: $field differs from ${rule['id']} — run '
                'python3 tool/sync_lecture_cards.py',
          );
        }
        expect(
          '${step['say']}'.split(RegExp(r'\s+')).length,
          lessThanOrEqualTo(40),
          reason: '${rule['id']} step $index says too much for one step',
        );
        expect((step['table'] as List? ?? const []).length, lessThanOrEqualTo(8));
        expect((step['examples'] as List? ?? const []).length, greaterThanOrEqualTo(2));
        expect(
          (data['items'] as List? ?? const []),
          isNotEmpty,
          reason: 'lecture $id needs items for apps without the lecture layout',
        );
      }
    }
  });

  test('V10 every required A1/A2 item is taught once its level is rebuilt', () {
    final required = scope['required'] as Map<String, dynamic>;
    for (final level in ['A1', 'A2']) {
      final levelUnits = [
        for (final entry in units.entries)
          if ('${entry.value['phase']}'.toUpperCase() == level &&
              standard(entry.key))
            entry.key,
      ];
      if (!levelUnits.every(rebuiltUnits.contains)) continue;
      final taught = <String>{
        for (final lesson in lessons)
          for (final card in exercisesOf(lesson).where(isLecture))
            ...((rules[dataOf(card)['grammar_rule_id']]?['concept_keys']
                        as List?) ??
                    const [])
                .cast<String>(),
      };
      final missing = [
        for (final item in (required[level] as List))
          if (!taught.contains(item['key'])) item['key'],
      ];
      expect(missing, isEmpty, reason: '$level lectures never teach these');
    }
  });
}

/// Units still carrying out-of-scope content until they are rebuilt
/// (docs/sources/SCOPE_REVIEW_2026-09-24.md). It exists to be emptied.
const pendingScopeUnits = {22, 27, 29, 31};

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// level_scope.json writes patterns for Python; `(?i)` becomes a flag here.
RegExp _pattern(String source) =>
    source.startsWith('(?i)')
        ? RegExp(source.substring(4), caseSensitive: false, unicode: true)
        : RegExp(source, unicode: true);

List<String> _strings(Object? node) => switch (node) {
  final Map<dynamic, dynamic> map => [for (final v in map.values) ..._strings(v)],
  final List<dynamic> list => [for (final v in list) ..._strings(v)],
  final String s => [s],
  _ => const [],
};
