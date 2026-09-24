# No-scroll lessons: what the Unit 2 pilot taught us

**Date:** 24 September 2026 · **Branch:** `curriculum/v1.2-plan` · **Commits:**
`3ba71abb` (step 0), `63ae05ef` (step 1), `bfc15b76` (step 2)

**Status:** Unit 2 is converted for steps 0–2. Steps 3–5 are still to do. Every
other unit still uses the old one-page layouts.

This is what we learned while building Unit 2. Read it before switching another
unit on or starting the next step. The numbers come from the no-scroll fit test
and from running the app in the iOS simulator.

---

## 1. The rule and the decisions behind it

- **A learner never scrolls to read or answer a lesson step.** Whatever does
  not fit one small-phone screen is split into slides (Mahesh, 24 Sep 2026).
- **Browsing screens keep scrolling.** Home, the course map, settings, stats,
  chat history and legal text are lists; splitting them into pages would be
  slower to use.
- **Large text wins over fitting.** When someone sets their phone to large
  text, a slide may scroll. A slide is never shrunk to fit (no `FittedBox`),
  because shrinking text defeats the point of splitting it.
- **The lesson start screen appears every time** a lesson is started or
  resumed.
- **The work is a pilot behind one switch.** It is Unit 2 only, via
  `unitGuidePilotUnits` in `lib/core/config/unit_guide_pilot.dart`.
  `showsAsSlides()` in `lib/presentation/widgets/lesson/slides_pilot.dart`
  decides which exercises become slides.

## 2. How we measure

| What | Value | Why it matters |
|---|---|---|
| Test device | iPhone SE, 375 × 667 pt | The smallest phone we design for. |
| Lesson exercise area | **375 × 557 pt**. That is 667 minus the status bar (20), the slim lesson bar (52) and a task row (38). | Everything in `test/no_scroll_fit_test.dart` is measured in this area. |
| Room for a slide's content | **454 pt**. That is 557 minus the dots (17), Back/Next (about 70) and 16 pt of padding. | Use this when planning a layout on paper. |
| Fonts | The app's own (Bricolage Grotesque and Schibsted Grotesk) must be loaded in the test. | Flutter's default test font is wider. With it, the audit counted 957 scrolling exercises; with the real fonts the count is 728. |

**The fit test** (`test/no_scroll_fit_test.dart`, about 20 seconds) renders all
1,548 shipped exercises and turns every slide. Exercises that still scroll are
listed in `test/fixtures/no_scroll_budget.json`, and **that list may only
shrink**. The test fails in three cases:
- an exercise that isn't on the list scrolls;
- one on the list now scrolls more than 40 pt further than recorded;
- one on the list now fits (take it off the list).

- **After a content or layout change, re-pin the list and read the diff:**
  `UPDATE_NO_SCROLL_BUDGET=1 flutter test test/no_scroll_fit_test.dart`.
  The diff is a detector. When we hid a speaker button in dialogues, 98
  dialogues in *other* units changed height. That is how we noticed the change
  reached beyond the pilot.
- **Break it on purpose once.** Setting 20 table rows per rule slide made the
  test fail on exactly three Unit 2 rules, with their ids. A test that has never
  failed has not been shown to work.
- **The test only sees an exercise's first state.** It does not see:
  - screens after an answer (the feedback sheet pushes the exercise up);
  - a revealed transcript or translation;
  - the keyboard.

  Those are checked on the simulator until step 4 adds them.

## 3. The lesson frame (step 0)

- In Mahesh's screenshot of the old frame, the first exercise started **about
  300 pt** below the status bar. It was pushed down by:
  - the lesson title;
  - an "Introduction" label and a question counter;
  - the device-voice banner;
  - the goal card.

  Moving those to a start screen and keeping one 48 pt bar (close, progress,
  hearts, a small cloud icon for the voice notice) brought that to **about
  108 pt**. Every later screen gains about 50 pt too.
- **A one-line label needs the whole row.** "CHECK · NO HEARTS" was cut to
  "NO HEAR…" next to the Rule button. The cause was that the label (`Flexible`)
  and a `Spacer` split the free space in half. Give the label `Expanded`, and
  put the buttons after it.

## 4. The slide deck (steps 1–2)

`SlideDeck` in `lib/presentation/widgets/common/slide_deck.dart` is the one
component for this. It works in two ways:

- **Explicit slides** (`SlideDeck(slides: …)`): the screen decides what goes on
  each slide. We use it for one question per slide and one dialogue reply per
  slide.
- **Packed slides** (`SlideDeck.packed(blockCount:, blockBuilder:)`): the
  content is split into blocks. The deck measures each block at the phone's real
  width and text size, then places the blocks on **as few slides as they fit,
  spread evenly**. We use it for rules and word lists.

What we learned building it:

