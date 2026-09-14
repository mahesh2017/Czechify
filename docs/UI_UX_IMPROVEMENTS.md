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

## Third implementation batch: lesson recovery

Product decisions, 14 September 2026: hearts stay on by default; the graduated
feedback ladder stays, with Try again added on top of it; onboarding keeps its
teacher-voice and reminder steps; Daily Arrival stays and offers the lesson
after the one last finished.

- **Resume.** An unfinished normal lesson saves its position on this phone after
  every answer, when the teach phase ends, when Leave is chosen and when the app
  goes to the background. Reopening it continues at the same question with the
  same score, mistake queue and feedback-ladder state. Mock exams keep their own
  checkpoint and are not saved here. Finishing the lesson removes its entry;
  changed lesson content, or a save that cannot be read, starts the lesson over.
  Entries are cleared with the other account-scoped preferences.
- **Writing drafts.** Typing is saved 0.8 s after it stops and restored into the
  writing task. The revision stage after a first submission is not saved.
- **Try again.** After a wrong answer on the main pass of a normal lesson, the
  same question can be asked again straight away. Every miss costs a heart. The
  explanation still appears on the third miss and the answer on the fourth, and
  Try again is not offered after that. The question returns once in the mistake
  pass either way. Exams and the mistake pass do not offer it.
- **Leaving when saving fails.** The learner is told, and can choose Leave
  without saving.
- **One next lesson everywhere.** Daily Arrival, Home's Continue learning card
  and the Pronunciation Lab deck all use the next unfinished, unlocked lesson
  after the one most recently finished, or the first at the chosen level when
  none is. Home's card shows the unit name instead of the router's
  untranslated reason.
- **Worth revisiting.** When the evidence-weighted router picks a finished
  lesson for repair (a later check that didn't hold, unaided misses, or
  reliance on hints and replays) and it is not already the next lesson, Home
  shows it as a separate card under Continue learning, with a translated
  reason. It never replaces the next lesson. Decided 14 September 2026.
- **Home recommendation fix (first batch).** Finished lessons at the starting
  level no longer hold a learner there: an A1 starter who has finished A1 is
  recommended A2 instead of completed A1 lessons.

Held back for their own work: the unused Exams, Practice and Downloads strings,
48 dp touch-target resizing (it pushed the pronunciation retry controls out of
view) and the Android Settings page presentation.

## Next work, in order

1. **Practice and recovery (remaining):** verify resume, drafts, Try again and
   the Worth revisiting card on physical devices.
2. **Today, Exams and Progress:** prototype these screens together. Today
   should show one suitable session with duration and rationale. Exams should
   explain supported coverage and offer section practice and attempts. Progress
   should show skill evidence and a direct next action, with unassessed skills
   identified clearly. Validate navigation labels before replacing current tabs.
3. **First-session experience:** correct introductory A1-only copy; shorten
   onboarding around starting level, goal and available time; defer optional
   preferences until after useful practice. Consolidate repeated greetings.
4. **Android polish:** 48 dp tap areas and labels are in place on Home, the
   lesson player, every shipped exercise type, review, Daily Arrival and
   onboarding, held by `touch_target_guidelines_test.dart` and
   `input_semantics_labels_test.dart`. Still to do: check TalkBack on a device,
   adapt settings presentation, reduce repeated titles and heavy card shadows,
   and let important lesson names and recommendation explanations wrap.
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

Third-batch checks cover resume after a fresh start of the app state, draft
save after typing stops, feedback-ladder continuity across a resume, removal on
completion, discarding changed or damaged checkpoints, exam exclusion, store
write ordering, Try again hearts and ladder limits, draft wiring into the
writing task, Leave without saving, Daily Arrival's continue-lesson selection
and the finished-A1 recommendation.

- Third batch: `flutter analyze --no-pub`: no issues found.
- Third batch: `flutter test --no-pub`: all 1,161 tests passed.
- Third batch, Android emulator (Pixel 10 Pro, API 37, offline debug build,
  fresh install, 100% text, gesture navigation), 14 September 2026: onboarding
  showed all seven steps including teacher voice and reminders; Leave showed the
  new message and reopening resumed at question 2 of 10; after a force-stop,
  Daily Arrival appeared on relaunch offering the first A1 lesson, and starting
  it resumed at question 2 of 10; on a listening question, four misses in a row
  went 5 → 1 hearts with the signal, self-repair, cue-plus-explanation and
  answer steps in order, Try again was offered for the first three and not after
  the answer was shown.
- Not exercised on a device: writing-draft restore (no writing task in the
  first unlocked lesson), Leave without saving (needs failing storage), 200%
  text, three-button navigation and TalkBack.
- Found on the device and fixed: listening comprehension, matching and writing
  tasks showed their own Retry or Try again after submitting, beside the
  lesson's Try again. Those controls only cleared the answer, and the lesson
  ignores a second answer while its feedback is showing, so the re-answer was
  never recorded. They are removed; the lesson's Try again is the only retry.
  Pronunciation keeps its record-again control, which comes before the attempt
  is submitted. The delayed-transfer screen replaces the exercise once
  answered, so no use of these views needed its own retry. Covered by
  `in_exercise_retry_test.dart` and `lesson_single_retry_control_test.dart`
  (the latter fails against the previous listening view); 1,166 tests pass,
  and the emulator showed a single Try again after a missed listening question.
- One next lesson: `home_continue_and_revisit_test.dart` (fails against the
  previous Home) and router kind tests; 1,174 tests pass. On the emulator,
  Daily Arrival and Home's Continue learning card both named "Hear Czech in
  Useful Words · Hear, Read & Repair Czech". The Worth revisiting card was then
  checked by finishing that lesson with unaided misses left standing (3 of 18
  correct): Home moved Continue learning on to "The First Beat and Long Vowels"
  and showed "Hear Czech in Useful Words · Worth revisiting · some answers were
  missed without help" as a separate card directly beneath it, and the lesson's
  saved checkpoint was removed. On that run the emulator keyboard's floating
  toolbar covered the first keys of the Czech letter bar, so "á" could not be
  tapped; a dictation typed through an uncovered key ("ě") was accepted.

Before release, verify the changed screens on Android at normal text and 200%
text separately, with gesture and three-button navigation, keyboard input and
TalkBack. Automated widget checks do not replace native visual verification.
Test the broader redesign with 5–8 A1/A2 learners: starting appropriate practice,
finding exams, understanding corrections and resuming interrupted work should
all be possible without help.
