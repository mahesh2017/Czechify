#!/bin/zsh
# Diagnose why exercises overflow: turns each slide on the iPhone SE lesson
# area and prints, for every slide that scrolls, the height of each part.
# Units of the given exercises are switched on to slides for the run only.
#
#   .agents/skills/lesson-no-scroll/scripts/slide_heights.sh 4100,29103,31113
#
# Exercise ids start with their unit: 4100 is Unit 4, 29103 is Unit 29.
# Run from the repo root, outside the sandbox (flutter needs it).
set -euo pipefail

ids=${1:?usage: slide_heights.sh ID[,ID…]}
here=${0:A:h}
pilot=lib/core/config/unit_guide_pilot.dart
probe=test/zz_slide_heights_probe_test.dart

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

cp $here/slide_heights_probe_test.dart.txt $probe
# The probe tags its own lines with », so flutter's chatter is left out.
flutter test $probe --dart-define=IDS=$ids 2>&1 | sed -n 's/^» //p'
