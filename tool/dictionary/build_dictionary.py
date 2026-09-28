#!/usr/bin/env python3
"""Build the in-app dictionary for one level from its hand-written sources.

    python3 tool/dictionary/build_dictionary.py a1            # build
    python3 tool/dictionary/build_dictionary.py a1 --check    # verify only

Sources live in tool/dictionary/<level>/*.txt, one block per word (format at
the bottom of this file). The build adds what the course already knows:

- the unit where each word is first met, from the level's lessons and the
  review vocabulary;
- up to two examples, taken from the course's own Czech/English pairs
  wherever the word appears in them (a source `ex:` line comes first);
- a search index of every form of the word.

It also cross-checks the forms against the course: every Czech word form a
learner meets in the level's lessons or review cards must be a form of some
dictionary word,
or be listed in <level>/not_words.txt (names, letters, English). A form the
lessons use that no table produces is either a missing word or a wrong table,
so --check fails on it.

Output: assets/dictionary/<level>_dictionary.json.
"""

from __future__ import annotations

import glob
import json
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

LEVEL_UNITS = {
    'a1': set(range(1, 16)) | {28, 30},
    'a2': set(range(16, 28)) | {29, 31},
}

CASES = [
    ('1', 'kdo? co?'),
    ('2', 'koho? čeho?'),
    ('3', 'komu? čemu?'),
    ('4', 'koho? co?'),
    ('5', 'calling someone'),
    ('6', 'o kom? o čem?'),
    ('7', 's kým? s čím?'),
]

PERSONS = ['já', 'ty', 'on / ona / ono', 'my', 'vy', 'oni']

GENDERS = {
    'm-anim': 'masculine (person or animal)',
    'm-inan': 'masculine',
    'f': 'feminine',
    'n': 'neuter',
}

POS_LABELS = {
    'noun': 'noun',
    'verb': 'verb',
    'adj': 'adjective',
    'pron': 'pronoun',
    'num': 'number',
    'adv': 'adverb',
    'prep': 'preposition',
    'conj': 'conjunction',
    'part': 'word',
    'interj': 'exclamation',
    'phrase': 'phrase',
}

WORD = re.compile(r"[A-Za-zÁČĎÉĚÍŇÓŘŠŤÚŮÝŽáčďéěíňóřšťúůýž]+")

# Lesson fields that hold Czech learners read or hear. English fields and
# instructions are left out on purpose: they are not words of the level.
CZECH_FIELDS = {
    'cz', 'blank_answers', 'answer_key', 'text', 'left', 'sentence', 'say',
    'transcript_cz', 'words', 'expected_phrases', 'question_cz', 'prompt_cz',
    'text_cz', 'target_text', 'sample_answer', 'expected_text', 'key_vocab',
    'name_say',
}

# answer_key is Czech only where it is the Czech the learner types; elsewhere
# it is an English summary ("plan invitation", "journey update") or pairs
# ("byt-apartment"), and dialogues and pronunciation carry their Czech in
# their gaps and target text anyway. A translation's Czech side is read
# below, by direction.
TYPED_ANSWER_TYPES = {'fill_blank', 'dictation', 'word_order', 'error_correction'}

# A2's teaching steps narrate in English in fields that hold Czech in A1.
ENGLISH_MARKERS = {
    'the', 'you', 'is', 'are', 'of', 'this', 'that', 'we', 'for', 'with',
    'your', 'it', 'can', 'what', 'when', 'how', 'will', 'use', 'means',
}


def learner_czech(text: str) -> str:
    """The Czech of a lesson string: bracketed hints and English cues
    ("___ (At the stop.)", "(jít — to go)") left out, and nothing at all when
    the string reads as English."""
    text = re.sub(r'\([^)]*\)', ' ', text)
    words = [w.lower() for w in WORD.findall(text)]
    if sum(w in ENGLISH_MARKERS for w in words) >= 2:
        return ''
    return text


