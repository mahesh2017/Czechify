---
name: lesson-no-scroll
description: "Use for any work on Czechify's no-scroll lessons, above all rolling them out: switching another unit on (adding it to unitGuidePilotUnits), assessing a unit for it, or fixing what a unit needs to fit a small phone. Also for changing a lesson exercise's layout, the lesson frame, answer feedback sheet, notebook step, Rule sheet or unit guide, SlideDeck, QuestionSteps, showsAsSlides, test/no_scroll_fit_test.dart or test/fixtures/no_scroll_budget.json. Load it before measuring, planning or writing code for any of these."
---

# No-scroll lessons

The rule (Mahesh, 24 Sep 2026): **a learner never scrolls to read or answer a
lesson step.** What doesn't fit a small phone is split into slides.

**Where it stands (26 Sep 2026):** all six steps are built and on in Units
1–5.
Rolling out means adding units to `unitGuidePilotUnits`
(`lib/core/config/unit_guide_pilot.dart`), after assessing each one. The full
record is `docs/NO_SCROLL_LESSONS_UNIT2_LEARNINGS_2026-09-24.md`: measurements,
recipes per exercise type, causes (§6), device-only bugs (§7).

## What switching a unit on changes

One setting turns on all of this for the unit's lessons:
- the start screen and the slim lesson bar (step 0);
- slides for rules, word lists, listening, reading and dialogues (step 2);
- task-then-do slides for writing, speaking and pronunciation (step 3);
- answer feedback over the exercise, compact and foldable (step 4);
- notebook intro/compare screens, the Rule sheet list, the collapsed unit
  guide, and no pre-lesson word list (step 5).

Unit-independent fixes are already live everywhere: word chips, speaking skip,
focus sounds in words, "Reference answer" for skipped answers.

## Decisions already made (don't ask again)

Mahesh agreed these on 24–25 Sep 2026; apply them to every unit.
- Browsing screens scroll: home, course map, settings, stats, chat, legal,
  and the unit guide (it opens with every section closed).
- At large system text a slide may scroll; text is never shrunk.
- The start screen shows on every start and resume.
- Reading shows one language at a time; "Show in English" counts as support.
- Speaking has "Can't speak right now? Skip" (skipped, no heart lost).
- Writing feedback appears once, in the feedback sheet.
- Task briefs over 60 characters are reading text, not a heading.
- Feedback lies over the exercise, folds down, Try again beside Continue, the
  grammar rule as a book icon.
- A picture-card step without pictures becomes the word-list style.
- The pre-lesson word list stays hidden until `assets/vocabulary/` matches
  v1.2.
- Flashcard review, the daily screen and onboarding are left for later.

Anything else that changes what a learner sees, gets as help, or is graded on
is Mahesh's call.

## 1. Assess (commit nothing)

1. **One command:** `.agents/skills/lesson-no-scroll/scripts/assess_unit.sh <unit…> --out <scratchpad>`
   from the repo root, outside the sandbox. It switches the units on
   temporarily, then:
   - runs the dry run (what would still scroll, by kind, keyboard up too);
   - runs the pilot screen tests with the units on (feedback over the
     exercise, notebook comparison, Rule sheet, 200% text);
   - restores the files.

   Every line it prints is a finding. If the budget file has uncommitted
   changes it refuses; stash them first.
2. **Find each cause as parts, not a number:**
   - `scripts/slide_heights.sh <id,…>` gives each overflowing slide's parts,
     or a one-page layout's.
   - `scripts/feedback_heights.sh <id,…>` gives the feedback sheet over an
     exercise.

   "96 pt prompt + 140 pt image + 130 pt listen panel" is a cause; "60 pt
   over" is not.
3. **Match causes to the table below.** A known cause has its fix; only new
   causes need designing.
4. **Read the unit's content** against the content checks below.
5. **Look at one lesson on the simulator** before changing it.

## 2. Plan
Write down, and show Mahesh before building:
- each finding, its cause and the fix (from the table where known);
- the content questions, for the teacher review;
- only the decisions that are genuinely new.

## Known causes and their fixes

