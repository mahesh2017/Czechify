#!/bin/zsh
# Assess units for the no-scroll rollout in one go: what would still scroll,
# and what the pilot's screen checks find, if the units were switched on.
# Nothing is committed; the pilot setting and the budget file are restored.
#
#   .agents/skills/lesson-no-scroll/scripts/assess_unit.sh 3 [4 …] [--out DIR]
#
# Prints:
#   1. the dry run (dry_run.sh): exercises that would still scroll, by kind,
#      with the keyboard up too;
#   2. the pilot's screen tests run with the units on: feedback over the
#      exercise, notebook comparison, Rule sheet, 200% text. Every line they
#      report is a finding for the plan.
# Then use slide_heights.sh / feedback_heights.sh on the ids to find causes.
# Run from the repo root, outside the sandbox (flutter needs it).
set -euo pipefail

here=${0:A:h}
pilot=lib/core/config/unit_guide_pilot.dart
out=${TMPDIR:-/tmp}
units=()
while (( $# )); do
  case $1 in
    --out) out=$2; shift 2 ;;
    *) units+=$1; shift ;;
  esac
done
(( ${#units} )) || { echo "usage: assess_unit.sh UNIT… [--out DIR]" >&2; exit 2; }
mkdir -p $out

echo "== 1. Dry run =="
$here/dry_run.sh ${units[@]} --out $out

if ! git diff --quiet -- $pilot; then
  echo "$pilot has uncommitted changes; commit or stash them first." >&2
  exit 1
fi
trap 'git checkout -q -- $pilot' EXIT
python3 - $pilot ${units[@]} <<'PY'
import re, sys
path, units = sys.argv[1], {int(u) for u in sys.argv[2:]}
src = open(path).read()
m = re.search(r'const unitGuidePilotUnits = \{([^}]*)\};', src)
current = {int(x) for x in m.group(1).split(',') if x.strip()}
new = ', '.join(str(u) for u in sorted(current | units))
open(path, 'w').write(src[:m.start()] + f'const unitGuidePilotUnits = {{{new}}};' + src[m.end():])
PY

echo "\n== 2. Pilot screen checks with units ${units[*]} on =="
flutter test test/feedback_overlay_test.dart test/pilot_learning_screens_test.dart \
  test/slides_pilot_tasks_test.dart > $out/assess_tests.log 2>&1 || true
python3 - $out/assess_tests.log <<'PY'
import re, sys
log = open(sys.argv[1]).read()
findings = re.findall(r"^\s+'(.+?)',?$", log, re.M)
# A one-item list is printed on one line: Actual: ['…']
for one in re.findall(r"Actual: \[(.+)\]$", log, re.M):
    findings += re.findall(r"'([^']+)'", one)
reasons = re.findall(r'^(?:Unit \d+: .+|\S+ slide \d+ scrolls|.+ with the keyboard up)$', log, re.M)
failed = re.findall(r'^\d\d:\d\d \+\d+ -\d+: (.+?) \[E\]$', log, re.M)
if not failed:
    print('All pilot screen checks pass.')
for f in dict.fromkeys(failed):
    print(f'FAILED: {f}')
for line in dict.fromkeys(findings + reasons):
    print(f'  - {line}')
if failed:
    print(f'Full log: {sys.argv[1]}')
PY
