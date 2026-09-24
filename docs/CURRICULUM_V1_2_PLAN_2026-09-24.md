# Czechify Version 1.2 — Teach-First Lessons, Paper Notebook and A1/A2 Scope Plan

**Prepared:** 2026-09-24
**Scope:** all 31 units (A1 Units 1–15, 28, 30; A2 Units 16–27, 29, 31)
**Status:** Plan approved in principle. Nothing implemented yet.
**Builds on:** `V1_1_PEDAGOGICAL_UPGRADE_PLAN.md` (four-lesson unit: A Scene and
meaning → B Pattern and sound → C Guided use → D Mission). This plan keeps that
architecture and adds what v1.1 left implicit: an actual lecture, a guided-practice
stage, a paper notebook, and a scope correction against the official Czech
standard.

**Decisions taken (24 Sep 2026):**

1. Guided-practice, check and predict items **cost no hearts**. Scored exercises and
   their "Try again" retries still cost hearts exactly as today.
2. Notebook prompts are **strong but never block** a lesson. "No pen right now"
   defers the step to a Notebook to-do list.
3. Notes are **on paper by default**, with a **typed fallback** in the app (for no
   paper at hand, or for learners who cannot write by hand).

---

## 1. Why this plan exists

Two independent problems, found in the 24 Sep 2026 review.

### 1.1 The curriculum doesn't match the Czech standard: too much in places, missing pieces in others

The standard is the *Referenční popis češtiny pro účely zkoušky z českého jazyka pro
trvalý pobyt v ČR – úrovně A1, A2* (NÚV 2016). The 2026 candidate handbook confirms
it still governs the exam after the 11 April 2026 format change. The official A2
course syllabus (NPI 2021) sets the teaching order. A1 is broadly within scope, with
gaps. A2 goes beyond the standard in some areas and lacks required material in others:

| Area | App today | Official scope |
|---|---|---|
| A2 U20 `kdyby` | ~40 uses, drilled | Not present anywhere in the reference description |
| A2 U20 productive conditional | ~100 `bych/bys` forms | Passive only, optional; active only *chtěl/a bych*, *mohl/a bych* (+ polite *Nemohl byste…?*) |
| A2 U22 `aby` | ~50 uses, full `abych/abys/abychom` drill | Listed as an A2 word plus one fixed phrase (*dovolte, abych vám představil/a*); no purpose-clause system |
| A2 U27 aspect | Systematic prefix rules, "předpona u-" etc. as vocabulary | Perfective forms "only for frequent verbs". Directional prefixes on **motion** verbs are in scope |
| A2 U18 instrumental plural | Rule card, 2 exercises | Plural at A2 = nominative, accusative, genitive only |
| A2 vocabulary | ~18% of words absent from the entire official document, clustered in U22 connectives, U24 medical, U25 university, U17 emotions, U27 grammar terms | — |
| A1 vocative | 1 use in the whole A1 course, no rule | Active A1 requirement (*pane doktore* is an A1 phrase); vocative sg. also in the A2 minimum |
| A1 modal verbs | *moct/muset* 0 uses in A1 lessons | "Basic modal verbs" are assumed before the A2 course |
| A1 personal pronouns, dative/accusative (*mě, mi, tě, ti, ho, mu, ji*…) | Only subject forms (U7) and the fixed *bolí mě* (U24) | Active at **A1**; all cases at A2 |
| A2 nominative/accusative **plural** (nouns and adjectives) | No rule; only the genitive plural (U16) | Active A2 requirement (syllabus blocks 4 and 12) |
| A2 ordinal numbers and dates (*prvního května*) | No rule; 0 uses in lessons | A2 (syllabus block 8) |
| A2 imperative as grammar (*Počkej! Nečekej!*) | Chunks only (U14 directions), no rule | Positive and negative forms, A2 (syllabus block 9) |
| A2 signs and reflexive passive (*zavřeno, vyprodáno, zavírá se v 21 h*) | Not in lessons | Recognition at A2 |
| Everyday vocabulary | App ~1,450 words | Official list ~3,080 entries; the app covers at most ~67% of official A1 and ~36% of official A2 single words (stem match, upper bound) |

