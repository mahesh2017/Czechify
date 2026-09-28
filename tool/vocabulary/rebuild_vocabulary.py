"""Match a level's review cards to its lessons.

    python3 tool/vocabulary/rebuild_vocabulary.py a2            # rewrite
    python3 tool/vocabulary/rebuild_vocabulary.py a2 --check    # report only
    python3 tool/vocabulary/rebuild_vocabulary.py a2 --report docs/X.md

The rules Mahesh agreed for A1 (27 Sep 2026, commit 2c6ba8e0), as a tool:

1. A card its unit's lessons use points to the first lesson of the unit that
   uses it. Czech inflects, so a word counts as used when every word of the
   card has a form in the lesson (same stem, at most four letters more):
   "jablko" is used by a lesson that says "kilo jablek".
2. A card its unit does not use is kept and released with the unit
   (lesson_id null), not deleted.
3. A word-list item a lesson teaches (a teaching step in "list" or
   "image_cards" style) that has no card anywhere gets one, with the list's
   English and example; no pronunciation yet.
4. Exact duplicates within a unit (same Czech, same English) are removed.
   Same Czech with different English is reported, not touched.
5. A lesson introduces at most 8 cards (contract V8), keeping the words its
   own word list teaches first: the rest move to the unit's next lesson, and
   past its last lesson are released with the unit.

A1 was rebuilt by a one-off script before this tool, with another tie-break
for rule 5; run the tool on A2 and later levels, not on A1.

Only learner-visible Czech counts as use: English fields, explanations and
instructions are left out.
"""
from __future__ import annotations

import collections
import glob
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

LEVEL_UNITS = {
    'a1': set(range(1, 16)) | {28, 30},
    'a2': set(range(16, 28)) | {29, 31},
}
# New cards' ids start here, so a card's id says which rebuild added it.
NEW_ID_START = {'a1': 3001, 'a2': 4001}
MAX_PER_LESSON = 8
FILES = ['assets/vocabulary/a1_vocabulary.json',
         'assets/vocabulary/a2_vocabulary.json']

SKIP_KEYS = {'en', 'explanation', 'heading', 'body', 'intro', 'prompt',
             'scenario', 'image_label', 'style', 'type', 'kind', 'speaker',
             'mode', 'targets', 'instruction', 'play_all_label',
             'question_en', 'focus_sounds', 'hint', 'note', 'grammar_note',
             'error_type', 'image', 'audio_hash', 'direction', 'language'}
WORD = re.compile(r'[a-záčďéěíňóřšťúůýž]+')


def czech_strings(value, out: list[str]) -> None:
    if isinstance(value, str):
        out.append(value)
    elif isinstance(value, list):
        for item in value:
            czech_strings(item, out)
    elif isinstance(value, dict):
        for key, item in value.items():
            if key.endswith('_en') or key in SKIP_KEYS:
                continue
            czech_strings(item, out)


def lesson_tokens(units: set[int]) -> dict[int, set[str]]:
    tokens: dict[int, set[str]] = collections.defaultdict(set)
    for path in glob.glob(str(ROOT / 'assets/curriculum/lessons/unit*_lesson*.json')):
        for exercise in json.load(open(path, encoding='utf-8'))['exercises']:
            lesson = exercise['lesson_id']
            if lesson // 100 not in units:
                continue
            out: list[str] = []
            czech_strings(exercise['data'], out)
            out.append(exercise.get('answer_key') or '')
            for text in out:
                tokens[lesson].update(WORD.findall(text.lower()))
    return tokens


def token_in(token: str, tokens: set[str]) -> bool:
    if len(token) <= 3:
        return token in tokens
    stem = token[:max(3, len(token) - 2)]
    return any(t.startswith(stem) and len(t) - len(stem) <= 4 for t in tokens)


def card_in(card: dict, tokens: set[str]) -> bool:
    words = WORD.findall(card['word_cz'].lower())
    return bool(words) and all(token_in(w, tokens) for w in words)


def key(text: str) -> str:
    return re.sub(r'[^\wáčďéěíňóřšťúůýž ]', '', text.lower()).strip()


def word_list_items(units: set[int]):
    for unit in sorted(units):
        for path in sorted(glob.glob(str(ROOT / f'assets/curriculum/lessons/unit{unit:02d}_*.json'))):
            for exercise in json.load(open(path, encoding='utf-8'))['exercises']:
                data = exercise['data']
                if exercise['type'] != 'teaching' or data.get('style') not in ('list', 'image_cards'):
                    continue
                for item in data.get('items', []):
                    yield unit, exercise['lesson_id'], item