1. **Fewest slides first, then even them out.** Filling each slide to the brim
   left a single phrase alone on the last slide of the word list, which looked
   unfinished. The deck now finds the fewest slides and then evens them out:
   five blocks become 3 + 2, not 4 + 1.
2. **Keep every slide the same height.** The dots row keeps its height even when
   there is only one slide. Otherwise the slide area would change height after
   packing, and packing would run again in a loop.
3. **A block taller than a slide gets a slide to itself** and scrolls. It must
   never push its neighbours past the bottom; there is a test for this.
4. **A block can adapt to its position.** `blockBuilder` is told whether the
   block starts its slide. A rule table drops its repeated heading when it sits
   under the explanation.
5. **Next can wait.** `canAdvance` keeps Next greyed out until the question on
   that slide is answered. On the last slide it keeps "Check answers" greyed out
   until every question is answered.
6. **A finished deck drops its buttons.** After an answer is checked
   (`onDone: null`), Back and Next go. Then the lesson's own Continue is the
   only way forward, and there is room for the feedback sheet. Swiping still
   reviews the answers. (A lone Back button between the question and the
   feedback sheet looked broken on the phone.)
7. **One switch, used in two places.** A deck needs a bounded height. A deck
   inside the lesson's usual scroll view cannot lay out at all. So the exercise
   view and `LessonExerciseViewport` both ask `showsAsSlides()`. Never decide
   this in one place only.
8. **Reduced motion:** slides turn instantly (`jumpToPage`). The dots are read
   out to screen readers as "Slide 2 of 4".

## 5. Recipes by exercise type

The sizes are what the fit test measured on the iPhone SE area (454 pt of room
per slide).

### Listening (`QuestionSteps` in `exercises/question_steps.dart`)
- **Slide 1** keeps the old header:
  - prompt, image (140 pt), listen panel (130 pt);
  - a "listen for the gist" note (38 pt);
  - the transcript button (54 pt).
- **Then one question per slide**, under a compact "Play it again · Slower" row
  (48 pt).
- Grading is unchanged: one result for the whole exercise. A replay on a
  question slide is still recorded as replay support.

### Reading (the same component)
- **Slide 1:** the passage in **one language at a time**. "Show in English"
  swaps the text on the card and is recorded as translation support. Showing
  Czech and English together made the card 417 pt tall.
- **Question slides** repeat the Czech text in a compact box: 14 pt text, line
  height 1.4, 10/14 pt padding.
- **The "Question 1" label is gone.** The dots show position. Dropping the label
  was part of making Unit 2's longest reading fit: the text box (156 pt) plus the
  question card (326 pt) came to 494 pt in 454 pt of room, and the smaller text
  box made up the rest.

### Dialogues (`exercises/dialogue_view.dart`)
- **Slide 1:** the prompt, the situation and the Listen button.
- **Then one reply per slide.** Each reply slide shows the lines since the
  previous gap. Lines after the last gap are added to the last slide.
- **The field is focused when its slide arrives.** Request focus *after* the
  frame is built, because the next slide's field doesn't exist yet when the page
  starts turning.
- **Return moves to the next reply**, or checks the answers after the last one.
  Set the field's `onEditingComplete` to do nothing on slides. Otherwise
  Flutter's default "focus the next field" runs alongside our slide turn. On the
  iPhone that skipped a reply or closed the keyboard. **The widget tests did not
  catch this; only the simulator did.**
- A short reply slide fits above the keyboard.

### Word lists (the teaching `list` style)
- **Packed blocks:** the teacher intro, then the hero card with "play all",
  then one block per phrase. The "Tap a line to hear it" label belongs to the
  first phrase's block.
- **"Play all" turns the deck** to the slide of the phrase being spoken
  (`SlideDeckState.showBlock`).

### Rules (lectures)
- **Packed blocks** (explanation → table 5 rows at a time → examples →
  common mistake).
- **Tables stay whole where they can.** A 5-row table (about 360 pt) doesn't fit
  under an explanation (about 270 pt), so the first slide keeps some empty space.
  We accepted that rather than split a table across two screens.
- **Five rows is not always one screen:** see §6. The chunk size should be based
  on height, not a row count.

## 6. What happens when every unit is switched on

Measured on 24 Sep by temporarily listing all 31 units in the pilot. Nothing
was committed.

| Exercise kind | In the course | Scroll today | Scroll with slides everywhere |
|---|---|---|---|
| Listening | 138 | 133 | **34** |
| Reading | 98 | 96 | **20** |
| Dialogue | 103 | 98 | **7** |
| Rule (lecture) | 110 | 106 | **3** |
| Word list | 71 | 70 | **1** |
| Writing | 79 | 79 | 79 (step 3) |
| Pronunciation | 68 | 68 | 68 (step 3) |
| Speaking | 55 | 46 | 46 (step 3) |
| Everything else | 826 | 19 | 19 (step 4) |
| **Total** | **1,548** | **715** | **277** |

