# Production Readiness Plan — 2026-07-24

> **Status update (same day):** all P0 items are **done**. P0.1 Whisper
> quotas (deployed + verified), P0.2 Pronunciation Lab practice deck,
> P0.3 exam checkpoint/resume, P0.4 branding standardized on **Czechify**
> (real launcher icons generated for iOS/Android/macOS/Windows from
> `assets/images/app_icon.png`; desktop product names fixed), P0.5
> diagnostics gated to debug builds. Also fixed: declension/conjugation
> reference tables rendered empty (renderer expected a `rows` schema no
> asset had).
>
> **Phase 2 done:** P1.1 chat retry chip (replays the tutor call without
> retyping), P1.2 "continue where you left off" list in the scenario picker
> (scenario + level restored on resume), P1.3 Czech-voice availability hint
> on Home, P1.4 router errorBuilder + tryParse redirect, P1.5 per-task
> speaking caps (read-aloud 15 s / prompted 30 s / open 45 s), P1.8
> `stamp_sync_revision` search_path pinned (migration applied + trigger
> verified live). Also fixed: fill-blank sentences broke into separate
> paragraphs around the input box (word-level Wrap tokens now; blank width
> sized to the expected answer).
>
> **Phase 3 done:** P1.13 accessibility labels on the record button, score
> ring, and word chips (correctness now shown by icon + color, not color
> alone; hearts/streak labeled), P1.14 dark-mode sweep of hardcoded greys on
> the pronunciation/exam/reference/home screens (routed through theme
> tokens), P1.15 i18n foundation (`gen-l10n` wired into MaterialApp + ARB
> files; Pronunciation Lab fully localized as the working template), P1.18
> crash-reporting decision — **honor the "no SDK" privacy promise** (rely on
> `SafeDiagnostics` + store vitals; documented in RELEASE.md), P1.19
> tagged-release CI lane (release.yml) + RELEASE.md with the store-submission
> checklist and dependency-upgrade plan.
>
> **Phase 4 done (hardening):** P1.20 dependency-upgrade pass (drift/sqlite3
> ecosystem + go_router/record/just_audio/connectivity_plus/secure_storage/
> share_plus/flutter_lints majors — analyzer + 242 tests + device build all
> green), P1.11 anonymous-user cleanup (pg_cron daily purge of never-linked
> accounts idle 90+ days, self-healing), P1.12 DB hygiene (both unindexed FKs
> now covered — verified cleared in the advisor; service-role counter tables
> documented). Privacy policy corrected to disclose OpenAI Whisper audio, and
> a copy-paste store data-safety answer sheet added (STORE_DATA_DISCLOSURE.md).
>
> **The only items left require account access I don't have — both prepared:**
> 1. **Leaked-password protection** — a GoTrue auth-config toggle with no SQL
>    or API surface I can reach. Flip it at Supabase Dashboard → Authentication
>    → Policies → "Enable HaveIBeenPwned check" (or Sign In / Providers → Email
>    → password protection). ~2 clicks.
> 2. **Store submission** — host PRIVACY.md at a public URL, then paste the
>    answers from STORE_DATA_DISCLOSURE.md into App Store Connect App Privacy
>    and Play Console Data safety. Everything to enter is written out.
>
> **Accepted-by-design advisors (documented, not defects):** 6× anonymous-access
> policy WARNs (the app is anonymous-first — restricting to `authenticated`
> would break real users) and 3× RLS-enabled/no-policy INFOs on the
> service-role counter tables (deny-all-to-clients is the intended state).

Full-codebase review (app + Supabase backend) covering functionality, UI/UX,
security, and release operations. Scope: `lib/` (~26.8k lines, 155 files),
`supabase/` (3 edge functions, migrations), CI, and platform configs.

**Baseline health:** `flutter analyze` clean · 232/232 tests pass · CI enforces
80% changed-line coverage, pgTAP RLS tests, edge-function type checks, and
multi-platform build smoke. The architecture (clean layers, offline-first,
server-side API keys) is sound. What follows are the gaps between "works" and
"production."

---

## P0 — Must fix before any public release

### P0.1 `whisper-proxy` has no usage quota (cost-abuse hole)
`deepseek-proxy` enforces per-user burst + daily quotas via
`consume_ai_burst_quota` / `consume_ai_quota`. `whisper-proxy`
([index.ts](../supabase/functions/whisper-proxy/index.ts)) enforces only input
shape (size cap, language allowlist) — **zero rate/spend limits**. Anonymous
sign-ups are open and the publishable key ships in the binary, so anyone can
script unlimited Whisper minutes against your OpenAI bill.
- **Fix:** reuse the existing quota RPCs (or add `consume_ai_quota` with a
  separate `whisper` bucket keyed on audio seconds) before the OpenAI call;
  return 429 with a friendly message the client already knows how to render.
- **Acceptance:** pgTAP test proving the quota trips; client shows the limit
  message and falls back to on-device STT.

