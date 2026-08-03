# Manual verification — audit remediation Phases 1–3

Things the automated suite cannot prove. Branch: `fix/audit-phases-1-2`
(commits `6137247`, `832b8e1`, `8c2dcd5`).

Everything here needs a real device, a real backend, or a human judgement
call. The 568 passing tests cover the logic; these cover the parts that only
exist once the app is actually running.

---

## A. Blocking — do these before merging

### A1. Account switch does not lose data (Phase 1)

The single highest-risk fix. Needs **one physical device and two accounts**.

1. Sign in as account **A**. Complete a lesson and earn some XP, so A has
   progress written *from this device*.
2. Let it sync (watch for the outbox draining, or wait out a sync cycle).
3. Switch to account **B** in Settings.
4. Switch back to account **A**.

- [ ] A's lesson progress, XP, and streak are all back.
- [ ] The SRS review deck has A's cards, not an empty deck.
- [ ] Custom vocabulary cards A created are present.

**Why it can't be automated:** the bug only appears when the device id in
the cloud rows matches the local install, which is a property of a real
device's secure storage, not a fake backend.

**If this fails, stop.** It means the install path is still dropping rows and
the rest of the branch should not merge.

### A2. Nothing in the wild carries schema v17 (Phase 1)

I implemented Branch A — a loud `StateError` on downgrade — on your
confirmation that no pre-`85ce083` build escaped your machines.

- [ ] Confirm once more: no TestFlight build, internal tester, or side-loaded
      APK from before that commit is on anyone's device.

**If that turns out to be wrong,** a `StateError` at startup is an
unrecoverable crash loop for those installs, and we should switch to Branch B
(drop-and-recreate) before release. Tell me and I'll change it.

### A3. Migration on a real upgraded install (Phase 1)

Tests cover this with synthetic databases; a real one has real data volume.

1. Install the last build from `main` (pre-branch), use it enough to create
   SRS cards and complete a lesson.
2. Install this branch **over the top** — do not uninstall first.

- [ ] App launches.
- [ ] Progress and review deck survived.
- [ ] No duplicate cards in the review deck.

---

## B. Behaviour changes you should agree with

### B1. A failed pronunciation check now shows an error (Phase 3)

**This reverses a previously tested guarantee** and is the change most worth
your eyes. Old behaviour scored the learner ~0% when cloud speech failed; new
behaviour tells them it could not be checked and drops to on-device for the
rest of the session.

To see it: point the build at a project where `whisper-proxy` is not deployed,
or exhaust the daily speech quota.

- [ ] The **Pronunciation Lab** shows the message and *no* score.
- [ ] It does **not** say "Make sure microphone permissions are granted" for a
      quota error.
- [ ] The **in-lesson** pronunciation exercise shows the reason under the
      record button, and the skip link still works.
- [ ] The **second** attempt goes straight to on-device and produces a real
      score — the exercise is still completable.

- [ ] You agree this is better than the old silent 0%.

### B2. Long conversations now drop old turns (Phase 2)

- [ ] Hold a conversation past ~15 exchanges. It keeps working (it used to
      break permanently around 12).
- [ ] The tutor still follows the thread — judge whether losing the oldest
      turns is acceptable, or whether Phase 6's summarization should be
      pulled forward.
- [ ] Open a pre-existing long conversation from before this branch and
      confirm it now responds instead of erroring.

### B3. English narration actually plays (Phase 2)

The recorded English pack has never played in any build; this is the first
time you'll hear it.

- [ ] Teaching cards use the recorded narration voice, not the robotic
      system voice.
- [ ] It matches the male/female setting.
- [ ] Judge the recorded pack's quality — nobody has heard it in situ. If it
      sounds wrong, that's a content problem the fix has just exposed, not a
      regression.

---

## C. Platform and timing

### C1. Evening reminders after the DST change (Phase 2)

Verifiable without waiting for October:

1. Set the device clock to **24 Oct 2026**, timezone **Europe/Prague**.
2. Enable evening catch-up reminders.
3. Advance the clock past **26 Oct**.

- [ ] Reminders still arrive at **21:30** local, not 20:30.
- [ ] Reset the device clock afterwards.

### C2. CI timezone pin (Phase 2)

I added `TZ: Europe/Prague` to the test job. Under UTC the DST test passes
whether or not the bug is present.

- [ ] You're happy with that, or want it done another way.
- [ ] First CI run on the branch is green.

---

## D. Known gaps I could not close

Not failures — work deliberately left, so it doesn't get lost.

- [ ] **`installSession` null guard (Phase 1) has no test.** Needs a mocked
      Supabase auth client the suite doesn't have. Change is a null-check.
- [ ] **Whisper status→message mapping (Phase 3) has no test.** Same reason:
      it needs a mocked `SupabaseClient.functions`. The *consumers* of the
      mapping are tested; the mapping itself is not.
- [ ] **Per-message length is unguarded (Phase 2).** A single chat message over
      4,000 characters is still refused server-side. Worth adding a
      `maxLength` to the chat input if it has none.
- [ ] **macOS deep links are still broken** — `czechify://auth-callback` is not
      registered in `macos/Runner/Info.plist`, so email verification and
      password recovery dead-end there. Scheduled for Phase 4.

---

## E. Not mine

Untouched in your working tree, excluded from all three commits:

- The `com.ceskinapro.*` → `com.eminentsite.czechify` package rename
  (`android/`, `ios/`, `macos/`).
- `lib/data/services/stt/stt_bench_hook.dart`.

- [ ] Decide whether the rename lands before or after this branch. If Android
      release signing is already configured against the old application id,
      changing it needs a new upload key entry in Play Console.
