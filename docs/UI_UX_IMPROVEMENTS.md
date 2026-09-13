# A1/A2 Android UI/UX improvements

Branch: `codex/a1-a2-ux-improvements`  
Started: 13 September 2026

## Scope and direction

Serve A1 and A2 Czech learners. B1 is outside the current product scope.
Keep the existing purple identity, typography and reusable components. Make
the experience clearer through a focused next action, useful correction,
visible progress and dependable interruption recovery.

The initial Android review used a local debug build with its backend disabled.
Normal checks used 360×800 dp at 100% text. The pronunciation overflow was
found separately at 360×640 dp and 200% text; it was not a default-size defect.
The emulator was not matched to the owner's phone or installed build.

## First implementation batch

| Change | Result |
|---|---|
| Respect the selected level | Home prefers new lessons at the learner's A1/A2 level. Evidence can still recommend earlier material, and earlier lessons remain accessible. |
| Expose mock exams | Home links directly to the selected level's existing mock exam and describes it as informal practice. A1 course practice and the existing A2 exam remain distinct. |
| Confirm lesson exits | Android system Back and the lesson exit control share Stay/Leave confirmation during active lessons, including teaching material. Directly opened lessons can return Home. |
| Make pronunciation scroll | Compact screens and 200% text can scroll to the practice controls. Result buttons wrap when space is limited. |
| Follow the app theme | Screens with custom headers specify system status/navigation icon brightness from the active app theme. |
| Improve text contrast | Gender badges and the audio fallback banner use existing readable ink tokens. |
| Describe audio fallback accurately | The banner explains device-voice playback without assuming that every recorded-voice failure means the learner is offline. |

Exit confirmation does **not** save lesson position or writing drafts. The Home
shortcut is an initial discovery improvement, not the full proposed Exams hub.

## Second implementation batch: review recovery

- Typed recall now offers **I don't remember**. It reveals the answer without
  recording a successful recall. **Practise again** uses the existing Again
  scheduler and persistence path; a failed save keeps the answer open for retry.
- Active review uses the same confirmation for system Back and the close
  control. Stay preserves the current typed answer. End explains that completed
  ratings are saved and unfinished cards remain due.
- Review content scrolls on compact screens, with large text and with the
  keyboard visible. Each new attempt clears the input and returns to the top,
  even when the same forgotten card returns immediately.
- Progress segments reset their width animation when Again expands the queue,
  avoiding a transient horizontal overflow.
- Flashcard text, translation and audio controls are exposed to screen readers;
  the revealed card no longer announces itself as a flip button.

This batch does not add draft persistence across leaving the screen or restarting
the app. It uses the existing review scheduler and saved-rating behavior.

## Next work, in order

1. **Practice and recovery:** persist session position and writing drafts;
   provide a clear lesson retry, hint and explanation sequence. Revisit default heart
   interruptions while keeping exam simulation rules explicit.
2. **Today, Exams and Progress:** prototype these screens together. Today
   should show one suitable session with duration and rationale. Exams should
   explain supported coverage and offer section practice and attempts. Progress
   should show skill evidence and a direct next action, with unassessed skills
   identified clearly. Validate navigation labels before replacing current tabs.
3. **First-session experience:** correct introductory A1-only copy; shorten
   onboarding around starting level, goal and available time; defer optional
   preferences until after useful practice. Consolidate repeated greetings.
4. **Android polish:** complete the 48 dp target and semantics audit, adapt
   settings presentation, reduce repeated titles and heavy card shadows, and
   let important lesson names and recommendation explanations wrap.
5. **Offline confidence:** distinguish downloaded lessons from temporary cache,
   explain removal consequences, and expose accurate local-save and sync states.

Make progress feel rewarding through concrete skill achievements and restrained
optional motion. Keep reading and writing screens quiet and readable. Do not
present course completion, speech recognition or AI feedback as an official
exam result or a reliable pass prediction.

## Validation

Automated coverage includes selected-level changes, evidence-based remediation,
Home exam destinations, system Back Stay/Leave behavior for pushed and direct
lesson routes, system icon theme changes, and pronunciation control access at
100% and 200% text. Existing screen smoke tests cover light/dark themes and
English/Czech layouts. Final analysis and suite results are recorded below.

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub --reporter expanded`: all 1,125 tests passed.
- `git diff --check`: passed.
- Post-change native Android visual verification: pending.

Second-batch checks cover review Back, keyboard/100%/200% layouts, revealed-answer
semantics, failed-save retry and repeated-card input reset, alongside existing
review persistence and screen regression tests. Results are recorded with the
implementation commit.

- Second batch: all 58 affected regression tests passed.
- Second batch: `flutter analyze --no-pub` and `git diff --check` passed.
- The full 1,125-test run above belongs to the first batch; the second batch
  reran the affected review, navigation and screen tests.

Before release, verify the changed screens on Android at normal text and 200%
text separately, with gesture and three-button navigation, keyboard input and
TalkBack. Automated widget checks do not replace native visual verification.
Test the broader redesign with 5–8 A1/A2 learners: starting appropriate practice,
finding exams, understanding corrections and resuming interrupted work should
all be possible without help.