### 1.2 Lessons test before they teach, and nothing asks for notes

Measured across all 124 lesson files and the lesson player:

- **The teaching card is a list, not a lecture.** 112 of 124 lessons open with an
  unscored `teaching` card, but its explanation is a median of **13 words** (max 70),
  plus a phrase list with audio. 12 lessons (mostly lesson 1 of Units 17–27, which is
  v1.1's *Pattern* lesson) have no teaching card at all.
- **Vocabulary flashcards** open 50 of 124 lessons, with a median of **27 cards**
  shown in one run, well above v1.1's 10–14 new items per unit.
- **Rules are explained in answer feedback.** 575 scored items carry a ~19-word
  explanation shown only after answering. In U20 the core rule ("*napíšu* = I *will*
  write") first appears in the feedback to question 2.
- **The real explanations are hidden.** `grammar_rules.json` has ~110 write-ups
  (median 71 words). None of the 115 teaching cards links to one. Learners reach a
  rule only through "View grammar rule" after a **wrong** answer, or from the unit
  list.
- **Every non-teaching item is scored and costs a heart.** There is no practice stage.
- **Notes:** no lesson asks for notes. The "Write it down" tip is in `LearningTipCard`,
  which is used on no screen (only a test imports it). The Daily copybook (Home) is
  handwriting practice, not tied to what was just taught.

v1.1 already required that "a graded task may not silently depend on unexplained
grammar". Nothing enforces it. This plan adds that enforcement.

---

## 2. Principles

1. **Teach one small step at a time, then check it straight away.** A short
   explanation, examples, and one instant check, repeated in two or three steps. Not
   one long lecture.
2. **Show before asking for production.** Worked examples first, then guided items
   with support, then scored items without support.
3. **Write notes from memory, not by copying.** Evidence that handwriting alone
   helps is mixed. What reliably helps is retrieving the material and putting it in
   your own words, then checking against a model. Every notebook step follows the
   pattern *close → write → reveal → self-correct*.
4. **Each lesson has a different job.** Lessons A–D in a unit are not four copies of
   one template.
5. **One source for each piece of text.** Lecture steps live in the grammar rule. The
   model notebook page lives in the cheat sheet. The Grammar screen, lecture cards,
   feedback link and notebook all read the same text.
6. **Lesson time stays about 12–14 minutes.** Adding teaching means trimming scored
   items, not making lessons longer.

---

## 3. The unit, lesson by lesson

Standard units (1–27) keep v1.1's A–D roles, mapped from `order_in_unit` (0→A,
1→B, 2→C, 3→D). Units 28–31 are covered in §3.5.

### 3.1 Lesson A — Scene and meaning (~12 min)

1. **Predict** (1 item, `mode: predict`): hear or read the scene, guess the gist.
   Unscored. The answer is revealed with a one-line explanation.
2. **Scene:** the existing dialogue or listening item.
3. **Chunk lecture** (1–2 `teaching` cards): the 8–12 new words and chunks with
   audio, **split into sets of ≤ 8**. This replaces the current 27-card flashcard run.
4. **Notebook: capture** (see §4). Unit page header plus the "Words & chunks" box,
   written from memory, then checked.
5. **Scored:** 6–7 items on meaning and recognition.

### 3.2 Lesson B — Pattern and sound (~14 min). This is the new lecture.

1. **Notes recall** (notebook, `kind: recall`): "Without looking, write 4 chunks from
   Lesson A." Then reveal and self-mark.
2. **Pattern lecture: 2–3 steps.** Each step is one `teaching` card with
   `style: lecture` that references a grammar rule step (§5.2):
   - what it means (1–2 sentences, plain English);
   - a small form table (only the forms in scope);
   - 2–3 examples with audio;
   - one "common mistake" line.

   Each step is followed immediately by **one check item** (`mode: check`, unscored).
3. **Notebook: capture.** The "Pattern" box: rule in the learner's own words, the
   table from memory, then reveal the model and fix.
4. **Guided practice** (3–4 items, `mode: guided`): worked example first, hint visible
   from the start, no hearts, immediate explanation. Recorded as *supported* evidence.
5. **Perception → pronunciation** (existing v1.1 requirement).
6. **Scored:** 5–6 items.

### 3.3 Lesson C — Guided use (~12 min)

1. **Notes recall:** the Pattern table from memory, reveal, self-mark.
2. **Spaced recall** of the previous unit's page: one line from memory.
3. **Notebook: My sentences.** Write 2 true sentences about yourself using the unit
   pattern. The app shows 2 model sentences after the learner writes. This is also
   rehearsal for the exam's speaking part (answering questions about yourself).
4. **Scored:** 8–9 items (listening, reading, cued production), as v1.1 describes.

### 3.4 Lesson D — Mission (~12 min)

1. Notebook closed. The **mission** (existing).
2. **Notebook: unit check** (`kind: unit_check`): compare your page with the model
   page (§4.4), fix gaps, then optionally share or save the model page as an image.
3. Delayed transfer continues as today.

### 3.5 Skills and review units (28, 29, 30, 31)

No new lecture. Each lesson opens with a **recall across units** notebook step ("write
the three case endings you use most"), and the review units end with an "exam page"
checklist. Their scored content is unchanged apart from the scope fixes.

### 3.6 Time budget (enforced by the content checker, §6)

| Lesson | Unscored stages | Scored items | Target |
|---|---|---|---|
| A | predict, chunk lecture, notebook | 6–7 | ≤ 13 min |
| B | recall, 2–3 lecture steps + checks, notebook, 3–4 guided | 5–6 | ≤ 15 min |
| C | recall ×2, My sentences | 8–9 | ≤ 13 min |
| D | mission, unit check | mission | ≤ 13 min |

---

## 4. The notebook system

### 4.1 Setup (once)

- A one-time **"Your Czech notebook"** card at the start of Unit 1 Lesson A (not in
  onboarding, which stays as decided on 14 Sep). It explains the habit in two lines
  and shows the page layout as a picture.
- Setting **Notes: Paper (default) / In the app** in Settings.
- Existing learners get the same card once, at the start of their next lesson.

### 4.2 The page layout (one page per unit)

```
┌ Unit 6 — Get What You Need ─────────── date ┐
│ I can: order one food and one drink politely │
├ Words & chunks ─────────────────────────────┤
│ Dám si kávu. — I'll have a coffee.           │
├ Pattern ────────────────────────────────────┤
│ Rule in my words: …                          │
│ káva → kávu   voda → vodu   čaj → čaj        │
├ My sentences ───────────────────────────────┤
│ 1. …                                          │
│ 2. …                                          │
└ Check ✓ (Lesson D) ──────────────────────────┘
```

Czech first, English after. Colour-coding for gender (ten/ta/to) is suggested but
optional.

### 4.3 The notebook step (every lesson)

1. **Instruction:** a specific task, for example "Write the three accusative endings
   from memory."
2. **Write:** on paper, or in the text box if Notes = In the app.
3. **Check:** reveals the model for that box.
4. **Self-mark:** *Got it* / *Fixed mistakes*. This is a self-report, stored as
   evidence with a `notebook` support tag. It is never scored and never costs hearts.
5. **No pen right now:** skips the step and adds it to **Notebook to-do**, a new
   section at the top of the Daily copybook. The lesson continues. The to-do list
   shows the exact box to write, with its model.

What it deliberately does **not** do:
- no "I've written it" gate;
- no photo upload of notes. It adds little value, and keeping learner handwriting off
  the server matches the project's EU-privacy rule.

### 4.4 The model page

- Generated from `cheat_sheets.json` (all 31 units already have one), extended with a
  `notebook_page` block matching the layout in §4.2.
- Shown in the Lesson D unit check and from a new **Lecture & notebook** entry on each
  unit in the curriculum list. That entry also lists the unit's lecture steps, for
  revision and for learners who completed the unit before v1.2.
- **Share/save as image** using the existing `share_plus` dependency (render the page
  to PNG). A printable PDF would need a new dependency, so it is deferred.

### 4.5 Reviving existing pieces

- `LearningTipCard` ("Write it down") gets a home: the setup card reuses its copy, and
  the unused widget is deleted.
- The Daily copybook remains, but it now shows today's Notebook to-do first, then the
  four daily words.

---

## 5. Content format

The main constraint is backward compatibility. The on-device checker
(`CurriculumContractValidator.validateSnapshot`, called from
`curriculum_pack_source.dart`) **rejects an entire content release** if any exercise
has a type the installed app doesn't know. Older installs would then silently stay on
old content for every unit, not just the changed ones. Behind it,
`ExerciseType.values.byName` (`exercise.dart:29`, `drift_curriculum_repository.dart:103`)
throws on unknown types. The same checker accepts extra fields inside `data` and
unknown teaching `style` values: a teaching card only needs a `heading` or `body`, and
list rows with `cz`. `teaching_view.dart` renders an unknown style as a list.
Therefore:

- **No new exercise types.** New stages are variants of existing types, controlled
  by fields inside `data`, which older clients ignore.
- **A minimum-app-version gate ships first** (§8, Phase 1). It is needed for all
  future content changes anyway.

### 5.1 Exercise mode

```json
{ "type": "multiple_choice", "data": { "mode": "check", ... } }
```

`mode` is one of `scored` (default when absent), `predict`, `check`, `guided`.

| mode | Hearts | XP | Mistake queue | Feedback | Evidence |
|---|---|---|---|---|---|
| scored | yes (unchanged) | yes | yes | graduated ladder (unchanged) | independent |
| guided | **no** | small | no | hint shown up front; explanation on first miss | supported |
| check | **no** | none | no | explanation always shown | check |
| predict | **no** | none | no | reveal + one line | not recorded as mastery |

An older client treats all modes as scored. That is acceptable, because it is
today's behaviour.

### 5.2 Lecture steps live in the grammar rule

```json
// grammar_rules.json (extended)
{
  "id": "GR-050",
  "rule_name": "Accusative case — feminine -a → -u",
  "lecture": [
    {
      "step": 1,
      "title": "What changes",
      "say": "When a feminine noun is the thing you want or see, -a becomes -u.",
      "table": [["káva", "kávu"], ["voda", "vodu"]],
      "examples": [{"cz": "Dám si kávu.", "en": "I'll have a coffee."}],
      "common_mistake": {"wrong": "Dám si káva.", "right": "Dám si kávu."}
    }
  ],
  ...
}
```

```json
// lesson file
{
  "type": "teaching",
  "data": {
    "style": "lecture",
    "grammar_rule_id": "GR-050",
    "step": 1,
    "heading": "What changes",
    "items": [{"cz": "Dám si kávu.", "en": "I'll have a coffee."}]
  }
}
```

A new client renders the rule's lecture step. An older client falls back to the
existing `list` layout using `heading` and `items`. The Grammar reference screen
renders the same `lecture` array.

### 5.3 Notebook step

```json
{
  "type": "teaching",
  "data": {
    "style": "notebook",
    "kind": "recall",                 // capture | recall | my_sentences | unit_check
    "box": "pattern",                 // words | pattern | my_sentences | page
    "instruction": "Without looking, write the three accusative endings.",
    "model_ref": {"unit_id": 6, "box": "pattern"},
    "heading": "Notebook",
    "items": [{"cz": "káva → kávu", "en": "feminine -a → -u"}]
  }
}
```

An older client shows it as an ordinary teaching card with the model as a list.

### 5.4 Cheat sheet extension

`cheat_sheets.json` → each unit gets
`notebook_page: { can_do, words: [...], pattern: {rule_plain, table, examples}, my_sentences_models: [...] }`,
written once, after the scope fixes in §7.

---

## 6. Content checker rules (`curriculum_contract_validator.dart`)

New checks. **E** = build error, **W** = warning.

| # | Rule | Level |
|---|---|---|
| V1 | Standard units have exactly 4 lessons; roles follow `order_in_unit` | E |
| V2 | Lesson B has 2–3 `style: lecture` cards, each followed by ≥ 1 `mode: check` item | E |
| V3 | **Taught before tested:** every scored item in lessons B–D carries a `grammar_rule_id` or `targets: "vocab"`; that rule has a lecture step earlier in the unit or in an earlier unit | E |
| V4 | Every Czech word form in a scored answer key has appeared earlier in the course (teaching, vocabulary or example); unexplained forms are listed | W (becomes E after the rollout) |
| V5 | Every lesson has exactly one notebook step of the kind its role requires (§3) and a resolvable `model_ref` | E |
| V6 | **Scope guard:** on the main path, A1/A2 lessons may not contain the out-of-scope list (`kdyby*`, `abych/abys/abychom/abyste`, *tudíž, avšak, ovšem, jakmile, co se týče…*) unless the lesson is marked `extension: true` | E |
| V7 | Time budget per lesson (§3.6), estimated per item type | W |
| V8 | ≤ 8 new vocabulary cards per teach set | E |
| V9 | `lecture` steps: 1 idea, `say` ≤ 40 words, table ≤ 8 rows, ≥ 2 examples with audio | E |
| V10 | **Required coverage:** every item in the §7.0 table for a level (as a list of concept keys) has at least one lecture step on that level's main path | E |

V3 would have caught the U20 problem automatically.

---

## 7. Scope changes (done before writing any lectures)

### 7.0 Level scope for anyone writing lectures

Every lecture step, model page and scored item must stay inside this table. Source:
reference description 2016, chapter 7, and the A2 syllabus 2021. "Active" means the
learner produces it. "Passive" means understanding it is enough.

| Area | A1 (active) | A2 (active) |
|---|---|---|
| Noun cases | Nom., acc., voc. sg.; loc. and gen. sg. **only after place prepositions** (*v Praze, z Prahy, do práce*); instr. sg. **only as means** (*tramvají*) | All singular cases; plural **nom., acc., gen. only** |
| Declension patterns | pán, muž, hrad, stroj; žena, růže, píseň; město, pole, stavení | + táta, soudce, vrátný, cestující; kost, vrátná; drobné |
| Adjectives | Nom., voc., acc. sg.; acc. pl.; irregular comparatives (*větší, lepší*) | All singular cases; plural nom., gen., acc.; regular comparison |
| Personal pronouns | Nominative, **dative, accusative** | All cases |
| Possessive/demonstrative pronouns | As adjectives, incl. *svůj* | As adjectives, without dat./loc./instr. plural |
| Verbs | Present tense (all regular types; *být, mít, chtít, jíst, jít, jet, vědět, vidět*); modals *chtít, mít, moct, muset, smět*; reflexive verbs; past-tense chunks (*narodil jsem se*) | Past and future; perfective forms **only for frequent verbs**; directional prefixes on **motion** verbs; imperative positive and negative |
| Conditional | *chtěl/a bych* as a chunk | Passive only (optional), active only *chtěl/a bych, mohl/a bych*, polite *Nemohl/a byste…?* |
| Passive | — | Recognition only: signs (*zavřeno, vyprodáno, zakázáno*) and reflexive passive (*zavírá se v 21 h*) |
| Numbers | Cardinals, time, prices | + ordinals (declined like adjectives), dates, *-krát* |
| Clauses | *a, ale, nebo, protože* | + *že, jestli, kdo/co/kde…, který, když, až, proto, dokonce*; *aby* only as a word and in *dovolte, abych…* |
| Not at A1/A2 | — | *kdyby*; purpose-clause system (*abych/abys…*); dative/locative/instrumental plural; systematic aspect derivation; written-register connectives (*tudíž, avšak, ovšem, jakmile*…) |

**A1 words the official list puts at A2** (~7% of app A1 vocabulary, e.g. *koníček,
budík, mlha, doleva*): keep them. They serve the unit topics and are only a level
early. They are exempt from the scope guard (V6), which checks grammar and the
out-of-scope word list, not every word's level.

"Extension" means an optional **Towards B1** lesson after the unit's D lesson. It is
not required for unit completion or progression, and it stays out of Daily Arrival.
It is scored normally.

### 7.1 A1

| Unit | Change |
|---|---|
| U2 | Add the vocative: chunks *pane Nováku, paní Nováková, pane doktore*, first names; plus a short rule for the common patterns (*-e/-i/-o/-u*) |
| U6, U8 | **Personal pronouns, accusative and dative** (required at A1): *Dejte mi…, Můžete mi pomoct?* (U6); *Znáš ho? Vidím ji. Mám ho rád.* (U8) |
| U6, U14 | Add modal chunks: *Můžete mi pomoct? Můžu platit kartou? Musím jít.* |
| U11 | Partitive genitive becomes chunks only (*kilo brambor, trochu mléka*); no transformation drills; rule card reworded as "useful phrases" |
| U15 | Past and future labelled **Preview**; scored items only on taught chunks (the official A1 list includes *narodil jsem se, co jste říkal?*) |
| All A1 | Add ~150 high-value official A1 words the app lacks (e.g. *propiska, poschodí, zpáteční, drobné, sourozenec*) as **recognition** vocabulary in reading and listening items, so v1.1's 10–14 active items per unit stay unchanged |

### 7.2 A2

| Unit | Change |
|---|---|
| U17 | *svěřit se, ublížit, odpustit, závidět, obávat se* move to extension |
| U18 | Instrumental plural: rule card becomes reference only; its 2 exercises are removed. Unit stays singular + *s rodiči / s přáteli* as chunks |
| U20 | Main path: future (*budu* + imperfective, perfective present), and the conditional only as *chtěl/a bych, mohl/a bych, rád/a bych, Nemohl/a byste…?* **`kdyby` moves to extension** |
| U22 | Main path: *že, protože, když, až, jestli, který, proto, ale, nebo, dokonce*. `aby` taught as a word plus 2 fixed phrases. The `abych/abys` drill and the written-register connectives move to extension |
| U24 | Technical medical words (*bakterie, sterilní, operační sál, krevní test, pulz*…) move to extension. Verify each against the official list in Phase 0 |
| U25 | University terms (*děkan, rektor, kredit, semestr, přezkoušení*) move to extension |
| U27 | Keep prefixed **motion** verbs (*od-, při-, v-, vy-, s-, pro-, pře-, ob-*). Replace systematic aspect-pair prefix rules with ~15 frequent pairs. Delete the "předpona X-" vocabulary items |
| All A2 | Add high-value official A2 words as recognition vocabulary, as in A1 |

### 7.3 Required A2 content the app lacks (added, not moved)

These go into existing units. Each lands in that unit's Lesson B lecture and in its
model page. No new units, so unit IDs and learner progress stay intact.

| Content | Where | Why there |
|---|---|---|
| **Nominative/accusative plural**, nouns and adjectives (inanimate and feminine/neuter first) | U16, a lecture step **before** the genitive plural | Shopping needs *boty, rohlíky, jablka*; the syllabus pairs it with food and shopping |
| Nominative/accusative plural of **animate masculines** (*učitelé, lékaři, studenti*) | U25 | Professions; syllabus block 12 pairs it with work |
| **Personal pronouns, all cases** (*se mnou, o něm, k nám*) | U17 (dative) and U18 (locative/instrumental), a step in each | Built on the A1 dative/accusative forms (§7.1) |
| **Ordinal numbers and dates** (*prvního května, v prvním patře*) | U20 (*Make plans*), with dates; floors revisited in U26 | Appointments and plans need dates; A2 syllabus block 8 |
| **Imperative as grammar**, positive and negative (*Počkej! Nečekej! Pojďte!*) | U23 (rules and permission) | The syllabus teaches it with modal verbs; U14's direction chunks become the examples |
| **Signs and reflexive passive** (*zavřeno, vyprodáno, zakázáno parkovat, zavírá se v 21 h*), recognition only | U23 reading items | Rules and notices; reading only, never produced |
| Adjectival nouns *vrátný, cestující* | U27 (journeys), recognition | In the A2 declension list |

**Net load:** these additions are smaller than the §7.2 removals (*kdyby*, the *aby*
drill, the systematic aspect rules, the instrumental plural, ~60–80 advanced words), so
A2 ends up shorter and closer to the standard, not longer.

### 7.4 Tooling for scope work

- A small script under `tool/` extracts the official word list from the NÚV PDF into
  `docs/sources/official_lexicon_a1_a2.csv`, and writes
  `docs/sources/app_vs_official_<date>.csv` (per unit: out-of-scope words, missing
  official words). The analysis from 24 Sep was done this way but not saved.
- The official PDFs (reference description 2016, syllabus 2021, candidate handbook
  2026) are stored in `docs/sources/` with their URLs.

---

## 8. Implementation phases

### Phase 0 — Scope and tooling (content only, no app release)

1. Save the sources and the word-list script (§7.4).
2. Produce the per-unit scope lists and verify every "move to extension" word against
   the official list.
3. Turn the §7.0 table into concept keys for V6 (forbidden) and V10 (required), and
   confirm the §7.3 placements unit by unit.
4. Write `notebook_page` for U6 and U19 (the pilot units).

### Phase 1 — Engine (one app release, no visible content change)

| Change | Where |
|---|---|
| Minimum-app-version on the content release manifest; older clients keep their current pack | `curriculum_pack_source.dart`, release manifest, Supabase content release |
| Defensive: an unknown exercise type is skipped with a logged warning instead of throwing (the version gate is the real protection) | `exercise.dart:29`, `drift_curriculum_repository.dart:103` |
| `mode` handling: hearts only for `scored` (the heart deduction in `onExerciseAnswered`), no XP / mistake queue for check and predict, hint up front for guided | `lesson_providers.dart`, `learning_loop_engine.dart` stays as is |
| Evidence tags for guided/check/notebook, so recommendations don't count them as independent success | `learning_evidence_events` writer |
| `style: lecture` rendering (title, say, table, examples, common mistake) reading the grammar rule | `teaching_view.dart` |
| `style: notebook` view: instruction, typed box (fallback mode), Check, self-mark, "No pen right now" | new `notebook_step_view.dart` |
| Notes setting (Paper / In the app) | `settings_providers.dart`, Settings screen |
| Notebook to-do (local, prefs, like the copybook) + copybook section | `copybook_providers.dart`, `copybook_screen.dart` |
| Split vocabulary teach sets to ≤ 8 cards | `lesson_providers.dart` teach phase |
| Unit "Lecture & notebook" entry + model page + share as image | `curriculum_screen.dart`, `quick_reference_screen.dart` |
| Checkpoint restore handles lessons whose exercise list changed after a content update | `_restoreCheckpoint` |
| Content checker rules V1–V10 (V4/V7 as warnings) | `curriculum_contract_validator.dart` |
| Delete the unused `LearningTipCard` | widget + its test |

**Tests:** hearts per mode (guided/check/predict never deduct; scored unchanged incl.
Try again); notebook step (paper, typed, defer → to-do); older-client fallback
rendering of `lecture` and `notebook` styles; validator rules with passing and
failing fixtures; checkpoint restore across a content change.

**Before calling Phase 1 done:** run the app on iOS and Android and complete a pilot
lesson end to end (a green test suite has shipped an unopenable screen before).

### Phase 2 — Pilot content: A1 U6 and A2 U19

These are grammar-heavy and representative. U1–U3 (sounds, greetings) are not.
Both units get the full A–D rework: lectures, checks, guided items, notebook steps,
model pages, trimmed scored items.

### Phase 3 — Measure (2–3 weeks with testers)

| Measure | Source | Success looks like |
|---|---|---|
| First-try accuracy on scored items, pilot units vs pre-v1.2 | `learning_evidence_events` (synced for signed-in testers), with the testers' consent | clearly higher |
| Median lesson time | lesson attempts | within §3.6 budget |
| Mid-lesson quit rate | lesson attempts | not worse than today |
| Notebook: done / deferred / skipped, and "Fixed mistakes" rate | notebook evidence | most steps done, not deferred |
| Delayed transfer success | `delayed_transfer_assignments` | higher |
| Interviews | 5–8 testers, including a learner who recently finished A1/A2 at Charles University | lectures clear, notebook used |

If first-try accuracy doesn't improve, or lessons run long, fix the template before
Phase 4.

### Phase 4 — Rollout

1. **A1** Units 1–15, then 28 and 30.
2. **A2** Units 16–27 (with the §7.2 scope changes), then 29 and 31.

Each batch: author → validator clean → Czech-teacher review of lecture and
model-page text → device run → content release.

**Rough authoring volume:** ~31 chunk lectures, ~70 pattern lecture steps with checks,
~100 guided items, 124 notebook steps, 31 model pages, plus the removals and
extension lessons from §7.

### Phase 5 — Independent review

A qualified teacher of Czech as a foreign language reviews all lecture steps and
model pages against the reference description, as `V1_1` already requires for
content to count as field-validated.

---

## 9. Acceptance criteria

**Per unit**

- Validator V1–V10 clean (V4 and V7 errors from Phase 4 onward).
- No main-path item outside the A1/A2 scope; extensions clearly optional.
- Lesson B lecture: 2–3 steps, each with a check, all forms taught before any scored use.
- Every lesson has its notebook step; the model page exists and matches the lectures.
- Lesson times within §3.6.
- Czech-teacher sign-off on lecture and model-page text.

**Across the course**

- Guided, check and predict items never cost hearts; scored behaviour unchanged.
- "No pen right now" never blocks; deferred steps appear in Notebook to-do.
- Typed fallback works with the screen reader.
- An older installed app keeps working when a v1.2 content release is published.

---

## 10. Risks

| Risk | Mitigation |
|---|---|
| Older clients reject a whole content release (and stay on old content everywhere) | No new exercise types; new stages are `data` fields and teaching styles the current checker already accepts; min-app-version gate shipped first (Phase 1) |
| Lessons get longer and completion drops | Time budget enforced (V7); scored items trimmed |
| Learners tap past notebook steps | Recall prompts, not copy prompts; measure done vs deferred in the pilot |
| Removing A2 content disappoints learners who want more | It moves to optional *Towards B1* lessons; nothing is deleted outright |
| Lecture text quality | Short, checked format (V9) + teacher review before release |
| Evidence inflated by supported items | Guided/check/notebook tagged separately in `learning_evidence_events` |

---

## 11. Sources

- NÚV (2016), *Referenční popis češtiny pro účely zkoušky z českého jazyka pro trvalý
  pobyt v ČR – úrovně A1, A2*, incl. *Soupis lexikálních jednotek* —
  https://cestina-pro-cizince.cz/trvaly-pobyt/a1/wp-content/uploads/sites/2/2020/03/referencni_popis_08122016.pdf
- NPI (2021), *Sylabus přípravného kurzu ke zkoušce A2 z češtiny pro trvalý pobyt* —
  https://cestina-pro-cizince.cz/trvaly-pobyt/wp-content/uploads/2021/12/11_NPI_Sylabus_sazba_WEB_300dpi.pdf
- NPI (2021), *Rámcové kurikulum pro přípravu ke zkoušce z českého jazyka pro trvalý
  pobyt* — https://cestina-pro-cizince.cz/trvaly-pobyt/a1/wp-content/uploads/sites/2/2021/02/NPI_Ramcove_kurikulum_kestazeni.pdf
- NPI (2026), *Příručka pro uchazeče* (new format from 11 April 2026) —
  https://cestina-pro-cizince.cz/trvaly-pobyt/wp-content/uploads/2026/03/Prirucka_pro_uchazece_2026.pdf
- Charles University (2026), *CCE-A1 modelová varianta* —
  https://arche.is.cuni.cz/images/zkousky/dokumenty/CCE-A1_MODELOV%C3%81_VARIANTA_2026.pdf
- Official model situations (14 topics) —
  https://cestina-pro-cizince.cz/trvaly-pobyt/modelove-situace?v=a2
