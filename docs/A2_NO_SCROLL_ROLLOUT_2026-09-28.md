# A2 on no-scroll lessons — 28 Sep 2026

All of A2 (Units 16–27, 29, 31) switched on in one pass, grouped by cause
instead of unit by unit. With it every course unit is on, and the no-scroll
budget (`test/fixtures/no_scroll_budget.json`) is empty: no lesson exercise
scrolls on an iPhone SE, with the keyboard up or down.

Content revision 26 shipped in 1.1.5 (Play, 28 Sep); these changes are
revision 27, so they reach learners who upgrade.

## How it was measured

| Step | Tool | Result |
|---|---|---|
| Scrolling today / with A1's slides | `assess_unit.sh` (all 14 units) | 283 → 34, 1 more with the keyboard |
| Feedback sheet over every exercise | `feedback_heights.sh` (all 520 ids) | 107 right-answer sheets over 240 pt |
| Content checks | `content_scan.py` (new) | below |
| Causes | `slide_heights.sh` | table below |

The first assessment's screen test printed only 23 of the 107 oversized
sheets (its list is truncated). Measure every id with
`feedback_heights.sh` before planning.

## Causes and fixes

| Cause | Items | Fix |
|---|---|---|
| Right-answer explanation long (A2 up to 398 chars; A1's longest 128) | 107 | Shortened to A1 length (≤ ~115 chars), same rule and example |
| Reading's first slide: prompt + 140 pt picture + passage | 11, 17–49 pt | The passage card takes the room left on the slide and scrolls inside (`ScrollingPassage`, below) |
| Review readings (Unit 29): passage repeated above four long options | 5, 130–212 pt | `reminderMaySplit`: the passage gets its own slide before the question when both do not fit |
| A passage alone taller than a slide (29103, a job ad) | 1 | Scrolls inside its card (a first cut of one sentence was reverted) |
| Dialogue lines after the last gap all on the reply slide | 5; 31113 by 534 pt | One closing line stays; more get slides of ≤ 3 lines before Check |
| Unit 29 listening: Listen again + four long options | 6, 4 pt | Question card 14 pt above and below (was 16); reminder gap 6 |
| Fill-ins with three gaps (one-page) | 4, 25–62 pt | Fill-in spacing 14/10/14 (was 20/14/18); prompts shortened to one or two lines |
| Long prompts in the display face | 19133, 21309, 27216 | Shortened |
| Speaking briefs with 11–14 phrase chips (29206, 29207) | 2 | Czech brief shortened |
| New English cues under the keyboard | 3, 7 pt | Cues shortened to one line |

New `SlideDeck.packed` options: `breakBefore` (a block starts a slide),
`SlideDeckState.blocksOn(slide)`, and a `FillSlide` block, which gets a slide
of its own at the slide's exact height.

### Long passages scroll inside their box (Mahesh, 28 Sep)

A first build moved a passage that did not fit under its heading to the next
slide, which left Unit 29's headings alone on a slide (seen on the emulator).
Mahesh: "make that text box where text is scrollable so that entire screen
shouldn't scrolled … there should be clear indication that text box is
scrollable". `ScrollingPassage` does that: the heading, picture and passage
share the first slide; a longer text scrolls inside its card with a scrollbar
that stays visible, a fade over the last lines and a "Scroll the text for
more" label, all gone at the end. "Show in English" sits at the top of the
card. The fit test lets the box scroll but fails it below 140 pt (about five
lines); 25401 and 31202 needed a two-line heading for that. At very large text
sizes the slide itself scrolls instead.

## Content checks

`scripts/content_scan.py` runs the skill's checks over many units at once and
prints every dialogue to read. Calibration learned here:

- **Dialogue audio reads every reply**, so an uncued gap can be answered by
  listening (the listen-then-reproduce design). A1 kept 43 uncued gaps. The
  standing fix stays as approved: a cue only where a gap has no cue and one
  accepted answer. Cues are safe for audio: `TextNormalizer.forSpeech` drops
  anything in brackets.
- Counting accepted answers is not enough to find unguessable gaps; the scan
  lists every uncued whole-line gap to read.
- Gender: a task that names the speaker ("male speaker", "a man speaking")
  rightly accepts one gender; the scan skips those.

## Content changes (all listed with before/after in `curriculum-review/A2_CHANGES_2026-09-28.md`)

- 107 explanations shortened.
- English cues on gaps with no cue and one answer: 17407, 18104 (2), 18406,
  23312, 25405, 26403; and on the three dialogues that opened on a bare gap
  (24108, 25106, 26107).
- Both genders: "Chtěl/a bych …" was an accepted answer nobody can type
  (24108, 25106, 26107), now *Chtěl* and *Chtěla*; 31113 accepts
  *potřebovala*.
- Errors fixed:
  - 26107: "Jsou energie v ceně?" — "**Ano**, energie nejsou v ceně" → "Ne, …".
  - 16405: the market vendor turned into a barista mid-dialogue.
  - 27307: "My přišli na nádraží pěšky" lacks *jsme* → "Přišli jsme na nádraží pěšky."
  - 18216: *bratr → bratrem* has no fleeting -e-; 18213 gave *v obchodě* as an -u locative.
  - 31204: "Mohl/a bys" in a line read aloud → "Mohla bys".
  - 23106: focus sound *ě* is not in "Smím se zeptat?" → *í*.
  - 21212: "Adjecitives".
  - 25217: an internal reference "(GR-240)" in learner text.
- Review card 1397 (`a2_vocabulary.json`): "shop assistant / salesman" →
  "shop assistant". Switching A2 on puts its cards under
  `review_card_fit_test`; this one was 15 pt over on the answer side, the
  only one of 1,432.

## For the teacher

1. The 107 shortened explanations (change list): is each still right, and is
   nothing a learner needs lost? The full rule is one tap away (book icon).
2. The fixes above, especially 27307 (word order now includes *jsme*) and
   26107 (the landlord's reply).
3. 25401, 31202: headings shortened to two lines.
4. 29206, 29207: the Czech speaking briefs were shortened.
5. 23105 is in the unit on *smět* but accepts only *Můžu/Mohu*: add *Smím*?
6. 27106 teaches "Teď jdu tam pěšky"; "Teď tam jdu pěšky" is more natural.
7. 15 speaking tasks list "chtěl/a bych"-style phrases (17409, 19161,
   19176, 20310, 20406, 21407, 22309, 22406, 25407, 27312, 27406, 29305,
   31206, 31306, 31404) and 14 writing tasks list such key words. A phrase
   with "/" can never match speech, so the task passes on the others. Split
   into both forms? (Changes grading — Mahesh's call.)
8. 24213 "Jsem ____." gives no hint that the answer is *nemocný/nemocná*.
9. 29102 (seen on the emulator): "Hrála **se** tam česká kapela" should be
   "Hrála tam česká kapela"; "zůstal doma protože" needs a comma before
   *protože*.

## Left for later

- The one-page layouts of slide exercise types are now unreachable (every
  unit is on); tests keep them alive through unit 0 (`outsidePilotUnit`)
  until they are removed.
- A2 review vocabulary, A2 dictionary, A2 audio: steps 3–5 of the plan.