def fold(text: str) -> str:
    """Lowercase without diacritics: what a learner types without a Czech
    keyboard. `ů` and `ú` both fold to `u`."""
    text = unicodedata.normalize('NFD', text.lower())
    return ''.join(c for c in text if unicodedata.category(c) != 'Mn')


# ---------------------------------------------------------------- sources


@dataclass
class Entry:
    cz: str
    source: str
    pos: str = ''
    gender: str | None = None
    plural_only: bool = False
    aspect: str | None = None
    meanings: list[str] = field(default_factory=list)
    related: list[str] = field(default_factory=list)
    note: str | None = None
    case: str | None = None
    sg: list[str] | None = None
    pl: list[str] | None = None
    pres: list[str] | None = None
    past: list[str] | None = None
    imp: list[str] | None = None
    neg: list[str] | None = None
    fut: list[str] | None = None
    pair: str | None = None
    cmp: str | None = None
    decl: str | None = None
    tables: list[dict] = field(default_factory=list)
    keys: list[tuple[str, str]] = field(default_factory=list)
    examples: list[tuple[str, str]] = field(default_factory=list)
    extra_forms: list[str] = field(default_factory=list)
    see: list[str] = field(default_factory=list)
    id: str = ''


def cells(value: str) -> list[str]:
    return [c.strip() for c in value.split(',')]


def parse_sources(level: str) -> list[Entry]:
    entries: list[Entry] = []
    for path in sorted((ROOT / 'tool' / 'dictionary' / level).glob('*.txt')):
        if path.name == 'not_words.txt':
            continue
        current: Entry | None = None
        table: dict | None = None
        for n, raw in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            line = raw.strip()
            where = f'{path.name}:{n}'
            if not line or line.startswith('#'):
                continue
            if line.startswith('@'):
                current = Entry(cz=line[1:].strip(), source=where)
                entries.append(current)
                table = None
                continue
            if current is None or ':' not in line:
                raise SystemExit(f'{where}: expected "@ word" or "key: value"')
            key, value = (s.strip() for s in line.split(':', 1))
            e = current
            if key == 'pos':
                parts = value.split()
                e.pos = parts[0]
                for p in parts[1:]:
                    if p in GENDERS:
                        e.gender = p
                    elif p == 'pl':
                        e.plural_only = True
                    elif p in ('impf', 'pf'):
                        e.aspect = p
                    else:
                        raise SystemExit(f'{where}: unknown pos flag {p!r}')
                if e.pos not in POS_LABELS:
                    raise SystemExit(f'{where}: unknown pos {e.pos!r}')
            elif key == 'en':
                e.meanings = [m.strip() for m in value.split(';') if m.strip()]
            elif key == 'rel':
                e.related = [m.strip() for m in value.split(';') if m.strip()]
            elif key == 'note':
                e.note = value
            elif key == 'case':
                e.case = value
            elif key in ('sg', 'pl', 'pres', 'past', 'imp', 'neg', 'fut'):
                setattr(e, key, cells(value))
            elif key == 'pair':
                e.pair = value
            elif key == 'cmp':
                e.cmp = value
            elif key == 'decl':
                if value != 'adj':
                    raise SystemExit(f'{where}: decl only takes "adj"')
                e.decl = value
            elif key == 'forms':
                e.extra_forms += [c for c in cells(value) if c]
            elif key == 'see':
                e.see += [c for c in cells(value) if c]
            elif key == 'key':
                label, form = (s.strip() for s in value.split('=', 1))
                e.keys.append((label, form))
            elif key == 'ex':
                cz, en = (s.strip() for s in value.split('=', 1))
                e.examples.append((cz, en))
            elif key == 'table':
                head = [c.strip() for c in value.split('|')]
                table = {'title': head[0], 'columns': head[1:], 'rows': []}
                e.tables.append(table)
            elif key == 'row':
                if table is None:
                    raise SystemExit(f'{where}: row before table')
                parts = [c.strip() for c in value.split('|')]
                table['rows'].append({'label': case_label(parts[0]),
                                      'cells': parts[1:]})
            else:
                raise SystemExit(f'{where}: unknown key {key!r}')
    return entries


