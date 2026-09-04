# Czechify UI revamp — Figma handoff

Captured on iPhone 17 Pro Simulator at 1206 × 2622 px (3× scale), 28 August 2026. Screens use production configuration with a fresh local learner profile. The capture-only route override was removed after export; the app source is back to normal.

## Screenshot inventory

| File | Product state | Why it matters |
|---|---|---|
| `01-onboarding-welcome.png` | First launch | Brand promise, acquisition and onboarding entry |
| `02-home.png` | Home / next lesson | Daily loop, streak, goal and recommended activity |
| `03-learn.png` | Curriculum | Unit/lesson hierarchy, progress and navigation density |
| `04-review.png` | Empty review completion | SRS outcome and empty-state treatment |
| `05-ai-tutor.png` | Tutor scenario picker | Visual content discovery and premium-feeling practice |
| `06-progress.png` | Progress dashboard | Metrics, proficiency and next-action guidance |
| `07-settings.png` | Settings sheet | Preferences, grouped controls and modal behavior |
| `08-account.png` | Anonymous account | Google/email authentication, data export and deletion |
| `09-grammar.png` | Grammar reference | Search/browse information architecture problem |
| `10-placement.png` | Placement question | Assessment flow and answer selection |
| `11-copybook.png` | Handwriting practice | Editorial learning content and completion controls |
| `12-lesson.png` | Locked lesson | Access-gating state |
| `13-lesson-player.png` | Active lesson | Core learning interaction |

## Existing visual system

- Display type: Bricolage Grotesque; body type: Schibsted Grotesk.
- Light canvas: `#FAF7F2`; cards: `#FFFFFF`; recessed surfaces: `#F2EDE4`.
- Primary indigo: `#3355E8`; supporting amber, red, green and violet are already tokenized.
- Current language: large rounded cards, soft shadows, pill controls, bold editorial headings and Czech lifestyle illustrations.
- Navigation: five persistent destinations—Home, Learn, Review, Chat and Stats.

## What is already strong

- Czechify feels warmer and more adult than a generic gamified language app.
- The indigo/cream combination is recognizable and works well with the Prague illustrations.
- Home has a clear “continue learning” action.
- The curriculum communicates sequence well, and Tutor scenarios connect practice to real situations.
- Typography has personality without sacrificing Czech diacritics.

## Main UI problems to solve

1. **Hierarchy is too loud.** Many screens use display-sized text for titles, card titles, numbers and actions simultaneously. The eye has no quiet layer.
2. **Cards consume too much vertical space.** Large radii, padding and shadows reduce information density; Settings and Progress require excessive scrolling.
3. **Content clips in important places.** Tutor descriptions, curriculum copy and metric labels truncate, while grammar exposes raw tags such as `complex_sentences`.
4. **Five equal tabs dilute the daily loop.** Review and Chat are valuable, but Home and Learn should dominate; Stats is better as part of Profile/Progress.
5. **Empty and zero states look like completed achievements.** “Deck cleared” with 0 cards and 0% recall feels contradictory.
6. **Progress is metric-first instead of insight-first.** Zeroes dominate before the app explains what to do next.
7. **Authentication is action-heavy.** Google, two email actions, recovery, export and deletion compete on one screen without clear priority.
8. **Reference content lacks findability.** Grammar is a long reverse-ordered list with technical metadata instead of search, level filters and human-readable topics.
9. **Accessibility needs more deliberate hierarchy.** Several secondary grays are visually light, selected state relies heavily on color, and some touch targets appear crowded.

## Recommended redesign: “Czech confidence coach”

The new design should feel like a calm personal coach for adults living in Czechia: practical, culturally grounded and focused on one useful win at a time. Keep the existing brand assets and warm palette, but move from “large cards everywhere” to a clearer editorial layout.

### Navigation

Use four primary tabs:

1. **Today** — daily plan, streak and resume action.
2. **Course** — curriculum map, units and reference shortcuts.
3. **Practice** — Review, AI Tutor, Pronunciation and Copybook in one task hub.
4. **Progress** — level, skills, achievements, account and settings entry.

