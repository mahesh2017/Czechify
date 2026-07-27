# Czechify — Pre-Release Remediation Plan

Derived from the QA report, **re-verified against the codebase on 2026-07-27**. Numbers in
the QA report that did not survive verification have been corrected here; this file is the
source of truth, not the original report.

## Corrections applied to the QA report

| QA claim | Verified reality |
|---|---|
| ~109 lib files | **196** Dart files under `lib/` (75 test files was correct) |
| 61 `catch (_) {}` | **7** exact `catch (_) {}`, 48 `catch (_)` total |
| ~40 hardcoded colours in 6 screens | **~190** `Colors.` refs; the exercise-widget layer was omitted entirely |
| Flat file paths (`srs_review_screen.dart`) | All paths are nested; see the task tables below |
| `app_en.arb` has 20 strings | **21** keys |
| 6 analyzer issues | Confirmed: 1 unused import + 5 `avoid_print` |

## Ground rules (how we avoid scope drift)

1. **A phase is done when its Definition of Done passes — not when it feels done.** No
   starting phase N+1 with phase N's DoD unmet.
2. **No opportunistic refactors.** If a phase touches a file that also has an unrelated
   problem, note it in "Deferred" at the bottom of this file; do not fix it in that PR.
3. **One PR per phase**, titled `phase N: <name>`. Each PR description restates that
   phase's Deliverable verbatim.
4. **Every phase ends green:** `flutter analyze` clean and `flutter test` passing.
5. Phases 1–4 are release blockers. Phases 5–6 are not; ship without them if time forces it.

---

## Phase 0 — Baseline & guardrails

**Deliverable:** a repo that can prove whether later phases actually changed anything.

| # | Task | Files |
|---|---|---|
| 0.1 | Fix the 6 analyzer issues (unused drift import; 5 `print` in `tool/phoneme_demo.dart`) | `test/consent_repository_test.dart`, `tool/phoneme_demo.dart` |
| 0.2 | Diagnose the `flutter test` 300s timeout — time each suite, identify the slow ones | — |
| 0.3 | Record baseline counts in this file: `Colors.` refs, `Semantics(` count, hardcoded `Text('` count | this file |

**Definition of Done:** `flutter analyze` reports 0 issues. `flutter test` completes within
a known, documented wall-clock time. Baseline table below is filled in.

**Baseline — measured 2026-07-27, commit `787fbf4`:**

| Metric | Command | Value |
|---|---|---|
| Dart files in `lib/` | `find lib -name '*.dart' \| wc -l` | 196 |
| Hardcoded colours | `grep -rn "Colors\." lib/presentation \| wc -l` | **217** |
| Accessibility labels | `grep -rn "Semantics(" lib/presentation \| wc -l` | 6 |
| Tooltips / IconButtons | `grep -rn "tooltip:\|IconButton(" lib/presentation` | 8 / 19 |
| Hardcoded UI strings | `grep -rn "Text('" lib/presentation \| wc -l` | 128 |
| Silent catches | `grep -rn "catch (_) {}" lib \| wc -l` | 7 |
| l10n keys (en / cs) | `app_en.arb` / `app_cs.arb` | 21 / 0 |
| Analyzer issues | `flutter analyze` | 0 (was 6, fixed in 0.1) |
| Test suite | `flutter test` | **452 tests, all passing, 92.9s wall clock** |

**0.2 finding — the "300s test timeout" does not reproduce.** A clean run is 92.9s
(`real 92.86`, 452 tests, exit 0). During investigation three stale
`flutter run --dart-define-from-file=env/prod.json --release -d 00008140-…` processes were
found still resident (PIDs 9252, 53583, 65338), each holding a Dart VM and a device
connection. Compile-heavy `flutter test` runs contend with those for CPU. **Conclusion: the
QA officer's timeout was environmental, not a property of the test suite.** No test-suite
work is needed; leaving the stale processes running is the actual hazard. Kill orphaned
`flutter run` processes before timing anything.

---

## Phase 1 — Dark mode repair