### P0.2 Pronunciation Lab ignores its exercise id
`/pronunciation/:id` routes into
[pronunciation_screen.dart](../lib/presentation/screens/pronunciation/pronunciation_screen.dart)
which declares `exerciseId` but never reads it — every entry practices the
hardcoded `'Ahoj, jak se máš?'` unless a caller passes `expectedText`. The lab
is effectively a single-phrase demo.
- **Fix:** resolve the exercise text from the curriculum repository by id (fall
  back to a curated phrase list when id is unknown); add a phrase picker /
  "next phrase" progression so the lab has replay value.
- **Acceptance:** widget test that a given id renders its own phrase.

### P0.3 Mock exam loses all progress on process death
[mock_exam_screen.dart](../lib/presentation/screens/exam/mock_exam_screen.dart)
persists only the final `ExamResult`. A 30+ minute CCE mock exam killed by iOS
memory pressure, a phone call, or an accidental swipe loses everything —
the single most rage-inducing failure mode the app can have.
- **Fix:** checkpoint answers + remaining time to the DB per question (a small
  `exam_sessions` table or `user_progress` keys); offer "Resume exam?" on
  re-entry; discard checkpoints on submit.
- **Acceptance:** kill the app mid-exam in an integration test, relaunch,
  resume with answers and timer intact.

### P0.4 Store identity is placeholder
- Launcher icons are the default Flutter logo (442-byte `ic_launcher.png`).
- Naming is inconsistent: UI + platform manifests say **Czechify**,
  pubspec/repo say **czechify / Čeština Pro**, bundle id is
  `com.ceskinapro.czechify`.
- **Fix:** decide the brand name once; align `CFBundleDisplayName`,
  `android:label`, MaterialApp `title`, and store listings; generate real
  icon + adaptive icon + splash (e.g. `flutter_launcher_icons`,
  `flutter_native_splash`). Bundle id cannot change after first store upload —
  confirm it now.