| Cause | Where it shows | Fix |
|---|---|---|
| Listening first slide with an image (prompt + 140 pt image + listen panel + gist note + transcript) | all listening with a picture | **built:** the compact play row on that slide |
| Long reading text repeated above a 4-option question | Unit 29 | question first with "Show the text", or a text slide between questions |
| Many dialogue lines before one gap | e.g. 31113 | last 2–3 lines on the reply slide, earlier ones on their own slide |
| Dialogue reply slide under the keyboard (several lines) | 38 dialogues | **built:** while typing, only the gap's line and the one before |
| Dialogue gap with an English cue ("___ (I live in Prague.)") under the keyboard | 21 dialogues, e.g. 5404 | **built:** lines sit closer while typing |
| Dialogue with several gaps on one reply slide | check each unit | one gap per slide |
| Table taller than a slide (long rows, or the Rule sheet's smaller room) | all lectures | **built:** a row per block, measured by the deck |
| Matching counter ("0/6 matched") under the folded feedback bar | all matching | **built:** counter on the instruction's line, no bottom row |
| Notebook comparison too tall (long model or typed notes) | all notebook steps | **built:** packed blocks, one page when it fits |
| Picture cards without pictures (empty 268 pt box) | check each unit | whole step: word-list style; some items: **built**, they close the step as a word list |
| Alphabet grid | all alphabet steps | **built:** packed slides, a row of four per block |
| Long explanation on a right answer (sheet over 240 pt) | e.g. 1215 | shorten the content, flag for the teacher |
| Near-fits: long multiple-choice questions in the display face, fill-in letter bar | outside Units 1–3 | tighten spacing; `instruction:` reading text |

## 3. Build
Reuse these parts:

**Decks and slides** (`lib/presentation/widgets/common/slide_deck.dart`):
- `SlideDeck` with explicit `slides:` puts one thing on each slide.
- `SlideDeck.packed` fits blocks onto the fewest slides, spread evenly.
- `canAdvance` greys out Next until the slide is answered.
- `onDone: null` means the last slide has no button (a recording finishes the
  step).
- `finished: true` hides the deck's buttons once answered.
- `returnKeyAdvances` lets the keyboard take the buttons' room.
- `FillSlide` gives a page the remaining height.
- `KeyboardUpBuilder` tells whether the keyboard is up.
- `chromeOnlyWhenSeveral` (packed): no dots or buttons while it fits one
  slide, for a screen whose last block carries its own buttons.
- `gapBefore` (packed): a smaller gap between blocks that belong together,
  such as a table's rows.

**Exercises:**
- `QuestionSteps` (`exercises/question_steps.dart`): a passage or recording,
  then one question per slide.
- `QuestionPrompt(instruction: true)` sets long briefs as reading text.
- `AudioPairButtons(compact: true)`: play and speed on one row.

**Feedback sheet** (`FeedbackSheet` in `lesson_ui.dart`): `folded` /
`onToggleFolded`, `secondaryLabel` / `onSecondary`, `onTitleAction`.

**The on/off switch:** `showsAsSlides()` (`lib/presentation/widgets/lesson/slides_pilot.dart`)
is the one switch for exercise views. The view and `LessonExerciseViewport`
must both use it.

**Design against:**

| Measure | Size |
|---|---|
| Lesson exercise area (iPhone SE) | 375 × 557 pt |
| Room for one slide's content | about 454 pt |
| Keyboard with suggestion bar | 260 pt |

## 4. Verify
- **Switch the unit on** in `unitGuidePilotUnits`. The pilot tests pick it up
  by themselves (`test/support/pilot_units.dart`); tests of the old one-page
  layouts use `outsidePilotUnit`, so no test edits are needed. If a test
  breaks for any reason other than a real finding, fix the test to use
  `pilotUnits` / `outsidePilotUnit`, not a unit number.
- **Re-pin the budget:** `UPDATE_NO_SCROLL_BUDGET=1 flutter test test/no_scroll_fit_test.dart`,
  then read `git diff test/fixtures/no_scroll_budget.json`:
  - only the unit's ids change;
  - every converted kind leaves the list;
  - whatever stays is on the plan.
- **Content changed?** Re-pin the content digest in
  `test/bundled_content_revision_test.dart`; revision 26 has not shipped, so
  the number stays.
- **Break each new test on purpose once** and see it fail.
- **On the simulator** (bugs in §7 of the doc were only visible there):
  - one of each converted type, through to the feedback sheet;
  - typed answers with the keyboard up;
  - the Rule sheet and a notebook comparison.
- **Run the full suite:** only the referral manifest test may fail. Then
  commit.
- **Add what you learned to the doc and to the table above.**

## Content checks for every unit
- Expected answers that hard-code a name ("Jmenuji se Mahesh.").
- Dialogue answers that don't reply to the line before the gap (Unit 4 had
  all three wrong, Unit 5 three of four): print every dialogue's lines with
  its answers and read them.
