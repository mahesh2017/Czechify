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
probe=test/zz_feedback_heights_probe_test.dart

trap 'rm -f $probe' EXIT


cp $here/feedback_heights_probe_test.dart.txt $probe
flutter test $probe --dart-define=IDS=$ids 2>&1 | sed -n 's/^» //p'