def case_label(label: str) -> str:
    for number, question in CASES:
        if label == number:
            return f'{number} · {question}'
    return label


# ---------------------------------------------------------------- tables


def split_alternatives(cell: str) -> list[str]:
    return [c.strip() for c in cell.split('/') if c.strip() and c.strip() != '—']


def noun_tables(e: Entry) -> list[dict]:
    columns, data = [], []
    if e.sg:
        columns.append('singular')
        data.append(e.sg)
    if e.pl:
        columns.append('plural')
        data.append(e.pl)
    for column in data:
        if len(column) != 7:
            raise SystemExit(f'{e.source}: a case column needs 7 forms, got {len(column)}')
    rows = [{'label': f'{n} · {q}', 'cells': [col[i] for col in data]}
            for i, (n, q) in enumerate(CASES)]
    return [{'title': 'Cases', 'columns': columns, 'rows': rows}]


def past_forms(e: Entry) -> list[str]:
    """He / she / it / they (m. people) / they (others) from the l-form."""
    if not e.past:
        return []
    if len(e.past) == 5:
        return e.past
    if len(e.past) != 1:
        raise SystemExit(f'{e.source}: past takes 1 or 5 forms')
    m = e.past[0]
    return [m, m + 'a', m + 'o', m + 'i', m + 'y']


def reflexive(e: Entry) -> str:
    for r in (' se', ' si'):
        if e.cz.endswith(r):
            return r
    return ''


def verb_tables(e: Entry) -> list[dict]:
    refl = reflexive(e)
    tables = []
    if e.pres:
        if len(e.pres) != 6:
            raise SystemExit(f'{e.source}: pres needs 6 forms')
        title = 'Future' if e.aspect == 'pf' else 'Present'
        tables.append({
            'title': title,
            'columns': [''],
            'rows': [{'label': p, 'cells': [with_refl(f, refl)]}
                     for p, f in zip(PERSONS, e.pres)],
        })
    if e.past:
        m, f, n, pm, po = past_forms(e)
        # Czech keeps the reflexive after the auxiliary: myl jsem se.
        tables.append({
            'title': 'Past',
            'columns': [''],
            'rows': [
                {'label': 'já (man / woman)', 'cells': [f'{m} jsem{refl} / {f} jsem{refl}']},
                {'label': 'on / ona / ono', 'cells': [with_refl(f'{m} / {f} / {n}', refl)]},
                {'label': 'oni', 'cells': [with_refl(f'{pm} / {po}', refl)]},
            ],
        })
    if e.imp:
        labels = ['to one person (ty)', 'to several / polite (vy)']
        if len(e.imp) == 3:
            labels = ['to one person (ty)', "let's (my)", 'to several / polite (vy)']
        tables.append({
            'title': 'Command',
            'columns': [''],
            'rows': [{'label': lab, 'cells': [with_refl(f, refl)]}
                     for lab, f in zip(labels, e.imp)],
        })
    if e.fut:
        tables.append({
            'title': 'Future',
            'columns': [''],
            'rows': [{'label': p, 'cells': [with_refl(f, refl)]}
                     for p, f in zip(PERSONS, e.fut)],
        })
    return tables


def with_refl(forms: str, refl: str) -> str:
    if not refl:
        return forms
    return ' / '.join(f'{f.strip()}{refl}' for f in forms.split('/'))


