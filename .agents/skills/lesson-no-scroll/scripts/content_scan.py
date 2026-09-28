#!/usr/bin/env python3
"""The skill's content checks, over any number of units, in one pass.

    python3 .agents/skills/lesson-no-scroll/scripts/content_scan.py 16 17 …

Prints each check with the items it flags. Everything here is a candidate to
read, not a verdict: a dialogue gap may be guessable from the line before it,
a masculine form may be what the task asks for. The dialogues are printed in
full at the end, because the worst A1 errors (answers that don't reply to the
line before) can only be found by reading them.
"""
import collections
import glob
import json
import re
import sys

units = {int(u) for u in sys.argv[1:]}
if not units:
    raise SystemExit(__doc__)

found = collections.defaultdict(list)
dialogues = []

# A first- or second-person past or conditional: the speaker's gender shows.
PERSONAL = re.compile(r'\b(jsem|jsi|jsme|jste|bych|bys|byste|bychom)\b', re.I)
# The task says whose voice it is: then one gender is right.
GENDER_GIVEN = re.compile(r'\b(man|male|men|woman|female|he|she|him|her|'
                          r'masculine|feminine|mužský|ženský)\b', re.I)
PARTICIPLE = re.compile(r'\b(\w+(?:l|la|li|ly))\b')
NOT_PARTICIPLES = {'stůl', 'kostel', 'učitel', 'hotel', 'přítel', 'cíl', 'úkol',
                   'pronajímatel', 'kolo', 'škola', 'kila', 'pila', 'sůl',
                   'mýdla', 'jídla', 'auta', 'celý', 'dál', 'dále', 'místa'}
FOCUS_LETTERS = {'ř', 'ch', 'ě', 'ů', 'á', 'í', 'é', 'ú', 'ý', 'č', 'š', 'ž',
                 'ň', 'ť', 'ď', 'h'}


def masculine_only(answers, context):
    """Flags answers with a 1st/2nd-person -l form and no feminine version."""
    text = ' '.join(answers)
    if GENDER_GIVEN.search(context):
        return []
    if not PERSONAL.search(text + ' ' + context):
        return []
    lower = text.lower()
    missing = []
    for w in set(PARTICIPLE.findall(lower)):
        if w in NOT_PARTICIPLES or not w.endswith('l'):
            continue
        # šel → šla, přišel → přišla; the rest add -a (byl → byla).
        feminine = w[:-2] + 'la' if w.endswith('šel') else w + 'a'
        if not re.search(rf'\b{feminine}\b', lower):
            missing.append(w)
    if re.search(r'\brád\b', lower) and 'ráda' not in lower:
        missing.append('rád')
    return sorted(missing)


for path in sorted(glob.glob('assets/curriculum/lessons/unit*_lesson*.json')):
    unit = int(re.search(r'unit(\d+)', path).group(1))
    if unit not in units:
        continue
    for e in json.load(open(path, encoding='utf-8'))['exercises']:
        d, kind, i = e['data'], e['type'], e['id']
        blob = json.dumps(d, ensure_ascii=False)
        context = ' '.join(str(d.get(k, '')) for k in
                           ('sentence', 'hint', 'source', 'prompt_en',
                            'question_en', 'instruction')) + ' ' + e.get('prompt', '')

        if 'Mahesh' in blob:
            found['hard-coded name'].append(i)

        if kind == 'dialogue':
            lines, answers = d['lines'], d.get('blank_answers', [])
            dialogues.append((i, lines, answers))
            gaps = [k for k, l in enumerate(lines) if '___' in l['text']]
            if len(gaps) != len(answers):
                found['gap count differs from answer sets'].append(i)
            if gaps and gaps[0] == 0 and lines[0]['text'].strip() == '___':
                found['dialogue opens on a gap (nothing to reply to)'].append(i)
            for n, k in enumerate(gaps):
                line = lines[k]['text']
                if '(' not in line and line.strip() == '___':
                    ans = answers[n] if n < len(answers) else ['?']
                    found['uncued whole-line gap: can the answer be guessed?'].append(
                        f'{i}: after "{lines[k - 1]["text"] if k else "—"}" -> {ans}')
            for l in lines:
                if '/' in l['text']:
                    found['"/" inside a line (read aloud as written)'].append(
                        f'{i}: {l["text"]}')
            for group in answers:
                if any('/' in a for a in group):
                    found['"/" inside an accepted answer (untypeable)'].append(
                        f'{i}: {group}')
                if (m := masculine_only(group, context)):
                    found['masculine only'].append(f'{i}: {m} in {group}')

        for key in ('blank_answers',):
            if kind == 'dialogue':
                break
            for group in d.get(key, []):
                if any('/' in a for a in group):
                    found['"/" inside an accepted answer (untypeable)'].append(
                        f'{i}: {group}')
                if (m := masculine_only(group, context)):
                    found['masculine only'].append(f'{i}: {m} in {group}')
        if kind == 'translation':
            acc = d.get('accepted_answers', [])
            if any('/' in a for a in acc):
                found['"/" inside an accepted answer (untypeable)'].append(f'{i}: {acc}')
            if (m := masculine_only(acc, context)):
                found['masculine only'].append(f'{i}: {m} in {acc}')
        if kind == 'fill_blank' and (m := masculine_only([d.get('sentence', '')], context)):
            found['masculine only in the sentence itself'].append(
                f'{i}: {m} in "{d["sentence"]}"')

        if kind == 'pronunciation':
            target = d['target_text'].lower()
            for s in d.get('focus_sounds', []):
                if s in FOCUS_LETTERS and s not in target:
                    found['focus sound not in the sentence'].append(
                        f'{i}: {s} / {d["target_text"]}')
        if kind == 'speaking_task':
            phrases = d.get('expected_phrases', [])
            if any('/' in p for p in phrases):
                found['"/" in phrases to say'].append(f'{i}: {phrases}')
        if kind == 'writing_task' and any('/' in p for p in d.get('key_vocab', [])):
            found['"/" in writing key words'].append(f'{i}: {d["key_vocab"]}')
        if 'summar' in blob.lower():
            found['template summary question'].append(i)
        if kind == 'image_cards':
            for item in d.get('items', d.get('cards', [])):
                if not item.get('image') and not item.get('sentence'):
                    found['picture card without picture or sentence'].append(i)
                    break
        explanation = d.get('explanation') or d.get('grammar_note') or ''
        if len(explanation) > 220:
            found['explanation over 220 characters'].append(f'{i} ({len(explanation)})')

for check, items in found.items():
    print(f'\n## {check}: {len(items)}')
    for item in items:
        print(f'   {item}')

print(f'\n## Every dialogue, to read: {len(dialogues)}')
for i, lines, answers in dialogues:
    print(f'\n{i}:')
    it = iter(answers)
    for l in lines:
        text = l['text']
        if '___' in text:
            text += '  => ' + ' | '.join(next(it, ['?']))
        print(f'  {l["speaker"][:10]}: {text}')