- The Rule sheet: the assessment's pilot screen tests check its slides,
  which have less room than the lesson.
- Pronunciation focus sounds that are not in the sentence (2107 lists "ř").
- `image_cards` steps without `image` or `sentence` per item.
- Speaking tasks that pass on any one expected phrase.
- Alternatives shown as separate phrases to say ("Jmenuju se / Jmenuji se").
- The unit's words in `assets/vocabulary/` against the lesson word lists.
- Anything else for the teacher review.

Don't treat a teaching choice as a bug: dialogue audio plays the replies on
purpose (listen-then-reproduce). Ask.

## Never
- **Shrink text to fit** (`FittedBox`, a smaller font). Split it instead.
- **Change grading, hearts, XP or the help a learner gets** as a side effect of
  a layout change.
- **Make browsing screens into slides.**
- **Decide slides in one place only:** a deck inside the lesson's scroll view
  can't lay out.

## Traps we hit
- **Inside a `Scaffold` body, `MediaQuery.viewInsets` is always zero.** Use
  `KeyboardUpBuilder`.
- **The theme's buttons have an infinite minimum width.** In a `Row` they need
  `minimumSize: Size(0, h)`.
- **A `Container` with `alignment` fills its space.** Use
  `Align(widthFactor: 1)` to centre without stretching.
- **Measure the states the learner really sees:**
  - a first miss shows only the prompt;
  - the explanation comes after the third miss, the answer after the fourth;
  - typed notes must actually be typed.
- **Never edit files containing non-ASCII text with `sed -i`:** it corrupted a
  test file. Use Python.
- **The fit test's budget keys** can be `<id>+keyboard`.
- **Switching a unit on can surface screens the dry run never measures:**
  Unit 1 is the smoke tests' unit, and it showed the start screen breaking at
  200% text. Run the full suite before calling a unit done.
- **A test that hosts a step in its own `SingleChildScrollView`** breaks when
  the step becomes a deck. Host it in `LessonExerciseViewport`.
- **Don't estimate text heights with `TextPainter` to split content:** it got
  the wrapping wrong. Make each piece a block and let the deck measure.
- **Changing what the model shows while typing:** key the rows
  (`KeyedSubtree`), or the focused field is rebuilt and the keyboard drops.

## Practicalities
- **Flutter** must run outside the sandbox. Never `dart format` the repo.
- **Simulator build:**
  1. `flutter build ios --simulator --debug --config-only --dart-define=UNLOCK_ALL=true`
  2. The simulator tool's build of `ios/Runner.xcworkspace`, scheme `Runner`.
- **Content changes** need `xcrun simctl uninstall <device> com.eminentsite.czechify`
  before installing, to reseed. That starts at onboarding: skip it.
- **Taps:** wait for the app to settle; tap once per screenshot. Screenshots
  are about 2.29 px per point.
- **Screens in the way:**
  - on a new day the daily review screen comes first ("Go to Home");
  - the one-time notebook intro shifts the first notebook step.
- **A black screen after launch** is the simulator, not the app: relaunch with
  `xcrun simctl terminate`, then `xcrun simctl launch`.
- **Typing** is autocorrected by the simulator; use short words.
- **The iPhone SE simulator** exists (`iPhone SE (3rd generation)`), but Mahesh
  must grant access in the simulator panel.
- **`slide_heights.sh` doesn't measure the keyboard state;** for a
  `+keyboard` finding, read the reply slide's lines from the content.
- **Scratch files** go in the session scratchpad; `$TMPDIR` differs inside and
  outside the sandbox.