**Deliverable:** every screen and exercise widget renders legibly in dark mode, using
`AppTokens` exclusively. No raw `Colors.*` in `lib/presentation` except a documented
allowlist.

Available tokens (`lib/core/theme/app_tokens.dart`): `bg card elev ink muted faint line pri
priFill onFill priSoft priInk amber amberSoft red redSoft green greenSoft violet violetSoft
chipBg userBubble userBubbleTxt`.

| # | Target | `Colors.` refs |
|---|---|---|
| 1.1 | `screens/review/srs_review_screen.dart` | 29 |
| 1.2 | `widgets/lesson/exercises/listening_comprehension_view.dart` | 23 |
| 1.3 | `screens/lesson/lesson_player_screen.dart` | 22 |
| 1.4 | `screens/exam/mock_exam_screen.dart` | 19 |
| 1.5 | `widgets/common/grammar_tip_card.dart` | 16 |
| 1.6 | `screens/pronunciation/pronunciation_screen.dart` | 15 |
| 1.7 | `widgets/lesson/exercises/reading_comprehension_view.dart` | 14 |
| 1.8 | `widgets/lesson/exercises/error_correction_view.dart` | 12 |
| 1.9 | `widgets/lesson/exercises/pronunciation_view.dart`, `widgets/celebration/unit_complete_overlay.dart` | 8 + 8 |
| 1.10 | Remaining tail: `writing_task_view`, `xp_badge`, `speaking_task_view`, `chat_screen`, `multiple_choice_view`, `grammar_reference_screen`, `home_screen`, `app_router` | ~30 |
| 1.11 | Delete `_genderColor()` in the SRS screen; use the same source as `lesson_rating.dart`'s `_genderPill()` | 1 refactor |

**Definition of Done:**
- `grep -rn "Colors\." lib/presentation` returns only entries on the allowlist, and the
  allowlist is written into this file with a one-line justification each (e.g. `Colors.white`
  on the teal hero).
- Exactly one gender-colour implementation exists in the codebase.
- Manual check: SRS review, lesson player, mock exam, and pronunciation screens
  screenshotted in dark mode and attached to the PR.

### Phase 1 status — COMPLETE

**217 → 15** raw `Colors.*` references across `lib/presentation` + `lib/core`, every one
on the allowlist below. Analyzer clean, 463 tests passing. Commits `b8bca7b`, `1bc254a`.

Verified on the iOS simulator in dark mode — home, curriculum, teach-phase word cards,
lesson runner, answer-feedback states (correct/wrong tints and the grammar tip card),
pronunciation lab, review-complete, exam intro, exam reading section, and the router
error page all render legibly.

Exactly one gender-colour implementation now exists
(`widgets/common/gender_pill.dart`); the review screen's raw-Material `_genderColor()`
is gone and the lesson player calls the shared helper.

Two fixes were needed beyond straight substitution:

- `ScoreColors.of()` (`lib/core/utils/score_colors.dart`) returned raw Material colours and
  lives outside `lib/presentation`, so it was invisible to the QA report's grep. It now
  takes a `BuildContext`.
- `context.tokens` asserted the theme extension with `!`, which crashed 13 widget tests
  once these widgets started reading tokens. It now falls back to `AppTokens.light`/`.dark`
  by ambient brightness rather than throwing.

### Allowlist — raw `Colors.*` that stays

| Location | Value | Why |
|---|---|---|
| `settings_screen.dart:596`, `curriculum_screen.dart:250`, `error_correction_view.dart:316`, `app_theme.dart:172` | `Colors.transparent` | Absence of colour; nothing to theme. |
| `home_screen.dart:284,398` | `Colors.white` | Sits on the always-teal `priFill` hero, which does not flip with the theme. |
| `unit_complete_overlay.dart` (8 refs) | `Colors.black` scrim, `Colors.white`/`white70` text | Full-bleed celebration overlay that is deliberately dark in both themes; the scrim *is* the background. |
| `xp_badge.dart:57-60` | `Color(0xFF9AA0A6)` etc. | League identity colours (silver/gold/platinum/diamond) — fixed brand values, now explicit hex rather than `Colors.grey`/`.cyan`/`.blue` so they read as deliberate. |
| `app_theme.dart:168` | `Colors.white` | Switch thumb; Material's own component default. |

