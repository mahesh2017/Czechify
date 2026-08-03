# Manual verification — audit remediation Phases 1–6

Things the automated suite cannot prove. Branch: `fix/audit-phases-1-2`
(commits `6137247`, `832b8e1`, `8c2dcd5`, `2a28ced`, `ca760b0`, `c635b48`,
`3f148ee`). All six phases are complete.

Everything here needs a real device, a real backend, or a human judgement
call. The 588 Dart + 27 Deno tests cover the logic; these cover the parts that
only exist once the app is actually running.

**Phases 4 and 6 need a backend deploy; Phase 6 also needs a database
migration. Sections F and I.**

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

## F. Phase 4 — needs a backend deploy

Phase 4 changed three Edge Functions. **None of it takes effect until they are
deployed.** The Dart tests pass regardless, so a green CI run does not mean
these are live.

### F1. Deploy the functions

```bash
supabase functions deploy account-data deepseek-proxy whisper-proxy
```

- [ ] Deployed. `tool/smoke_edge_functions.sh` still passes afterwards.

### F2. The export now contains custom vocabulary

1. Create a custom vocabulary card in the app and let it sync.
2. Settings → export your data.

- [ ] The export JSON has a `cloud_data.custom_cards` array containing it.
- [ ] Spot-check that nothing else you'd expect is missing. The new contract
      test only proves synced entities are listed — it cannot know about a
      table that is server-written and never synced.

### F3. Quota refunds on server-side failure

Hard to force deliberately; mostly worth watching for.

- [ ] Over a few days of real use, the daily AI and speech counters do not
      drift down faster than actual successful requests.
- [ ] I left the **per-minute burst window unrefunded** on purpose — it resets
      within 60 seconds and refunding it would need a new SQL function and
      migration. Confirm you agree that trade is right.

### F4. macOS deep link

Needs a macOS build and a real email round trip.

1. Build and run on macOS. Link an email address to an anonymous account.
2. Click the verification link in the email.

- [ ] The app comes to the foreground and completes verification.
- [ ] Password recovery does the same.
- [ ] The Supabase Auth redirect allowlist includes `czechify://auth-callback`
      — the plist is only half of it; the server has to permit the redirect.

### F5. Consent log survives an account switch

Pairs with A1, same session.

- [ ] After switching A → B → A, Settings still shows the cloud-speech
      consent decision history rather than an empty log.

---

## H. Phase 5 — the refactor, and what it changed underneath

Phase 5 was meant to be a tidy-up. It surfaced two real bugs, so it needs more
of your attention than a refactor normally would.

### H1. Audio still plays, both languages

The Czech and English packs now share one cache implementation. The suite
cannot cover this: the download path needs a real filesystem and network.

- [ ] Czech clips play in lessons, at both normal and slow speed.
- [ ] English narration plays on teaching cards.
- [ ] Both follow the male/female voice setting.
- [ ] Kill the network mid-lesson: previously cached audio still plays and the
      manifest falls back to its cached copy.
- [ ] Settings → clear audio cache, then play something. It re-downloads.

### H2. Clips stop being re-downloaded on every launch

Both packs wrote the same `_cache_meta.json` from separate in-memory copies, so
whichever saved last erased the other's checksums and those clips were fetched
again next launch. Only observable over more than one session.

- [ ] Play some Czech and some English audio. Force-quit. Relaunch and play the
      same items — they should be instant, with no network traffic.

### H3. Prefetch cancellation

- [ ] Start an offline audio download, then navigate away mid-download.
- [ ] Traffic stops (check with a network monitor, or watch that no further
      files appear in the cache).
- [ ] Returning to the screen can start a fresh download without issues.

### H4. Sync retry appears when it should

The retry row only renders when something has actually dead-lettered, which is
hard to force. To try: sign in, go offline, make progress changes, and let the
outbox exhaust its five attempts.

- [ ] Settings shows "Retry failed sync" with a count.
- [ ] Tapping it, back online, clears the count and the changes reach the
      backend.
- [ ] The row is absent when nothing has failed. **This is the more important
      case** — a permanently visible sync-error row would be worse than the
      silence it replaced.

### H5. `gcStaleAudio` remains unreferenced

I fixed it to consider both packs rather than deleting every English clip, but
it still has no callers.

- [ ] Decide: wire it up (it needs a trigger — after a manifest revision
      change is the natural one), or delete it. Leaving correct-but-dead code
      is the worst of the three.