This reduces navigation load and gives practice modes a coherent home. Settings becomes a conventional top-right action within Progress rather than a prominent Home control.

### Today

- Start with a compact greeting row and a single 160–190 pt “Next best action” hero.
- Show progress as “8 min to today’s goal” instead of “0 / 300 XP”. XP can remain secondary.
- Replace the large weekly streak card with a compact seven-day strip.
- Add a two-item “Also practise” row based on weak skills.
- Celebrate completion with color and motion only after real activity; avoid achievement styling for zero states.

### Course

- Keep the unit map, but make the active lesson the visual anchor and collapse completed/upcoming lessons.
- Replace repeated `NEXT UP` pills with state-specific icons/labels only where necessary.
- Use a sticky level/unit selector and a compact progress line.
- Add contextual shortcuts to Vocabulary and Grammar for the active unit.

### Practice

- Top section: “Recommended for you” with one personalized task.
- Below: four stable practice modes—Review, Tutor, Pronunciation, Writing.
- Tutor scenarios should use one-column feature cards or a horizontally scrolling carousel; current two-column cards clip copy and imagery.
- Show due counts and estimated time before entering a mode.

### Progress

- Lead with a plain-language insight: “Listening is your strongest skill” or “Practise long vowels next.”
- Use one level-progress visualization, then a compact 2×2 skill grid.
- Put streak, XP and hearts in a secondary “Activity” section.
- Empty state: explain that insights appear after the first lesson and provide one primary CTA.

### Lessons and assessment

- Standardize the top bar: close/back, thin progress indicator, hearts only when enabled.
- Keep one question or concept per viewport with a sticky bottom CTA.
- Answer cards should have explicit default, selected, correct, incorrect and disabled components.
- Use short feedback directly beneath the answer, with optional “Why?” expansion.
- For placement, show “1 of about 8” because adaptive length is uncertain.

### Account and settings

- Account hero should state the benefit: “Save and sync your progress.”
- One primary button: **Continue with Google**. Put email behind **Use email instead**.
- Move recovery into the email sign-in flow.
- Put export and deletion under a clearly separated “Data & privacy” section; destructive action is tertiary until opened.
- Explain identity behavior near Google sign-in: one Google identity maps to one Czechify account.

### Grammar and reference

- Add search, A1/A2 chips and topic chips (Cases, Verbs, Word order, Pronunciation).
- Sort by learning sequence by default, with “Recently viewed” above the list.
- Replace database-style tags with human labels and short examples.
- Grammar detail pages should use: rule → two examples → common mistake → quick practice.

## Figma component checklist

- App shell: status-safe header, four-tab bar, modal sheet.
- Buttons: primary, secondary, quiet, destructive; loading and disabled states.
- Cards: next-action, unit, lesson row, practice mode, metric, insight, account state.
- Inputs: answer choice, text field, segmented control, chips, search, toggle.
- Feedback: correct, incorrect, hint, toast, offline, syncing and error.
- Learning: progress header, heart counter, audio control, record control, Czech/English phrase pair.
- States for every core screen: loading, empty, populated, offline, locked and error.

## Suggested Figma pages

1. `00 Foundations` — color, type, spacing, radii, elevation, iconography.
2. `01 Components` — variants and interaction states.
3. `02 Onboarding & Account`.
4. `03 Today & Navigation`.
5. `04 Course & Reference`.
6. `05 Lesson & Placement`.
7. `06 Practice & AI Tutor`.
8. `07 Progress & Settings`.
9. `08 Prototype` — first launch → first lesson; returning learner → daily goal; Google sign-in → synced account.
10. `09 QA` — dark mode, Dynamic Type, long Czech/English strings and offline/error states.

## Prototype priorities

Design these three clickable workflows first:

1. New learner: Welcome → name → starting level → goal → first lesson.
2. Returning learner: Today → resume lesson → answer feedback → lesson complete → updated Today.
3. Existing learner: Account → Google sign-in → existing-account confirmation → synced Progress.

The redesign should be validated at 390 × 844 pt and 430 × 932 pt, then with 200% Dynamic Type and both light/dark themes.