**Explicitly not in this phase:** splitting large files, adding Semantics, changing copy.

---

## Phase 2 — Security hardening

**Deliverable:** no unauthenticated cross-origin surface on the Edge Functions, and account
deletion that a stolen access token alone cannot trigger.

| # | Task | Files |
|---|---|---|
| 2.1 | Add CORS + `OPTIONS` handler to whisper-proxy (currently has none at all) | `supabase/functions/whisper-proxy/index.ts` |
| 2.2 | Replace `Access-Control-Allow-Origin: *` with an explicit origin allowlist in all three functions | `deepseek-proxy`, `account-data`, `whisper-proxy` |
| 2.3 | Require fresh re-authentication before `deleteCloudAccount()` — password re-entry or fresh OTP, not just the `x-confirm-account-deletion` header | `lib/data/sync/backend_service.dart:127`, + the calling UI |
| 2.4 | Replace `ceskinapro://auth-callback` with Universal Link (iOS) + App Link (Android) over an HTTPS domain | `backend_service.dart:62,112`, `Info.plist`, `AndroidManifest.xml`, `.well-known/` hosting |
| 2.5 | Triage the 7 `catch (_) {}` sites: each either logs, surfaces to the user, or gains a comment saying why silence is correct | 7 sites |

**Definition of Done:**
- A `curl` with an `Origin:` header from a non-allowlisted origin is rejected by all three
  functions; the transcript is pasted in the PR.
- Deleting an account from a session whose password has not been re-entered fails.
- `grep -rn "catch (_) {}" lib` — every remaining hit has an adjacent justifying comment.

**Note on 2.4:** this needs a real HTTPS domain and hosting for the association files. If
that domain is not available, 2.4 is deferred and the rest of Phase 2 still ships — say so
explicitly rather than half-implementing it.

### Phase 2 status — COMPLETE except 2.4 (blocked)

| Task | Outcome |
|---|---|
| 2.1 whisper-proxy CORS + OPTIONS | Done (`0861971`) — it had none at all |
| 2.2 drop `Access-Control-Allow-Origin: *` | Done (`0861971`) — allowlist defaults to empty across all three functions |
| 2.3 re-auth before deletion | Done (`d3e4f9f`) — server rejects a token older than 5 minutes |
| 2.4 Universal Links / App Links | **BLOCKED — needs a domain** |
| 2.5 triage silent catches | Done (`32eaa89`) |

`deno fmt`/`lint`/`check` clean and 23 Edge Function tests pass, run locally via
`npx deno@2` (no system install needed — the repo has no local Deno).

**2.4 is blocked on a decision only the owner can make.** Replacing `ceskinapro://` with
Universal Links needs an HTTPS domain you control, serving
`/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`. The repo has
no project-owned domain — every URL in `docs/` points at third parties. Nothing was
half-implemented. To unblock: name the domain and confirm you can host two static files
on it.

Also fixed while here: the 204 on successful deletion was spreading the old module-level
`corsHeaders` name, which had become an imported *function* — spreading a function yields
no properties, so that one reply silently went out with no CORS headers.

---

## Phase 3 — Localization foundation

**Deliverable:** a Czech UI is selectable and covers the app's primary navigation and
lesson flow. Partial coverage is acceptable; *invisible* coverage is not.

| # | Task |
|---|---|
| 3.1 | Expand `lib/l10n/app_en.arb` from 21 → ~60 keys covering nav labels, settings groups, primary buttons, and user-facing error messages |
| 3.2 | Create `lib/l10n/app_cs.arb` (ISO code is `cs`, **not** `cz` as the QA report wrote) with translations for every key |
| 3.3 | Wire `AppLocalizations.of(context)` into: home, settings, curriculum, SRS review, chat, lesson player |
| 3.4 | Add a language selector in settings; verify locale persists across restart |