HARD = [
    # m-anim, m-inan, f, n
    ('ý', 'ý', 'á', 'é'), ('ého', 'ého', 'é', 'ého'), ('ému', 'ému', 'é', 'ému'),
    ('ého', 'ý', 'ou', 'é'), ('ý', 'ý', 'á', 'é'), ('ém', 'ém', 'é', 'ém'),
    ('ým', 'ým', 'ou', 'ým'),
]
HARD_PL = [
    ('í', 'é', 'é', 'á'), ('ých',) * 4, ('ým',) * 4, ('é', 'é', 'é', 'á'),
    ('í', 'é', 'é', 'á'), ('ých',) * 4, ('ými',) * 4,
]


def soften_plural(stem: str) -> str:
    """Masculine animate plural of a hard adjective: mladý → mladí,
    velký → velcí, drahý → drazí, tichý → tiší, dobrý → dobří."""
    for hard, soft in (('ck', 'čt'), ('sk', 'št'), ('ch', 'š'), ('k', 'c'),
                       ('h', 'z'), ('r', 'ř')):
        if stem.endswith(hard):
            return stem[: -len(hard)] + soft
    return stem


def adjective_tables(e: Entry) -> list[dict]:
    word = e.cz
    if word.endswith('ý'):
        stem = word[:-1]
        sg = [[stem + end for end in row] for row in HARD]
        pl = [[stem + end for end in row] for row in HARD_PL]
        pl[0][0] = soften_plural(stem) + 'í'
        pl[4][0] = pl[0][0]
    elif word.endswith('í'):
        stem = word[:-1]
        # m-anim, m-inan, f, n
        soft = [('í', 'í', 'í', 'í'), ('ího', 'ího', 'í', 'ího'),
                ('ímu', 'ímu', 'í', 'ímu'), ('ího', 'í', 'í', 'í'),
                ('í', 'í', 'í', 'í'), ('ím', 'ím', 'í', 'ím'),
                ('ím', 'ím', 'í', 'ím')]
        sg = [[stem + end for end in row] for row in soft]
        pl = [[stem + end] * 4
              for end in ('í', 'ích', 'ím', 'í', 'í', 'ích', 'ími')]
    else:
        return []
    columns = ['m. person', 'm. thing', 'f.', 'n.']
    return [
        {'title': 'Singular', 'columns': columns,
         'rows': [{'label': f'{n} · {q}', 'cells': row}
                  for (n, q), row in zip(CASES, sg)]},
        {'title': 'Plural', 'columns': columns,
         'rows': [{'label': f'{n} · {q}', 'cells': row}
                  for (n, q), row in zip(CASES, pl)]},
    ]


def tables_for(e: Entry) -> list[dict]:
    if e.tables:
        return e.tables
    if e.pos == 'noun' and (e.sg or e.pl):
        return noun_tables(e)
    if e.pos == 'verb':
        return verb_tables(e)
    if e.pos == 'adj' or e.decl == 'adj':
        return adjective_tables(e)
    return []


def key_forms(e: Entry, tables: list[dict]) -> list[dict]:
    keys = [{'label': label, 'cz': form} for label, form in e.keys]
    if keys:
        return keys
    if e.pos == 'noun' and (e.sg or e.pl):
        if e.sg and e.pl:
            keys.append({'label': 'plural', 'cz': e.pl[0]})
        col = e.sg or e.pl
        keys.append({'label': 'object form (4)', 'cz': col[3]})
        keys.append({'label': 'after v, na, o (6)', 'cz': col[5]})
    elif e.pos == 'verb':
        refl = reflexive(e)
        if e.pres:
            keys.append({'label': 'já', 'cz': with_refl(e.pres[0], refl)})
            keys.append({'label': 'on / ona', 'cz': with_refl(e.pres[2], refl)})
            keys.append({'label': 'oni', 'cz': with_refl(e.pres[5], refl)})
        if e.past:
            m, f, *_ = past_forms(e)
            keys.append({'label': 'past', 'cz': with_refl(f'{m} / {f}', refl)})
        if e.pair:
            keys.append({'label': 'pair' if e.aspect else 'pair', 'cz': e.pair})
    elif (e.pos == 'adj' or e.decl == 'adj') and tables:
        row = tables[0]['rows'][0]['cells']
        keys.append({'label': 'm / f / n', 'cz': f'{row[1]} · {row[2]} · {row[3]}'})
        if e.cmp:
            keys.append({'label': 'more …', 'cz': e.cmp})
            keys.append({'label': 'most …', 'cz': most(e.cmp)})
    elif e.pos == 'adv' and e.cmp:
        keys.append({'label': 'more …', 'cz': e.cmp})
        keys.append({'label': 'most …', 'cz': most(e.cmp)})
    return keys


