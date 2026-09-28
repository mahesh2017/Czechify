---
name: lesson-no-scroll
description: "Use for any work on Czechify's no-scroll lessons, above all assessing a unit (after a content edit or for a new level) and fixing what it needs to fit a small phone. Also for changing a lesson exercise's layout, the lesson frame, answer feedback sheet, notebook step, Rule sheet or unit guide, SlideDeck, QuestionSteps, showsAsSlides, test/no_scroll_fit_test.dart or test/fixtures/no_scroll_budget.json. Load it before measuring, planning or writing code for any of these."
---

# No-scroll lessons

The rule (Mahesh, 24 Sep 2026): **a learner never scrolls to read or answer a
lesson step.** What doesn't fit a small phone is split into slides.

**Where it stands (28 Sep 2026):** all six steps are built and every unit
(1–31) is on slides. The per-unit switch (`unitGuidePilotUnits`) and the old
one-page layouts were removed on 28 Sep: a lesson exercise is on slides by its
type alone. New or edited content is assessed and fixed; there is nothing to
switch on. Exam lessons keep the full lesson frame. The full
record is `docs/NO_SCROLL_LESSONS_UNIT2_LEARNINGS_2026-09-24.md`: measurements,
recipes per exercise type, causes (§6), device-only bugs (§7).

## What the slides layout covers

Every lesson (outside exams) gets:
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
- Task briefs over 60 characters are reading text, not a heading (writing,
  speaking, and listening on slides since 26 Sep).
- Feedback lies over the exercise, folds down, Try again beside Continue, the
  grammar rule as a book icon.
- A picture-card step without pictures becomes the word-list style.
- The pre-lesson word list stays hidden (Mahesh, 27 Sep): lessons teach
  their own words on slides. The A1 vocabulary was rebuilt on 27 Sep; A2's was
  rebuilt on 28 Sep (`tool/vocabulary/rebuild_vocabulary.py a2`).
- The daily screen and onboarding are left for later. Flashcard review was
  made to fit on 27 Sep; `test/review_card_fit_test.dart` checks every card
  on each face.

Anything else that changes what a learner sees, gets as help, or is graded on
is Mahesh's call.

## 1. Assess (commit nothing)