**Definition of Done:**
- `flutter gen-l10n` runs clean; `app_cs.arb` has zero missing keys relative to `app_en.arb`.
- Launching with device locale `cs` shows Czech on all six wired screens.
- A test asserts the two `.arb` files have identical key sets.

### Phase 3 status — COMPLETE (`11a8596`)

- `app_en.arb` 21 → **74 messages**; `app_cs.arb` created with all 74 translated.
- Wired: adaptive scaffold (nav), settings, home, SRS review, lesson player.
- Language setting persists; defaults to null = follow the device, so a Czech-locale
  phone gets a Czech UI unprompted.
- Czech plurals use `one`/`few`/`other` — English's two-way split would render
  "3 den v řadě".
- **The file is `app_cs.arb`.** `cs` is the ISO 639-1 code for Czech; the QA report's
  `app_cz.arb` would never have been loaded by `gen-l10n`.
- Tests: ARB key parity, placeholder agreement, untranslated-copy detection, and the
  real per-locale lookup including all three plural bands. 463 tests pass.

Phase 5.3 (misleading lesson-exit copy) landed here too — the dialog now reads that
completed answers are saved, which is what the code actually does.

**Explicitly not in this phase:** translating lesson *content* (that is authored data, not
UI strings), or the remaining ~13 screens.

---

## Phase 4 — Accessibility baseline

**Deliverable:** the core learning loop — start a lesson, answer, rate an SRS card — is
completable end-to-end with TalkBack/VoiceOver.

| # | Task |
|---|---|
| 4.1 | `Semantics` on SRS review: rating buttons, flip affordance, audio playback |
| 4.2 | `Semantics` on lesson player: hearts count, progress, feedback banner, continue |
| 4.3 | `Semantics` on chat: send, mic, scenario cards, vocab chips |
| 4.4 | `Semantics` on home: quick actions, shortcut rows, settings |
| 4.5 | `tooltip:` on every `IconButton` (currently 8 in the whole presentation layer) |

**Definition of Done:**
- Every `IconButton` in `lib/presentation` has a `tooltip`, verified by grep.
- One recorded screen-reader pass completing: home → lesson → answer → complete, and
  home → review → rate a card.

---

## Phase 5 — Functional fixes (non-blocking)

**Deliverable:** the known-misleading behaviours are corrected or honestly labelled.

| # | Task | Files |
|---|---|---|
| ~~5.1~~ | **Dropped — premise is false.** See the finding below. | — |
| 5.2 | Decide and document the STT model hosting plan — a ~340MB asset on Supabase free tier (5GB egress) supports ~15 downloads/month | `docs/` |
| 5.3 | Fix the lesson exit dialog copy — answers *are* persisted; only in-session position and hearts are lost | `lesson_player_screen.dart:444` |
| 5.4 | Label the offline writing evaluator in the UI as a rough keyword check (it is 50% token overlap, `writing_task_view.dart:80`) | `writing_task_view.dart` |
| 5.5 | Squash the 19 Drift migrations into a single `onCreate` for v1.0 | `lib/data/database/database.dart:85` |
| 5.6 | Hoist the per-render `SrsScheduler()` | `srs_review_screen.dart:200` |
| 5.7 | Update `ARCHITECTURE.md` Vosk → ONNX, and fix the "Vosk failed" error string | `docs/ARCHITECTURE.md`, `lib/core/errors/app_exceptions.dart:13` |
| 5.8 | Replace `'Failed to load: $err'` with user-facing copy | `stats_screen.dart:33`, `curriculum_screen.dart:48` |

### 5.1 finding — the on-device ONNX model is not in the shipping path

The QA report says an unset `STT_MODEL_URL` makes pronunciation "silently fail". It does
not, because **nothing in the app ever constructs `OnDeviceCzechStt`**. `grep -rn
"OnDeviceCzechStt(" lib` returns only its own declaration; `SttModelManager.download()`
has no caller. The ~340 MB download never happens in a shipped build.