### P0.5 Remove debug diagnostics from learner-facing UI
The engine-diagnostic footer ("cloud Whisper (4.4s)", "on-device (cloud error:
ClientException …)") in the pronunciation screen leaks raw exception strings
and URLs to end users. Same for `Heard: "…"` phrasing choices.
- **Fix:** gate diagnostics behind a developer toggle in Settings (or
  `kDebugMode`); map failures to human copy ("Using on-device recognition —
  results may be less accurate").

---

## P1 — High priority (quality bar for a paid/public app)

### Functionality

1. **Chat has no retry affordance.** On `LlmServiceException` the error string
   renders but the user's message can't be re-sent without retyping
   ([chat_providers.dart](../lib/presentation/providers/chat_providers.dart)).
   Add a "Try again" chip that replays the last user message; keep the composer
   populated on failure.
2. **Conversation history is not resumable from the UI.**
   `loadConversation()` exists but nothing lists past conversations. Either
   surface a history list or drop the dead code and the `conversations` table
   growth.
3. **Czech TTS availability is never verified.**
   [tts_providers.dart](../lib/presentation/providers/tts_providers.dart) sets
   `cs-CZ` fire-and-forget. Devices without a Czech voice fail silently — a
   language app where "listen" does nothing. Check
   `isLanguageAvailable('cs-CZ')` once, surface a one-time banner linking to
   the OS voice-install settings.
4. **Router robustness.** `int.parse(state.pathParameters['id']!)` in
   [app_router.dart](../lib/presentation/routes/app_router.dart) throws on a
   malformed deep link; there is no `errorBuilder`/404 route. Use
   `int.tryParse` + redirect home, add `errorBuilder`.
5. **Recording cap vs exam speaking tasks.** `maxDuration` is 10 s for
   pronunciation; verify speaking-task flows (CCE requires longer utterances)
   use an appropriate cap, and surface remaining time visually while
   recording.
6. **Edge-function deploy drift.** `whisper-proxy` v3 was deployed from a
   working tree; nothing pins deployed code to git. Add
   `supabase functions deploy` to a release workflow (CI already type-checks
   the sources) so the repo is always the source of truth.

### Backend / security (from Supabase advisors, 2026-07-24)

7. **Enable leaked-password protection** in Auth settings (advisor WARN).
8. **Pin `search_path`** on `public.stamp_sync_revision` (advisor WARN,
   `SECURITY DEFINER` hygiene).
9. **`public.ai_daily_usage` / `private.ai_burst_usage`: RLS enabled, no
   policies.** Intentional (service-role only) — add an explicit
   deny-all-comment or pgTAP assertion so the linter finding is documented,
   not ignored.
10. **Anonymous-access advisor WARNs** on the owner-scoped tables are by
    design (anonymous-first product). Document the decision in
    `supabase/README.md` so future reviews don't re-litigate it.
11. **Anonymous user hygiene:** 11 anonymous users already exist from testing.
    Decide a cleanup policy (Supabase ships a scheduled cleanup for anonymous
    users ≥30 days old) so orphaned rows don't accumulate forever.
12. **Performance advisor INFOs:** add covering index for
    `content_release_items` composite FK; re-check the three "unused index"
    findings after real traffic before dropping.

### UI/UX

13. **Accessibility is essentially absent.** One `Semantics` usage in the whole
    presentation layer. Minimum bar: semantic labels on the record button, TTS
    speaker buttons, score ring (`"Score: 91 percent"`), hearts/XP indicators;
    word-score chips must not encode correct/incorrect by color alone (add
    icon or underline); verify every screen at 1.3× and 2.0× text scale (the
    score-ring `FittedBox` fix from today is the pattern to reuse).
14. **Dark-mode audit.** 221 hardcoded `Colors.*` references bypass the theme
    (e.g. `Colors.grey` captions, `Colors.orange.shade100` chips on the
    pronunciation screen). Sweep screens in dark mode; route colors through
    `ColorScheme`/`app_tokens.dart`.
15. **Language of the UI is undecided.** Chrome is English, feedback strings
    are Czech ("Skvělé!", "Zkuste znovu"), content is Czech. Fine for a
    personal app; for production pick the learner language(s), move strings to
    `flutter gen-l10n` ARB files now (retrofitting i18n later across 155 files
    is far more expensive).
16. **Loading/latency UX for AI features.** Chat waits on a full DeepSeek
    completion with a spinner; consider the existing `streamComplete` seam +
    server-sent streaming later, but at minimum add a typing indicator and
    keep suggested replies visible while loading.
17. **Empty/first-run states.** Audit Home, Stats, Review for the zero-data
    case (new user, day one) — a stats page of zeros should sell the journey,
    not look broken.

### Release operations

18. **Crash reporting is a product decision, not an accident.** The Settings
    privacy screen promises "No analytics, advertising, or crash-reporting
    SDK." Honor it (rely on `SafeDiagnostics` + store-vitals crash logs) or
    change the promise and add Sentry/Crashlytics with consent copy. Decide
    explicitly; today it's implicit.
19. **Release pipeline.** CI builds debug binaries only. Add a tagged-release
    lane: versioned `flutter build appbundle` / `ipa` with the release
    keystore (docs for `key.properties` exist in the gradle file, the keystore
    process is undocumented), changelog, and store upload (fastlane or
    codemagic).
20. **Dependency currency.** 49 packages outdated; notably
    `sqlite3_flutter_libs 0.5.x` (0.6 is marked end-of-line — plan the drift
    migration path), `go_router` 14→17, `flutter_lints` 4→6,
    `speech_to_text`/`record` majors. Schedule one upgrade sprint; the strong
    test suite makes this cheap.
21. **Store compliance checklist.** Mic + speech-recognition permission
    strings exist (good); account deletion via `account-data` exists (good —
    App Store 5.1.1(v)). Still needed: privacy policy URL, App Privacy /
    Data-safety questionnaires (declare audio-leaves-device for cloud STT),
    age rating, screenshots.
22. **Config files.** `env/prod.json` (publishable key — safe to commit) and
    `.vscode/launch.json` are currently untracked; commit them so every
    checkout builds a working app, and note the staging override pattern.

---

## P2 — Polish / nice-to-have

- **Pronunciation depth:** per-phoneme feedback currently maps "other" for
  many sounds (visible as `other in "ahoj"` chips — confusing copy). Either
  hide unknown-phoneme rows or finish the phoneme mapper coverage for the
  Czech inventory (ř, ě, ů, ch).
- **Whisper payload efficiency:** base64-JSON adds ~33% upload weight; a
  multipart or Storage-upload path would cut latency on slow cellular.
- **Haptics/sound feedback** on answer submit, streak events.
- **iPad/desktop layout pass** — `AdaptiveScaffold` exists; verify large
  breakpoints, keyboard navigation on macOS/Windows targets.
- **Onboarding value:** placement test exists; consider letting users skip and
  sample a lesson first (activation funnel).
- **Sync observability:** surface "last synced" + pending-outbox count in
  Settings; today sync failures are silent by design.
- **Performance baseline:** measure cold-start (content seeding on first run)
  on a low-end Android device; add a startup trace to CI if it exceeds ~3 s.

---

## Suggested execution order

| Phase | Contents | Outcome |
|-------|----------|---------|
| 1. Stop the bleeding (days) | P0.1 quota, P0.5 diagnostics gate, P1.7–9 auth/db advisors | Safe to hand builds to testers |
| 2. Core UX debt (1–2 weeks) | P0.2 lab content, P0.3 exam resume, P1.1–5 chat/TTS/router | Feature-complete learning loop |
| 3. Production posture (1 week) | P0.4 branding/icons, P1.13–15 a11y/dark/i18n foundations, P1.18–19 crash + release lanes | Store-submittable build |
| 4. Hardening (ongoing) | P1.20 upgrades, P1.11–12 db hygiene, P2 items | Sustainable maintenance |

Phases 1 and 2 are the true gate: P0.1 is a financial risk today, and P0.2/P0.3
are the two places a paying learner would hit a wall. Everything in Phase 3 is
mechanical once decided (name, crash-reporting stance, UI language).
