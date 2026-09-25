#!/bin/zsh
# Measure the answer feedback sheet over exercises on an iPhone SE: its height
# and how far the exercise then scrolls, after a first miss, a fourth miss and
# a right answer. Units of the given exercises are switched on for the run.
#
#   .agents/skills/lesson-no-scroll/scripts/feedback_heights.sh 2103,2214,4101
#
# Output: id, type, state, sheet height, exercise area left, pt it scrolls.
# Run from the repo root, outside the sandbox (flutter needs it).
set -euo pipefail

ids=${1:?usage: feedback_heights.sh ID[,ID…]}
here=${0:A:h}
pilot=lib/core/config/unit_guide_pilot.dart
probe=test/zz_feedback_heights_probe_test.dart

if ! git diff --quiet -- $pilot; then
  echo "$pilot has uncommitted changes; commit or stash them first." >&2
  exit 1
fi
trap 'git checkout -q -- $pilot; rm -f $probe' EXIT

python3 - $pilot $ids <<'PY'
import re, sys
path, ids = sys.argv[1], sys.argv[2]
units = {int(i) // 1000 for i in ids.split(',')}
src = open(path).read()
m = re.search(r'const unitGuidePilotUnits = \{([^}]*)\};', src)
current = {int(x) for x in m.group(1).split(',') if x.strip()}
new = ', '.join(str(u) for u in sorted(current | units))
open(path, 'w').write(src[:m.start()] + f'const unitGuidePilotUnits = {{{new}}};' + src[m.end():])
PY

cp $here/feedback_heights_probe_test.dart.txt $probe
flutter test $probe --dart-define=IDS=$ids 2>&1 | sed -n 's/^» //p'