def superlatives(e: Entry) -> list[str]:
    """Comparatives and their superlatives (nej- + comparative)."""
    if not e.cmp:
        return []
    out = []
    for c in split_alternatives(e.cmp):
        out += [c.lower(), 'nej' + c.lower()]
    return out


def most(cmp: str) -> str:
    return ' / '.join('nej' + c for c in split_alternatives(cmp))


def all_forms(e: Entry, tables: list[dict]) -> set[str]:
    forms: set[str] = {e.cz.lower()}
    refl = reflexive(e)
    bare = e.cz[: -len(refl)] if refl else e.cz
    forms.add(bare.lower())

    def add(text: str):
        for alt in split_alternatives(text):
            for part in re.split(r'\s*/\s*|\s*·\s*', alt):
                part = part.strip().lower()
                if not part or part == '—':
                    continue
                forms.add(part)
                # "pil jsem se" → also "pil"
                words = WORD.findall(part)
                if len(words) > 1 and e.pos in ('verb', 'adj', 'noun', 'pron', 'num'):
                    for w in words:
                        if w not in ('jsem', 'se', 'si'):
                            forms.add(w)

    for t in tables:
        for row in t['rows']:
            for c in row['cells']:
                add(c)
    for c in (e.sg or []) + (e.pl or []):
        add(c)
    if e.pos == 'verb':
        for c in (e.pres or []) + (e.imp or []) + (e.fut or []):
            add(c)
        for f in past_forms(e):
            add(f)
        negatable = [f for c in (e.pres or []) + (e.imp or []) + (e.fut or [])
                     for f in split_alternatives(c)] + past_forms(e)
        if e.neg:
            for c in e.neg:
                add(c)
        else:
            for f in negatable:
                forms.add('ne' + f.lower())
        forms.add('ne' + bare.lower())
    if e.pos in ('adj', 'adv'):
        # Negative adjectives (nový → nenový) are rare at A1; comparatives and
        # superlatives are indexed so "větší" and "největší" find "velký".
        # An adjective's comparative declines like any -í adjective (lepšího,
        # nejlepší); an adverb's does not (rychleji, nejrychleji).
        for c in superlatives(e):
            forms.add(c)
            if e.pos == 'adj' and c.endswith('í'):
                for t in adjective_tables(Entry(cz=c, source=e.source, pos='adj')):
                    for row in t['rows']:
                        for cell in row['cells']:
                            forms.add(cell.lower())
    for c in e.extra_forms:
        add(c)
    return forms


# ---------------------------------------------------------------- course data


def lesson_files(level: str):
    units = LEVEL_UNITS[level]
    for path in sorted(glob.glob(str(ROOT / 'assets/curriculum/lessons/unit*_lesson*.json'))):
        data = json.loads(Path(path).read_text(encoding='utf-8'))
        if data['unit_id'] in units:
            yield data


def walk(node, key=None):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from walk(v, k)
    elif isinstance(node, list):
        for x in node:
            yield from walk(x, key)
    elif isinstance(node, str):
        yield key, node