---

## I. Phase 6 — quota, memory, scheduling

Needs a **database migration** as well as a function deploy. Run the migration
first: the new `remaining_today` field is harmless without it, but the refund
fix is not applied until it lands.

```bash
supabase db push
supabase functions deploy deepseek-proxy whisper-proxy
```

- [ ] `supabase test db` passes, including the new `quota_refunds.test.sql`.
      **I could not run this locally — Docker was unavailable — so CI is the
      first thing that has ever executed it.** If it fails, the migration is
      the suspect, not the test.

### I1. Quota refunds finally work

The refund functions referenced tables that were never created, so they raised
on every call and the error was swallowed. Nobody has ever been refunded.

- [ ] Force a failure (point `DEEPSEEK_API_KEY` at an invalid key on a staging
      project) and confirm the daily counter goes back down rather than staying
      consumed.

### I2. The allowance is visible before it runs out

- [ ] Set `AI_DAILY_REQUEST_LIMIT` low (say 5) on staging. Chat until 3 remain.
- [ ] The warning appears at 3 and counts down; it does **not** appear at full
      allowance. A running count every turn would be noise.
- [ ] At 0 the existing "Daily AI tutor limit reached" error still shows.

### I3. Conversation memory past the window

- [ ] Hold a conversation past ~12 exchanges, establishing a fact early
      ("jmenuji se Petr", or an order placed).
- [ ] After the window has rolled, ask the tutor about it. It should still know.
- [ ] Judge the summary quality — this is the part I cannot assess. If the
      tutor's memory feels wrong or generic, the prompt in
      `request_policy.ts` (`conversation_summary`) is where to tune it.

### I4. Summarization cost — a decision I made for you

I made summarization **exempt from the daily learner allowance**, on the
grounds that it is machinery they never asked for and charging them would make
a long conversation quietly cost double. It still passes the burst limits.

The consequence is on your DeepSeek bill: a conversation past the window costs
**two upstream calls per turn** instead of one, and that second call is not
capped by the learner's daily limit.

- [ ] Confirm you want that trade. The alternatives are charging it to the
      learner's allowance (one line in `index.ts`), or dropping summarization
      and accepting that the tutor forgets.
- [ ] Watch spend for a few days after deploying.

### I5. SRS scheduling changed

Ease now moves on the first two reviews instead of only from the third.

- [ ] Existing cards keep their stored ease — nothing is re-derived, and no
      migration touches them. Confirm you want it that way rather than
      recomputing from `review_attempts`.
- [ ] Rate a new card Easy twice and another Hard twice; by the third review
      their intervals should differ. They used to be identical.

---

## G. Decision still open — consent record durability

**I did not build this and want your call before anyone does.**

The consent audit log is device-local. It survives an account switch now, but
not a lost, reset, or replaced phone. That is a weaker position than it looks:
GDPR Art. 7(1) asks the *controller* to be able to demonstrate consent, and
right now the only copy lives on the data subject's own phone.

`ConsentRepository.pendingSync()` and `markSynced()` are the client half of
fixing that. They have no callers — I left them in place with an honest note
rather than deleting them, since deleting forecloses and they are already
tested.

Pick one:

- [ ] **Build it.** A `consent_records` table with owner RLS, an entry in the
      sync entity map, and inclusion in `syncedUserTables`. Roughly the size of
      the `custom_cards` migration. Consent evidence then survives device loss.
- [ ] **Leave it device-local.** I delete the two dead methods and the `synced`
      column note, and document in PRIVACY.md that the consent log is
      device-local so nobody later assumes otherwise.

Worth asking whoever advises you on data protection, rather than deciding it
on engineering grounds. Tell me which and I'll do it in Phase 5.

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
- [ ] ~~macOS deep links are still broken~~ — fixed in Phase 4; verify via F4.
- [ ] **The export contract test is one-directional.** It proves every *synced*
      entity is exported. A server-written table that the client never syncs
      could still be missed, because nothing on the client would know it
      exists. Only a review of the schema catches that class.

---

## E. Not mine

Untouched in your working tree, excluded from all three commits:

- The `com.ceskinapro.*` → `com.eminentsite.czechify` package rename
  (`android/`, `ios/`, `macos/`).
- `lib/data/services/stt/stt_bench_hook.dart`.

- [ ] Decide whether the rename lands before or after this branch. If Android
      release signing is already configured against the old application id,
      changing it needs a new upload key entry in Play Console.