The step-2 recipes carry over well. **438 of the 503 scrolling steps of those
five kinds would fit.** The 65 left over fail in four known ways, each needing
a fix *before* those units are switched on:

1. **Listening with an image** (34, overflowing by 60–92 pt). The first slide
   holds a 96–128 pt prompt, the 140 pt image, the 130 pt listen panel, the gist
   note and the transcript button. Possible fixes:
   - a smaller image (about 100 pt);
   - the gist note folded into the prompt;
   - pack the first slide instead of fixing its contents.

   Units 4, 7 and 9 (for example 4100, 7100, 9100).
2. **Long reading texts** (20, mostly Unit 29, 22–216 pt over). The repeated
   text alone is 240–260 pt, and the question has 4 options (378–400 pt). Such
   texts need a different reminder, such as:
   - the question first, with "Show the text" opening it on the same slide;
   - or a text slide between questions.
3. **Dialogues with many lines before a gap** (7, up to 534 pt over). 31113 has
   8 lines before its only gap. Show the last two or three lines on the reply
   slide and put the earlier ones on a slide of their own (or pack them).
4. **Tall table rows** (3 rules, 24–48 pt over: 7301, 24301, 26301). Five rows
   of long text are taller than a slide. Chunk tables by measured height (pack
   rows individually inside one table card) instead of by five rows.

## 7. Found only by running the app

In each case the unit tests were green:
- **The dialogue double turn.** Return skipped a reply or closed the keyboard
  (see §5).
- **The cut-off "NO HEAR…" label** (see §3).
- **A single phrase alone on the last slide** of the word list, on the larger
  phone (see §4).
- **The lone Back button** between a checked question and the feedback sheet
  (see §4).
- **Tables that read out English** (found earlier on the simulator): a rule
  table speaks its right-hand cell, so Czech goes on the right.

Run each converted type on the simulator at least once per unit, through to
the feedback sheet, with the keyboard for typed answers.

## 8. Don't change teaching decisions quietly

- **Dialogue audio plays the replies.** The Listen button and each line's
  speaker play the correct answers. That looked like a leak, and I hid the
  per-line speaker. Then it turned out the mission's expected reply is "Jmenuji
  se Mahesh.", so these are listen-then-reproduce exercises. I reverted the
  change. **Ask before changing what support a learner gets.**
- **The reading translation** moved behind "Show in English" and now counts as
  support. That is a teaching choice; it went to Mahesh for a decision.
- **Grading is untouched.** Slides changed how a step is shown, never what
  counts as right, the hearts, or XP. Keep it that way.

## 9. Content and product issues noticed along the way (not fixed)

- **2405 (Unit 2 mission dialogue) expects "Jmenuji se Mahesh."** A learner who
  types their own name is marked wrong. This is for the teacher review, and
  other units may hard-code names the same way.
- **A lesson resumed while its feedback sheet was showing** shows the sheet over
  a fresh, unanswered exercise. This predates the pilot.
- **"No pen right now" on a notebook step** shows a message that covers the
  Next button for a few seconds.
- **Two screens still scroll and still use the old tall header:** the new-words
  list before a lesson (the teach phase), and the Rule sheet. Both are step 5.

## 10. Checklist for switching on another unit

1. **Add the unit** to `unitGuidePilotUnits`.
2. **Run the fit test with re-pinning.** In the budget diff:
   - only that unit's ids should change;
   - every step-2 kind should leave the list.

   Look up any that remain in §6.
3. **Fix what §6 predicts for that unit** (image listening, long readings, long
   dialogues, tall tables) before calling it done.
4. **Run the unit's lessons on the simulator:**
   - one rule, one word list, one listening, one reading and one dialogue;
   - each through to the feedback sheet;
   - dialogues with the keyboard;
   - check that "play all" follows along.
5. **Check the content** for the §9 problems: hard-coded names, and answers the
   audio gives away when the exercise isn't meant to be listen-then-reproduce.
6. **Run the full test suite, then commit.** The only known failure is the
   referral campaign manifest test, which is pending its re-pin.

## 11. Working notes

- **Simulator taps need a settled screen.** Taps sent while the app is still
  launching go through to Home (they opened the Pronunciation Lab twice). Tap
  once, wait about a second, take a screenshot.
- **Coordinates:** screenshots are about 2.29 px per point on the iPhone 17 Pro.
  The keyboard's Return key is at about (348, 772) pt.
- **Simulated typing is autocorrected:** "Jmenuji se Mahesh" was typed in as
  "Menuhin se mahe…". Test with short words.
- **Temporary folders differ:** `$TMPDIR` inside the sandbox is not the same
  folder as outside it. Keep scratch files in the session scratchpad.
- **To see which part of a slide overflows,** write a throwaway widget test
  that turns each slide and prints the heights of the slide's children. This
  was used for §5 and §6; it isn't kept in the repo.