1. **One command:** `.agents/skills/lesson-no-scroll/scripts/assess_unit.sh <unit…> --out <scratchpad>`
   from the repo root, outside the sandbox. It:
   - runs the dry run (what would still scroll, by kind, keyboard up too);
   - runs the lesson screen tests (feedback over the exercise, notebook
     comparison, Rule sheet, 200% text);
   - restores the budget file.

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
| Long reading text repeated above a 4-option question | Unit 29 | **built:** `reminderMaySplit` — the text gets its own slide before the question |
| Reading passage longer than the room under its heading and picture | A2 (Units 16–31) | **built:** `ScrollingPassage` — the text box scrolls, never the screen, with a visible scrollbar, fade and label (Mahesh, 28 Sep); min 140 pt, checked by the fit test |
| Many dialogue lines before one gap | 5 reply slides, e.g. 11310 | **built:** the reply slide keeps the line before the gap; earlier lines get their own slide |
| Dialogue reply slide under the keyboard (several lines) | 38 dialogues | **built:** while typing, only the gap's line and the one before |
| Dialogue gap with an English cue ("___ (I live in Prague.)") under the keyboard | 21 dialogues, e.g. 5404 | **built:** lines sit closer while typing |
| Dialogue with several gaps on one reply slide | check each unit | one gap per slide |
| Table taller than a slide (long rows, or the Rule sheet's smaller room) | all lectures | **built:** a row per block, measured by the deck |
| Matching counter ("0/6 matched") under the folded feedback bar | all matching | **built:** counter on the instruction's line, no bottom row |
| Notebook comparison too tall (long model or typed notes) | all notebook steps | **built:** packed blocks, one page when it fits |
| Picture cards without pictures (empty 268 pt box) | check each unit | whole step: word-list style; some items: **built**, they close the step as a word list |
| Alphabet grid | all alphabet steps | **built:** packed slides, a row of four per block |
| Long explanation on a right answer (sheet over 240 pt) | e.g. 1215 | shorten the content, flag for the teacher |
| Matching with six wrapping pairs (over the slide, or under the folded bar) | e.g. 6403 | **built:** tighter matching spacing in slide units |
| Template summary question whose right option is the whole passage in English | 24 reading steps, Units 4–10 | **done:** right option rewritten as a short gist; check later units for the template |
| Long listening brief (three heading lines) on the first slide | 59 listening steps, e.g. 7100 | **built:** reading text over 60 characters |
| Near-fits: long multiple-choice questions in the display face, fill-in letter bar | outside Units 1–7 | tighten spacing; `instruction:` reading text |

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

**Which steps are decks:** `showsAsSlides()` (`lib/presentation/widgets/lesson/exercise_slides.dart`)
decides by type (and a teaching step's style). `LessonExerciseViewport` uses
it to give a deck a bounded box instead of a scroll view; a new deck type
must be added there.

**Design against:**

| Measure | Size |
|---|---|
| Lesson exercise area (iPhone SE) | 375 × 557 pt |
| Room for one slide's content | about 454 pt |
| Keyboard with suggestion bar | 260 pt |

## 4. Verify
- **Tests that loop over units** use `courseUnits` (`test/support/course_units.dart`).
  A widget test of a deck hosts it in a bounded box (`SizedBox(height: 700)`
  or `LessonExerciseViewport`) and turns slides with `toLastSlide(tester)`
  (`test/support/slides.dart`), which pumps fixed frames rather than settling.
- **Re-pin the budget:** `UPDATE_NO_SCROLL_BUDGET=1 flutter test test/no_scroll_fit_test.dart`,
  then read `git diff test/fixtures/no_scroll_budget.json`:
  - only the unit's ids change;
  - every converted kind leaves the list;
  - whatever stays is on the plan.
- **Content changed?** Re-pin the content digest in
  `test/bundled_content_revision_test.dart`. Raise
  `ReleaseConfig.bundledContentRevision` once per release that changes
  content: 26 shipped in 1.1.5 (Play, 28 Sep 2026), so A2's changes are 27.
  Check with `git show <last release commit>:lib/core/config/release_config.dart`;
  an unraised revision never reaches learners who upgrade.
- **Break each new test on purpose once** and see it fail.
- **On the simulator** (bugs in §7 of the doc were only visible there):
  - one of each converted type, through to the feedback sheet;
  - typed answers with the keyboard up;
  - the Rule sheet and a notebook comparison.
- **Run the full suite:** only the referral manifest test may fail. Then
  commit.
- **Add what you learned to the doc and to the table above.**

## Content checks for every unit
`python3 scripts/content_scan.py <unit…>` runs the mechanical ones over many
units at once and prints every dialogue to read. Its hits are candidates:
read each. For many units, `scripts/feedback_heights.sh` takes every exercise
id at once; right-answer explanations over about 120 characters (A1's
longest is 128) overflow the 240 pt sheet.

- Uncued whole-line dialogue gaps whose answer carries facts the learner
  can't know ("Mám matematiku a fyziku.", "patnáct tisíc"): the standing
  English-cue fix. Counting accepted answers misses these.
- Expected answers that hard-code a name ("Jmenuji se Mahesh.").
- Dialogue answers that don't reply to the line before the gap (Unit 4 had
  all three wrong, Unit 5 three of four): print every dialogue's lines with
  its answers and read them.
- Dialogue gaps with no English cue but one accepted answer (all of Units
  11 and 12): add a cue in the "___ (I drink tea.)" style. Mahesh approved
  this for Units 11 and 12; it's the standing fix.
- Answers accepted in one gender only (*rád* but not *ráda*, *šel* but
  not *šla*): add the other form as an accepted answer (Mahesh, Unit 13).
- The Rule sheet: the assessment's lesson screen tests check its slides,
  which have less room than the lesson.
- Pronunciation focus sounds that are not in the sentence (2107 lists "ř").
- `image_cards` steps without `image` or `sentence` per item.
- Speaking tasks that pass on any one expected phrase.
- Alternatives shown as separate phrases to say ("Jmenuju se / Jmenuji se").
- The unit's words in `assets/vocabulary/` against the lesson word lists:
  match by stem, point entries at the first lesson using them, add missing
  word-list items (ids from the file's top), release the rest with the unit,
  keep at most 8 cards per lesson (contract test V8), never move a word to
  another unit except by a word list, and keep the file's format (indent 2,
  no escaping, no trailing newline).
- Template questions: "Which text best summarizes the situation?" with the
  passage's translation as the answer, and "directions" / "weather" as the
  wrong ones.
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
- **Content files aren't all formatted alike:** Units 1–10 round-trip with
  `json.dumps(indent=2)`, Unit 17 doesn't. Check before rewriting a file.
- **Never edit files containing non-ASCII text with `sed -i`:** it corrupted a
  test file. Use Python.
- **The fit test's budget keys** can be `<id>+keyboard`.
- **A content change can surface screens the dry run never measures:**
  Unit 1 is the smoke tests' unit, and it showed the start screen breaking at
  200% text. Run the full suite before calling a unit done.
- **A test that hosts a deck in its own `SingleChildScrollView`** can't lay
  it out. Host it in a bounded box (see Verify).
- **Tests of the old one-page layouts hid real bugs** (found 28 Sep when they
  moved to the decks: a 40 pt fold button, a restored writing draft reported
  as an edit, autoplay after a manual play). Test the layout learners see.
- **Fitting the screen isn't enough:** a step must also clear the folded
  answer bar (76 pt). The dry run can't see that; `feedback_overlay_test` can.
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
- **`slide_heights.sh` settles before measuring; the fit test measures the
  first frame.** A finding only the fit test shows is a first-frame layout
  (28201: the deck's placeholder button was shorter than the real one).
- **`slide_heights.sh` doesn't measure the keyboard state;** for a
  `+keyboard` finding, read the reply slide's lines from the content.
- **Scratch files** go in the session scratchpad; `$TMPDIR` differs inside and
  outside the sandbox.