def pairs_in(node):
    """Czech/English pairs the course itself shows side by side."""
    if isinstance(node, dict):
        for cz_key, en_key in (('cz', 'en'), ('sentence', 'sentence_en'),
                               ('text_cz', 'text_en'), ('left', 'right'),
                               ('example_cz', 'example_en')):
            cz, en = node.get(cz_key), node.get(en_key)
            if isinstance(cz, str) and isinstance(en, str) and cz and en:
                yield cz.strip(), en.strip()
        for v in node.values():
            yield from pairs_in(v)
    elif isinstance(node, list):
        for x in node:
            yield from pairs_in(x)


def course_data(level: str):
    first_seen: dict[str, int] = {}     # token → first unit
    pairs: list[tuple[str, str, int]] = []
    for lesson in lesson_files(level):
        unit = lesson['unit_id']

        def note(text: str) -> None:
            for w in WORD.findall(learner_czech(text)):
                w = w.lower()
                if w not in first_seen or unit < first_seen[w]:
                    first_seen[w] = unit

        for exercise in lesson['exercises']:
            for key, text in walk(exercise):
                if key not in CZECH_FIELDS:
                    continue
                if key == 'answer_key' and exercise['type'] not in TYPED_ANSWER_TYPES:
                    continue
                note(text)
            if exercise['type'] == 'translation':
                data = exercise['data']
                if data.get('direction') == 'en_to_cz':
                    for answer in data.get('accepted_answers') or []:
                        note(answer)
                else:
                    note(data.get('source') or '')
        for cz, en in pairs_in(lesson['exercises']):
            pairs.append((cz, en, unit))
    # A level's review cards by unit, not by file: the a2 file also holds
    # A1's review units 28 and 30.
    vocab = [v for f in ('a1', 'a2')
             for v in json.loads((ROOT / f'assets/vocabulary/{f}_vocabulary.json').read_text(encoding='utf-8'))
             if v['unit_id'] in LEVEL_UNITS[level]]
    for v in vocab:
        if v.get('example_cz') and v.get('example_en'):
            pairs.append((v['example_cz'].strip(), v['example_en'].strip(), v['unit_id']))
        # The review cards are part of the level too: their words must be in
        # the dictionary as much as the lessons' are.
        for text in (v.get('word_cz') or '', v.get('example_cz') or ''):
            for w in WORD.findall(text):
                w = w.lower()
                if w not in first_seen:
                    first_seen[w] = v['unit_id']
    return first_seen, pairs, vocab


def good_example(cz: str, en: str) -> bool:
    if not 6 <= len(cz) <= 60 or '…' in cz or '...' in cz or '___' in cz:
        return False
    if '/' in cz or '×' in cz or '→' in cz or '—' in cz or '|' in cz:
        return False
    if not re.search(r'[.!?]$', cz):
        return False
    return len(WORD.findall(cz)) >= 2


# ---------------------------------------------------------------- build


def slug(text: str) -> str:
    s = fold(text)
    s = re.sub(r'[^a-z0-9]+', '-', s).strip('-')
    return s or 'x'


def unit_numbers(level: str) -> dict[int, int]:
    """Course unit id → the number a learner sees: its place in the level,
    as the Learn tab counts (A1's review units 28 and 30 are its Units 16
    and 17; A2 starts again at Unit 1)."""
    units = json.loads((ROOT / f'assets/curriculum/{level}_units.json').read_text(encoding='utf-8'))
    if isinstance(units, dict):
        units = units.get('units', [])
    ordered = sorted(units, key=lambda u: u.get('order_index', u['id']))
    return {u['id']: n for n, u in enumerate(ordered, 1)}


def earlier_levels(level: str) -> list[str]:
    order = list(LEVEL_UNITS)
    return order[: order.index(level)]


