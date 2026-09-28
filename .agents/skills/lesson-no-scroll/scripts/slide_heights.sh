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
probe=test/zz_slide_heights_probe_test.dart

trap 'rm -f $probe' EXIT


cp $here/slide_heights_probe_test.dart.txt $probe
# The probe tags its own lines with », so flutter's chatter is left out.
flutter test $probe --dart-define=IDS=$ids 2>&1 | sed -n 's/^» //p'