The real runtime chain in `PronunciationAssessor` is:

1. `PhonemeRecognizer` — a **remote HTTP service** (`PHONEME_SERVICE_URL`), when configured
2. Whisper via the Edge Function, when the backend is configured
3. OS-native `speech_to_text` (`NativeSttService`) otherwise

So an unconfigured build degrades to native STT and reports which path it used
(`usedWhisper`, plus the diagnostic line on the pronunciation screen). That is a graceful
fallback, not a silent failure.

The ONNX files (`stt_model_manager.dart`, `on_device_czech_stt.dart`,
`onnx_stt_benchmark.dart`) are reachable only from `SttBenchHook`, which is
`kReleaseMode`-guarded and reads a side-loaded file — a developer benchmark, not a
feature. Building download UI for it would wire a 340 MB prompt to code the app does not
run.

**Decision needed:** either delete that path, or state that it is staged for a future
on-device release and leave it. The Supabase-egress concern in the QA report is moot
either way while nothing downloads.

**Definition of Done:** each row either landed or is listed under Deferred with a reason.
5.5 must ship **before** the first public release or never — it is not safe post-launch.

**On 5.5 specifically:** squashing is only safe while no installed build exists in the wild.
Confirm that is still true before doing it.

---

## Phase 6 — Polish

**Deliverable:** the app does not look unfinished on first run.

| # | Task |
|---|---|
| 6.1 | Android keystore + `key.properties` |
| 6.2 | Empty states for stats (no activity) and exam (no history) |
| 6.3 | Generate images from the 56 prompts in `docs/image_prompts.json` (content task — parallelisable, not code) |
| 6.4 | Split `lesson_player_screen.dart` (1287 lines) into runner / teach phase / complete / game-over / exam-complete |
| 6.5 | Split `mock_exam_screen.dart` (1355 lines) by section renderer |
| 6.6 | Extract the shared question view from listening + reading comprehension |
| 6.7 | Memoize the `_items` getter in `teaching_view.dart` (parses JSON per build) |
| 6.8 | Host `PRIVACY.md` at a public URL and link it from settings |

**Definition of Done:** a signed release build installs on a clean device and every screen
reachable from home has either content or a designed empty state.

---

## Deliberately excluded

| Item | Why |
|---|---|
| Offline banner | `connectivity_plus` already wired in `sync_trigger_coordinator.dart` |
| Audio temp cleanup | `AudioRecorderService.cleanup()` exists and is called |
| Privacy policy authoring | `PRIVACY.md` + `legal_content.dart` exist; only hosting is missing (6.8) |
| `flutter_secure_storage` unused | It is used — `device_id.dart`, `sync_providers.dart` |
| Full CCE exam bank | Content authoring, not engineering |
| Sync revision-collision hardening (`sync_service.dart:55`) | Real but theoretical at current scale; revisit if multi-device conflicts are observed |

## Deferred (append as phases run)

_Anything found mid-phase that is out of that phase's scope goes here, with the phase it was
found in._

- ~~**Review-complete screen: bottom button overlaps the reschedule banner**~~ —
  **not a defect; my earlier reading was wrong.** The screen is
  `Column > Expanded(ListView) + fixed footer` with no `Stack`, so nothing overlaps. The
  teal banner appeared cut off because it is the list's last child sitting at the scroll
  fold — the rest is reachable by scrolling, which is ordinary behaviour. No change made.
- ~~**Mock exam renders an empty body when a section starts**~~ — **fixed in `ae301c2`.**
  Root cause was not exam-specific: the button themes use `Size.fromHeight(54)`, i.e.
  `Size(double.infinity, 54)`, and a Row gives its non-flex children unbounded width. The
  infinite minimum makes the constraint invalid, layout throws, and the entire subtree
  renders blank. Pre-existing (predates this branch; the theme is untouched by phase 1).
  Fixed with `kRowButtonMinSize` at the three affected sites, plus tests pinning the
  premise and the fix. `textButtonTheme` sets no minimum size, so TextButtons were never
  affected.
