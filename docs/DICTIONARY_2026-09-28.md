# In-app dictionary — A1 (28 Sep 2026)

A dictionary of every word of a level: meaning, audio, key forms, all forms,
examples from the course, and the unit that teaches it. Searchable in Czech
(any form, with or without accents: *kava*, *piju*, *Praze*) and in English
(meanings and related words: *coffee*, *drink*).

Decisions (Mahesh, 28 Sep 2026):
- Whole level listed; words from units not reached yet are marked with the
  unit and a lock, and still open.
- Word forms are generated, checked automatically, then reviewed by the teacher
  before production.
- A word page shows the key forms; "Show all forms" opens the full tables.
- Entry points: a search button on Learn (beside Map/List) and on Review (the
  active review and the "nothing due" screen), and a card on Home. No new tab.

## What a learner sees

- **Home** (added the same day; Mahesh: "show it on Home in an appropriate
  way"): a Dictionary card right after Mock exam — a search bar that opens the
  dictionary, the word count, and a **word of the day**: a noun, verb,
  adjective or adverb from a unit the learner has already reached (never a
  locked one), with its meaning, first example and a listen button; tapping it
  opens the word's page. Same word all day, a new one each day
  (`lib/data/dictionary/word_of_the_day.dart`).

- **Learn / Review → search button → Dictionary**: A–Z list with letter
  headings, word count, and a unit tag per word (a lock on units not reached).
  The search field is focused on open.
- **Search**: results ranked word > form > English meaning > related English
  word; a result found through a form says so ("pít · form: piju").
- **Word page**: word and listen button; word type and gender or aspect;
  meanings; "You meet it in Unit N" (or "…which you haven't reached yet");
  what a preposition is followed by; key forms (tap to hear); "Show all forms";
  a note where it helps; up to two examples (tap to hear); "See also" links.
- It is a browsing screen, so it scrolls. Tables stack alternatives ("moje /
  má") inside a cell so four columns still fit a 360 pt phone at 200% text.

## Numbers (A1)

| | |
|---|---|
| Words | 679 (nouns, verbs, adjectives, pronouns, numbers, small words, 36 set phrases) |
| With full tables | 519 |
| Examples | 979 — most from the course's own Czech/English pairs, 148 written for the dictionary |
| Word forms in A1 lessons and review cards | 1,720, every one a form of a dictionary word or listed as not a word |

## Where things are

- Sources, one block per word: `tool/dictionary/a1/*.txt` (format at the end of
  `tool/dictionary/build_dictionary.py`). `not_words.txt` lists the lesson
  forms that are not Czech words of the level: names, letter names and
  syllables from the pronunciation lessons, English.
- Build: `python3 tool/dictionary/build_dictionary.py a1` →
  `assets/dictionary/a1_dictionary.json`. `--check` verifies without writing.
  The build fills in each word's unit and examples from the lessons and the
  review vocabulary, and fails if a Czech form the course uses is not in the
  dictionary.
- App: `lib/data/dictionary/` (model, search), `dictionary_providers.dart`,
  `lib/presentation/screens/dictionary/`, `DictionaryButton`, routes
  `/dictionary` and `/dictionary/:level/:id`.
- Tests: `test/dictionary_test.dart` (search; data integrity; every Czech word
  of the A1 lessons and review cards is covered — fails when a lesson gains a
  word the dictionary lacks), `test/dictionary_screen_test.dart` (flows, and
  every table's forms end inside a 360 pt screen at 200% text), and both
  screens in `test/screen_smoke_test.dart`.

## How it was checked

- The course's present-tense conjugation tables: every form matches.
- Every noun table's endings checked by pattern (dative plural -m, locative
  plural -ch, instrumental endings, accusative = nominative for inanimate,
  = genitive for animate); every verb's my/vy/ty endings. One flag, *být*
  (*jsi*), which is correct.
- Every Czech word in the dictionary's examples is itself in the dictionary.
- Each new test broken once on purpose and seen to fail.
- On the Android emulator (release build, production backend, units locked):
  Learn and Review buttons, browse, search by form and by English, word page
  with all forms, locked-unit wording, dark mode, returning to a review keeps
  the session.

## For the teacher review (gates production, with the rest of §9)

1. **All forms and notes** in `tool/dictionary/a1/*.txt` — generated from
   Czech grammar, not yet read by a Czech teacher. Highest value: irregular
   nouns (*dítě*, *člověk*, *přítel*, *rok/let*, *den*, *kuře*, *vejce*),
   possessives, numbers, the past tense of *jít/přijít/najít/sejít se*.
2. **The 148 written examples** — the `ex:` lines in the sources (the rest come
   from the course and were reviewed with it).
3. **Meanings and "related" words** — related words steer English search.
4. **Existing course error found on the way:** the declension table
   `decl_masc_animate_hard` in `assets/curriculum/declension_tables.json` gives
   the plural of *pan* as *pani, panů, panům, pany, panové, panech, pany*. The
   plural is *páni, pánů, pánům, pány, páni, pánech, pány* (*pani* is not a
   word; *paní* is Mrs). The dictionary uses the correct forms.

## Open questions for Mahesh

- **Looking up the answer during review.** The Review button works on an
  active card, so a learner can look up the card's word before revealing it.
  That is what "search icon on Review" gives; say if the button should hide
  while a card is face down.
- **Audio.** Words with a recording in the pack play it; the rest fall back to
  the device voice. Recording the dictionary's headwords and examples could
  join the A2 audio batch.
- **A2.** Build A2's dictionary unit by unit with the A2 rollout (its
  vocabulary is being rebuilt anyway): add `'a2'` to `kDictionaryLevels` and
  `LEVEL_UNITS`, write `tool/dictionary/a2/`.

## A2 (28 Sep 2026)

Mahesh's decision: a learner on A2 sees A1 and A2 words in one list; an A1
word shown to an A2 learner has no unit and no lock, because the app keeps a
learner on one level and cannot send them to an A1 lesson. A1 learners see
A1 words only.

**Numbers.** A2: 805 words (719 with forms, 981 examples), sources in
`tool/dictionary/a2/` by unit. A1 grew to 746 (from 679): the review units
28 and 30 keep their cards in `a2_vocabulary.json`, which the A1 build did
not read, so 73 of their word forms had no dictionary word.

**What a learner sees.**
- One dictionary, chosen by the course level in Settings
  (`learnerDictionaryLevelProvider`): Home, Learn, Review and the dictionary
  screen all open it. The level switch on the dictionary screen is gone.
- On A2, "1551 words · A1 + A2". A1 words carry an "A1" tag instead of a
  unit; their page has no "You meet it in Unit …" line.
- Units are numbered as Learn numbers them (`unit_no`): A2's Unit 1 is course
  unit 16, and A1's review units 28 and 30 are its Units 16 and 17. Before,
  the dictionary showed the course's ids ("Unit 28").
- The word of the day comes from the learner's own level.

**Builder changes** (`build_dictionary.py`).
- An A2 build counts A1's words as covered; an A2 word may not repeat an A1
  headword or id.
- Lesson text is read as the learner sees it: bracketed cues and hints left
  out, English narration skipped, `answer_key` only where it is the Czech the
  learner types, a translation's Czech side by its direction. A1's
  `not_words.txt` English list is now partly redundant.
- Review cards count by unit from both card files.
- Comparatives and superlatives (nej- + comparative) are generated and
  declined from each adjective's `cmp:`; key forms show "most …".
- A1 entries gained a few forms A2 uses: *přede*, *otevřeno*, *kolika*,
  *poteče*, *pojeďme*, *nejvíc*, and comparatives *častěji*, *rychleji*,
  *pomaleji*, *později*.

**Content errors the coverage check found (fixed).**
- Lesson 2901, the doctor dialogue: "Napišu vám recept" → *Napíšu*.
- Review cards: "Projeli jsme tunellem" → *tunelem*; "Cukněte dozadu" (not a
  word) → "Ustupte dozadu, prosím"; "Blahopřji" → *Blahopřeji*; "Naposed" →
  *Naposled*; "Gratuluji ti k promoční/promo!" and "na promoce" → *k
  promoci*, *na promoci*.

**For the teacher.** All A2 sources are generated and wait for review, like
A1's. Worth a first look: the months (added in full, only four are used), the
participle forms on signs (*zakázáno*, *vyprodáno*, *zřízena*), the dual
plurals (*oči*, *uši*, *ruce*, *rukama*), *odpočinout si* with both
*odpočinul* and *odpočal*, and the 135 examples written for words the
readings use only in long passages.
