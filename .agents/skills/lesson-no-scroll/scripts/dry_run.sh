#!/bin/zsh
# Assess units before converting them: measure what would still scroll on a
# small phone if they were switched on to slides. Nothing is committed; the
# pilot setting and the budget file are restored on exit.
#
#   .agents/skills/lesson-no-scroll/scripts/dry_run.sh 5 6 [--out DIR]
#
# Run from the repo root, outside the sandbox (flutter needs it).
set -euo pipefail

pilot=lib/core/config/unit_guide_pilot.dart
budget=test/fixtures/no_scroll_budget.json
out=${TMPDIR:-/tmp}
units=()
while (( $# )); do
  case $1 in
    --out) out=$2; shift 2 ;;
    *) units+=$1; shift ;;
  esac
done
(( ${#units} )) || { echo "usage: dry_run.sh UNIT… [--out DIR]" >&2; exit 2; }

if ! git diff --quiet -- $pilot $budget; then
  echo "$pilot or $budget has uncommitted changes; commit or stash them first." >&2
  exit 1
fi
trap 'git checkout -q -- $pilot $budget' EXIT

cp $budget $out/no_scroll_budget.before.json
python3 - $pilot ${units[@]} <<'PY'
import re, sys
path, units = sys.argv[1], {int(u) for u in sys.argv[2:]}
src = open(path).read()
m = re.search(r'const unitGuidePilotUnits = \{([^}]*)\};', src)
current = {int(x) for x in m.group(1).split(',') if x.strip()}
new = ', '.join(str(u) for u in sorted(current | units))
open(path, 'w').write(src[:m.start()] + f'const unitGuidePilotUnits = {{{new}}};' + src[m.end():])
PY

UPDATE_NO_SCROLL_BUDGET=1 flutter test test/no_scroll_fit_test.dart > $out/dry_run.log 2>&1 \
  || { tail -30 $out/dry_run.log; exit 1; }
cp $budget $out/no_scroll_budget.after.json

python3 - $out ${units[@]} <<'PY'
import collections, glob, json, sys
out, units = sys.argv[1], {int(u) for u in sys.argv[2:]}
before = json.load(open(f'{out}/no_scroll_budget.before.json'))['scrolls']
after = json.load(open(f'{out}/no_scroll_budget.after.json'))['scrolls']
ex = {}
for f in glob.glob('assets/curriculum/lessons/*.json'):
    for e in json.load(open(f))['exercises']:
        ex[str(e['id'])] = e
def kind(e):
    style = e['data'].get('style')
    return e['type'] + (f'/{style}' if e['type'] == 'teaching' else '')
mine = sorted((i for i, e in ex.items() if e['lesson_id'] // 100 in units), key=int)
count = collections.Counter(kind(ex[i]) for i in mine)
b = collections.Counter(kind(ex[i]) for i in mine if i in before)
a = collections.Counter(kind(ex[i]) for i in mine if i in after)
print(f'Units {sorted(units)}: {len(mine)} exercises; scroll today {sum(b.values())}, '
      f'with slides {sum(a.values())}\n')
print(f'{"kind":32} {"total":>5} {"today":>6} {"slides":>7}')
for k in sorted(count, key=lambda k: -b[k]):
    if b[k] or a[k]:
        print(f'{k:32} {count[k]:5} {b[k]:6} {a[k]:7}')
print('\nStill scrolling with slides (id, lesson, kind, pt over):')
for i in mine:
    if i in after:
        print(f'  {i:>6}  {ex[i]["lesson_id"]}  {kind(ex[i]):30} {after[i]}')
others = [i for i in set(before) ^ set(after) if ex.get(i, {}).get('lesson_id', 0) // 100 not in units]
if others:
    print(f'\nChanged OUTSIDE these units (look at why): {sorted(others, key=int)[:20]}')
PY
echo "\nNext: scripts/slide_heights.sh <ids> to see which part of each slide overflows."