def build(level: str, check_only: bool) -> int:
    entries = parse_sources(level)
    # Words of earlier levels: an A2 learner has them too (the app shows A1
    # and A2 together), so A2 lessons may use them and A2 must not repeat them.
    inherited: dict[str, set[str]] = {}
    for lower in earlier_levels(level):
        for e in parse_sources(lower):
            # By headword and part of speech: hezký and hezky share a slug.
            inherited[(e.cz, e.pos)] = all_forms(e, tables_for(e))
    first_seen, pairs, vocab = course_data(level)
    not_words = set()
    for lvl in earlier_levels(level) + [level]:
        nw = ROOT / 'tool' / 'dictionary' / lvl / 'not_words.txt'
        if nw.exists():
            for line in nw.read_text(encoding='utf-8').splitlines():
                line = line.split('#', 1)[0].strip()
                not_words.update(w.lower() for w in line.split())

    problems: list[str] = []
    numbers = unit_numbers(level)
    # An A2 learner's dictionary holds A1's words too, found by id.
    ids: dict[str, str] = {}
    for lower in earlier_levels(level):
        doc = json.loads((ROOT / f'assets/dictionary/{lower}_dictionary.json').read_text(encoding='utf-8'))
        for x in doc['entries']:
            ids[x['id']] = f'{lower} dictionary'
    out = []
    forms_by_entry = []
    for e in entries:
        if not e.pos or not e.meanings:
            problems.append(f'{e.source}: {e.cz!r} needs pos and en')
            continue
        e.id = slug(e.cz)
        if (e.cz, e.pos) in inherited:
            problems.append(f'{e.source}: {e.cz!r} is already a word of an earlier level')
            continue
        if e.id in ids:
            # Same spelling, different word (e.g. "stát" to cost / to stand).
            e.id = f'{e.id}-{e.pos}'
            if e.id in ids:
                problems.append(f'{e.source}: duplicate {e.cz!r} (also {ids[e.id]})')
                continue
        ids[e.id] = e.source
        tables = tables_for(e)
        forms = all_forms(e, tables)
        forms_by_entry.append((e, tables, forms))

    # Unit where each word is first met: the review vocabulary knows the
    # words it lists; otherwise the first lesson that uses any of its forms.
    vocab_units: dict[str, int] = {}
    for v in vocab:
        k = v['word_cz'].lower().strip(' .?!')
        vocab_units[k] = min(vocab_units.get(k, 99), v['unit_id'])

    covered: dict[str, list[str]] = {}
    for (word, _), forms in inherited.items():
        for f in forms:
            covered.setdefault(f, []).append(word)
    for e, tables, forms in forms_by_entry:
        for f in forms:
            covered.setdefault(f, []).append(e.id)

    for e, tables, forms in forms_by_entry:
        units = [first_seen[f] for f in forms if f in first_seen and ' ' not in f]
        if e.pos == 'phrase' or ' ' in e.cz:
            text = fold(e.cz)
            units += [u for cz, _, u in pairs if text in fold(cz)]
        if e.cz.lower() in vocab_units:
            units.append(vocab_units[e.cz.lower()])
        unit = min(units) if units else None

        examples = [{'cz': cz, 'en': en} for cz, en in e.examples]
        seen = {x['cz'] for x in examples}
        candidates = []
        for cz, en, u in pairs:
            if cz in seen or not good_example(cz, en):
                continue
            words = {w.lower() for w in WORD.findall(cz)}
            if e.pos == 'phrase':
                text = f' {fold(cz)} '
                hit = any(f' {fold(p)} ' in text or f' {fold(p)}' in text
                          for p in [e.cz] + e.extra_forms)
            elif ' ' in e.cz and e.pos == 'noun':
                # "volný čas": only the whole phrase counts, not "čas".
                hit = any(fold(f) in fold(cz) for f in forms if ' ' in f)
            else:
                hit = bool(words & {f for f in forms if ' ' not in f})
            if hit and cz.lower().strip(' .!?') != e.cz.lower():
                candidates.append((u, len(cz), cz, en))
        for u, _, cz, en in sorted(candidates):
            if len(examples) >= 2:
                break
            if cz not in seen:
                examples.append({'cz': cz, 'en': en})
                seen.add(cz)

        item = {
            'id': e.id,
            'cz': e.cz,
            'pos': e.pos,
            'pos_label': POS_LABELS[e.pos],
            'meanings': e.meanings,
        }
        if e.gender:
            item['gender'] = e.gender
            item['gender_label'] = GENDERS[e.gender]
        if e.plural_only:
            item['plural_only'] = True
            item['gender_label'] = f"{item.get('gender_label', '')} · plural only".strip(' ·')
        if e.aspect:
            item['aspect'] = {'impf': 'ongoing or repeated (imperfective)',
                              'pf': 'one finished action (perfective)'}[e.aspect]
        if e.related:
            item['related'] = e.related
        if e.note:
            item['note'] = e.note
        if e.case:
            item['case'] = e.case
        keys = key_forms(e, tables)
        if keys:
            item['key_forms'] = keys
        if tables:
            item['tables'] = tables
        if examples:
            item['examples'] = examples
        if e.see:
            item['see'] = e.see
        if unit is not None:
            item['unit'] = unit
            item['unit_no'] = numbers[unit]
        item['forms'] = sorted(forms)
        out.append(item)

    # Every form the lessons use must be a word of the dictionary.
    uncovered = sorted(t for t in first_seen
                       if t not in covered and t not in not_words)
    for t in uncovered:
        problems.append(f'lessons use "{t}" (unit {first_seen[t]}), which no dictionary word produces')

    for x in out:
        if not x.get('examples'):
            problems.append(f'{x["cz"]!r} has no example (add an ex: line)')

    out.sort(key=lambda x: (fold(x['cz']), x['cz']))
    doc = {'level': level.upper(), 'version': 1, 'entries': out}
    target = ROOT / 'assets' / 'dictionary' / f'{level}_dictionary.json'
    text = json.dumps(doc, ensure_ascii=False, separators=(',', ':')) + '\n'
    if check_only:
        if not target.exists() or target.read_text(encoding='utf-8') != text:
            problems.append(f'{target.relative_to(ROOT)} is out of date: run the build')
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding='utf-8')

    print(f'{level}: {len(out)} words, '
          f'{sum(1 for x in out if x.get("tables"))} with forms, '
          f'{sum(len(x.get("examples", [])) for x in out)} examples, '
          f'{len(first_seen)} lesson forms, {len(uncovered)} not covered')
    for p in problems:
        print('  ' + p)
    return 1 if problems else 0