def rebuild(level: str, write: bool, report: str | None) -> int:
    units = LEVEL_UNITS[level]
    data = {}
    for path in FILES:
        raw = (ROOT / path).read_text(encoding='utf-8')
        cards = json.loads(raw)
        if json.dumps(cards, ensure_ascii=False, indent=2) != raw:
            raise SystemExit(f'{path} is not in the expected format')
        data[path] = cards
    everything = [c for cards in data.values() for c in cards]
    tokens = lesson_tokens(units)
    lessons_of = collections.defaultdict(list)
    for lesson in sorted(tokens):
        lessons_of[lesson // 100].append(lesson)

    log = collections.defaultdict(list)

    # 3. Cards for word-list items that have none.
    existing = {key(c['word_cz']) for c in everything}
    next_id = max([NEW_ID_START[level] - 1] +
                  [c['id'] for c in everything if c['id'] >= NEW_ID_START[level]]) + 1
    level_file = f'assets/vocabulary/{level}_vocabulary.json'
    added_ids = set()
    for unit, lesson, item in word_list_items(units):
        cz = (item.get('cz') or '').strip()
        en = (item.get('en') or '').strip()
        if not cz or not en or '…' in cz or '/' in cz or key(cz) in existing:
            continue
        existing.add(key(cz))
        example_cz = (item.get('sentence') or '').strip() or None
        example_en = (item.get('sentence_en') or '').strip() or None
        if example_cz and example_cz.lower() == cz.lower():
            example_cz = example_en = None
        card = {'id': next_id, 'word_cz': cz, 'word_en': en, 'ipa': None,
                'gender': None, 'unit_id': unit, 'example_cz': example_cz,
                'example_en': example_en, 'lesson_id': lesson}
        next_id += 1
        added_ids.add(card['id'])
        data[level_file].append(card)
        everything.append(card)
        log['added'].append((card,))

    # 1-2. Point each card at the first lesson of its unit that uses it (a
    # lesson whose word list teaches it uses it).
    taught = collections.defaultdict(set)
    for _, lesson, item in word_list_items(units):
        taught[lesson].add(key(item.get('cz') or ''))
    for card in everything:
        if card['unit_id'] not in units:
            continue
        using = [l for l in lessons_of[card['unit_id']]
                 if card_in(card, tokens[l]) or key(card['word_cz']) in taught[l]]
        # From the lessons alone, never from the card's old lesson, so a
        # second run finds nothing to change.
        target = using[0] if using else None
        if card.get('lesson_id') == target or card['id'] in added_ids:
            card['lesson_id'] = target
            continue
        if target is None:
            log['released'].append((card, card.get('lesson_id')))
        else:
            log['pointed'].append((card, card.get('lesson_id'), target))
        card['lesson_id'] = target

    # 4. Exact duplicates within a unit.
    seen = {}
    drop = set()
    for card in sorted(everything, key=lambda c: (c.get('lesson_id') is None, c['id'])):
        if card['unit_id'] not in units:
            continue
        k = (card['unit_id'], key(card['word_cz']))
        if k in seen:
            first = seen[k]
            if key(first['word_en']) == key(card['word_en']):
                drop.add(card['id'])
                log['duplicate removed'].append((card, first['id']))
            else:
                log['same Czech, different English'].append((card, first))
        else:
            seen[k] = card
    for path in data:
        data[path] = [c for c in data[path] if c['id'] not in drop]
    everything = [c for c in everything if c['id'] not in drop]

    # 5. At most 8 cards per lesson; the rest to the unit's next lesson. A
    # lesson keeps the words its own word list teaches first, then the
    # oldest cards.
    for unit in sorted(units):
        carry: list[dict] = []
        for lesson in lessons_of[unit]:
            here = carry + sorted(
                (c for c in everything if c.get('lesson_id') == lesson),
                key=lambda c: (key(c['word_cz']) not in taught[lesson], c['id']))
            carry = here[MAX_PER_LESSON:]
            for card in here[:MAX_PER_LESSON]:
                if card['lesson_id'] != lesson:
                    log['moved to next lesson'].append((card, card['lesson_id'], lesson))
                    card['lesson_id'] = lesson
        for card in carry:
            log['released: lessons full'].append((card, card['lesson_id']))
            card['lesson_id'] = None

    changed = False
    for path, cards in data.items():
        text = json.dumps(cards, ensure_ascii=False, indent=2)
        if text != (ROOT / path).read_text(encoding='utf-8'):
            changed = True
            if write:
                (ROOT / path).write_text(text, encoding='utf-8')

    level_cards = [c for c in everything if c['unit_id'] in units]
    print(f'{level}: {len(level_cards)} cards, '
          f'{sum(1 for c in level_cards if c.get("lesson_id"))} with a lesson')
    for kind, rows in log.items():
        print(f'  {kind}: {len(rows)}')
    if report:
        write_report(level, log, ROOT / report)
    if not write and changed:
        print('  out of date: run without --check')
        return 1
    return 0


def write_report(level: str, log, path: Path) -> None:
    out = [f'# {level.upper()} review cards rebuilt against the v1.2 lessons', '',
           'Made by `tool/vocabulary/rebuild_vocabulary.py` (rules in its header).',
           'Review cards are not graded; please check the Czech and English.', '']
    def table(title, header, rows):
        out.extend([f'## {title} ({len(rows)})', '', '| ' + ' | '.join(header) + ' |',
                    '|' + '---|' * len(header)])
        out.extend('| ' + ' | '.join(str(x) for x in r) + ' |' for r in rows)
        out.append('')
    table('New cards from the lesson word lists', ['Unit', 'Lesson', 'Czech', 'English', 'Example'],
          [(c['unit_id'], c['lesson_id'], c['word_cz'], c['word_en'], c['example_cz'] or '')
           for (c,) in log['added']])
    table('Same Czech, different English (not changed): keep both, or merge?',
          ['Unit', 'Czech', 'Card', 'English', 'Other card', 'Its English'],
          [(c['unit_id'], c['word_cz'], c['id'], c['word_en'], o['id'], o['word_en'])
           for c, o in log['same Czech, different English']])
    table('Duplicates removed', ['Unit', 'Czech', 'English', 'Kept card'],
          [(c['unit_id'], c['word_cz'], c['word_en'], other) for c, other in log['duplicate removed']])
    table('Not used by their unit’s lessons (kept, released with the unit)', ['Unit', 'Czech', 'English'],
          [(c['unit_id'], c['word_cz'], c['word_en']) for c, _ in log['released']])
    path.write_text('\n'.join(out), encoding='utf-8')


if __name__ == '__main__':
    args = sys.argv[1:]
    if not args or args[0] not in LEVEL_UNITS:
        raise SystemExit(__doc__)
    report = args[args.index('--report') + 1] if '--report' in args else None
    sys.exit(rebuild(args[0], '--check' not in args, report))
