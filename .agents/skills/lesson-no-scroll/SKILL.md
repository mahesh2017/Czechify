---
name: lesson-no-scroll
description: "Use for any work on Czechify's no-scroll lessons: converting a unit's lessons to slides or adding a unit to unitGuidePilotUnits; starting the next no-scroll step (writing/speaking/pronunciation split into brief then doing, tightening near-fits, answer feedback as an overlay, the new-words list, notebook step, unit guide or Rule sheet as slides); or changing a lesson exercise's layout, SlideDeck, QuestionSteps, showsAsSlides, test/no_scroll_fit_test.dart or test/fixtures/no_scroll_budget.json. Load it before measuring, planning or writing code for any of these."
---

# No-scroll lessons

The rule (Mahesh, 24 Sep 2026): **a learner never scrolls to read or answer a
lesson step.** What doesn't fit a small phone is split into slides.

The full record is `docs/NO_SCROLL_LESSONS_UNIT2_LEARNINGS_2026-09-24.md`. It
holds the measurements, the recipe for each exercise type, the known failure
causes (§6), and the bugs that only showed on a phone. Read the sections this
task touches before planning.

## Work in this order: assess, plan, build, verify

Never start with code. Mahesh asked for this explicitly, and on Unit 2 skipping
it cost a revert.

### 1. Assess (commit nothing)
- **Trial run:** run `scripts/dry_run.sh <unit…>` from the repo root. It
  switches the units on temporarily, measures every exercise on the iPhone SE
  area, prints what would still scroll, and restores the files.
- **Find the cause of each overflow:** run `scripts/slide_heights.sh <id,id,…>`.
  It prints each overflowing slide and the heights of its parts. Write each
  cause down as parts, not a number. Good: "96 pt prompt + 140 pt image + 130 pt
  listen panel on slide 1". Not a cause: "60 pt over".
- **Group by cause and match each cause to the doc's §6.** If a cause isn't
  there, it's new; describe it.
- **Read the content itself.** Look for:
  - hard-coded names in expected answers;
  - audio that plays the answer;
  - unusually long texts;
  - anything the teacher should review.
- **Look at the current layout on the simulator once.**

### 2. Plan
Write down:
- each cause and its fix, and what's new to build;
- the content questions;
- **the decisions that are Mahesh's:** anything that changes what the learner
  sees, gets as help, or is graded on.

Show him the plan and wait for agreement before building.

### 3. Build
Use the existing parts; don't make new ones:
- **`SlideDeck`** (`lib/presentation/widgets/common/slide_deck.dart`).
  Explicit `slides:` when each slide asks one thing; `SlideDeck.packed` for
  content to fit onto as few slides as possible. `canAdvance` keeps Next greyed
  out until the slide is answered; `onDone: null` once the deck is finished.
- **`QuestionSteps`** (`exercises/question_steps.dart`): a passage or recording
  followed by one question per slide.
- **`showsAsSlides()`** (`lib/presentation/widgets/lesson/slides_pilot.dart`)
  is the one on/off setting. The exercise view and `LessonExerciseViewport`
  must both use it.

The measure to design against:

| Measure | Size |
|---|---|
| Lesson exercise area | 375 × 557 pt |
| Room for one slide's content | about 454 pt |

### 4. Verify
- **Re-pin the budget:** `UPDATE_NO_SCROLL_BUDGET=1 flutter test test/no_scroll_fit_test.dart`,
  then read `git diff test/fixtures/no_scroll_budget.json`:
  - only the intended ids change;
  - every exercise of an already converted kind leaves the list;
  - whatever stays is on the plan.

  Changes in other units mean the change reached further than intended.
- **Break each new test on purpose once** and see it fail.
- **Run it on the iOS simulator:**
  - each converted type once, through to the feedback sheet;
  - typed answers with the keyboard up.

  Several bugs in this work were only visible there.
- **Run the full suite** (the referral manifest test is a known failure), then
  commit.
- **Add what you learned to the doc.**

## Never
- **Shrink text to fit** (`FittedBox`, a smaller font to squeeze content in).
  Split it instead. Only at large system text sizes may a slide scroll.
- **Change grading, hearts, XP, or the help a learner gets** as a side effect
  of a layout change.
- **Assume something is a bug in the teaching design.** Dialogue audio plays the
  replies on purpose: the exercises are listen-then-reproduce. Ask Mahesh.
- **Make browsing screens into slides.** Home, the course map, settings, stats,
  chat and legal text keep scrolling.
- **Decide slides in one place only.** A deck inside the lesson's scroll view
  can't lay out.

## Practicalities
- Flutter must run outside the sandbox, and never `dart format` the repo. See
  the flutter-toolchain-quirks memory.
- **The simulator:**
  1. Build: `flutter build ios --simulator --debug --config-only --dart-define=UNLOCK_ALL=true`,
     then the simulator tool's build of `ios/Runner.xcworkspace`, scheme
     `Runner`.
  2. After launch, wait for the app to settle before tapping, and tap once per
     screenshot. Early taps land on Home.
  3. Screenshots are about 2.29 px per point.
  4. Test typing with short words: the simulator autocorrects.
- **Keep scratch files in the session scratchpad.** `$TMPDIR` is a different
  folder inside and outside the sandbox.