if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] not in LEVEL_UNITS:
        raise SystemExit(__doc__)
    sys.exit(build(sys.argv[1], '--check' in sys.argv[2:]))


# Source format -------------------------------------------------------------
#
#   @ káva                         the word as the dictionary lists it
#   pos: noun f                    noun m-anim|m-inan|f|n [pl]; verb impf|pf;
#                                  adj; pron; num; adv; prep; conj; part;
#                                  interj; phrase
#   en: coffee                     meanings, separated by ";"
#   rel: drink; café               related English words, for search
#   sg: káva, kávy, kávě, kávu, kávo, kávě, kávou      7 cases, 1 → 7
#   pl: kávy, káv, kávám, kávy, kávy, kávách, kávami   alternatives with "/"
#   pres: piju/piji, piješ, pije, pijeme, pijete, pijou/pijí
#   past: pil                      or all five: šel, šla, šlo, šli, šly
#   imp: pij, pijte                or three: ty, my, vy
#   neg: nejsem, nejsi, není, …    only when "ne" + form is wrong
#   pair: vypít                    the other aspect
#   cmp: větší                     comparative
#   case: + 6 (locative)           what a preposition is followed by
#   table: Title | column | …      a hand-made table (pronouns, numbers)
#   row: 1 | já                    "1".."7" become the case labels
#   key: object = mě               the forms shown at the top of the page
#   forms: jdi, jděte              extra forms for search only
#   ex: Piju kávu. = I drink coffee.
#   note: usually plural
#   see: čaj                       related dictionary words
