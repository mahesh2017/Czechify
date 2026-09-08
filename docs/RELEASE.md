# Release & Store Submission — Czechify

## Build configuration

Every real build needs the Supabase dart-defines, or the backend (sync, AI
tutor, cloud Whisper) is silently disabled:

```
flutter run   --dart-define-from-file=env/prod.json   # or tool/run_prod.sh
flutter build appbundle --release --dart-define-from-file=env/prod.json \
  --obfuscate --split-debug-info=build/symbols
flutter build ipa       --release --dart-define-from-file=env/prod.json \
  --obfuscate --split-debug-info=build/symbols
```

**Keep `build/symbols`.** Obfuscation renames Dart symbols in the AOT snapshot,
so a release stack trace is unreadable without the symbol file from *that exact
build*. `release.yml` uploads them as a build artifact; if you build by hand,
archive them next to the `.aab` before you ship it.

R8 (Kotlin/Java shrinking) runs on its own, and both the R8 mapping and the
native debug symbols are embedded in the bundle, so Play Console symbolicates
Android-side crashes without a manual upload.

`env/prod.json` holds the project URL + **publishable** key (safe to ship in
the client; RLS enforces per-user isolation). Never put the service-role key
here — that lives only in Edge Function secrets.

## CI lanes

- **[ci.yml](../.github/workflows/ci.yml)** — analyze (`--fatal-infos`),
  tests + 80% changed-line coverage, edge-function fmt/lint/type-check + policy
  tests, pgTAP DB tests on a clean reset, multi-platform build smoke.
- **[release.yml](../.github/workflows/release.yml)** — on a `v*` tag: signed
  Android App Bundle + unsigned iOS release build. Configure these repo
  secrets first:
  - `SUPABASE_URL`, `SUPABASE_ANON_KEY`
  - `ANDROID_KEYSTORE_BASE64` (`base64 -i release.jks`), plus
    `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`

Android release signing reads `android/key.properties` (untracked) — see the
header comment in [android/app/build.gradle.kts](../android/app/build.gradle.kts).
iOS signing + App Store upload is done from Xcode (or a Mac runner with certs);
the bundle id `com.eminentsite.czechify` is fixed after first upload.

## Crash reporting — deliberate decision

The Settings → Privacy screen promises **no analytics, advertising, or
crash-reporting SDK**. We honor that:

- Unhandled errors route through `SafeDiagnostics` (see
  [main.dart](../lib/main.dart)), which logs event/type/stack **without** any
  learner text, audio, prompts, or account identifiers.
- Production crash visibility comes from the stores' own vitals (Play Console
  Android Vitals, App Store Connect crash reports) — no third-party SDK, no
  consent banner required.

If a future release adds Sentry/Crashlytics, the privacy copy and the App
Privacy / Data-safety questionnaires **must** change in the same PR.

## Backend deployment — before the app, every time

The app and the Supabase project ship separately, and the app is always the
second one. Several features fail *silently* against an older backend: pushes
land in the outbox retry path, which is invisible by design, and dead-letter
after five attempts. They are recoverable only from the sync-health screen a
learner has no reason to open.

Check what production actually has before assuming anything — the
`mcp__supabase__*` tools and the Supabase CLI both point at **production**
(`twhvcxti…`), not the dev project in `.env`:

```
supabase migration list --linked
```

### 1. Migrations, in timestamp order

`supabase db push --linked` applies them in order. They are ordered by
dependency as well as by name, so do not cherry-pick:

| Migration | Ships with | Breaks without it |
|---|---|---|
| `20260908120000_bound_conversation_summary_quota` | — | Summary quota unbounded |
| `20260908140000_add_tutor_reply_reports` | PR #22 | Reporting: table absent |
| `20260908160000_add_portable_learning_history` | PR #25 | History sync: tables absent |
| `20260908180000_fix_tutor_reply_report_transport` | PR #28 | Reporting: no `device_id`/`updated_at`, no UPDATE grant |
| `20260908200000_allow_staff_report_triage` | — | Nobody can move a report past `new` |
| `20260908201000_preserve_cloud_transfer_completion` | — | The v8 backfill can overwrite a cloud completion with a stale `pending` |
| `20260908202000_export_account_snapshot` | — | `account-data` GET returns 503 |

### 2. Edge functions, after the migrations

```
supabase functions deploy account-data deepseek-proxy
```

`account-data` calls `export_account_snapshot` by RPC, so deploying it before
`20260908202000` breaks account export outright. Migrations first is not a
style preference.

### 3. Smoke the deployed backend, before tagging the app

- **One real tutor turn.** The response schemas carry `minLength`/`pattern` on
  the fields that must not come back blank. Those keywords ride along as a hint
  to the model; OpenAI-style strict structured output does not support them for
  strings, so if the provider *validates* rather than ignores them, every AI
  request returns 502 — chat, writing, grammar and summarization together.
  If that happens, drop them from `answerProperty` in
  [request_policy.ts](../supabase/functions/deepseek-proxy/request_policy.ts):
  `matchesSchema` enforces the same rule server-side, so nothing is lost.
- **File a report** from a tutor reply and confirm the row lands in
  `public.tutor_reply_reports`. This is the Play gate; a silent failure here
  looks exactly like success from inside the app.
- **Export an account** through `account-data` and confirm all 15 tables are
  present. `isCompleteAccountSnapshot` refuses a partial rather than returning
  one, so a missing table is a 503, not a short file.
- **Re-run the advisors** (`get_advisors`) after the DDL. The anonymous-access
  warnings and the `rls_enabled_no_policy` notices on the quota tables are
  expected: anonymous sign-in is deliberate, and RLS-on-with-no-policy is the
  correct deny-all for service-role-only tables.

### 4. Then the app

Bump `pubspec.yaml` (marketing version *and* build number — the build number
must exceed anything Play has already accepted), merge to `main`, and push a
`v*` tag. `release.yml` validates `SUPABASE_URL` against the production host
before it compiles anything, then uploads the signed bundle and its obfuscation
symbols as artifacts. Download and inspect those rather than building locally:
`env/prod.json` is gitignored and its contents live only in Actions secrets.

### First upgrade after a long gap

Schema v8 queues every pre-existing `learning_evidence_events` and
`delayed_transfer_assignments` row, and the outbox sends one request per row.
A learner with months of history will have a long first sync. Prefer a staged
rollout for the release that carries it.

## Store compliance checklist

Done:
- Mic + speech-recognition usage strings (iOS `Info.plist`, Android manifest).
- Account deletion in-app via the `account-data` Edge Function (App Store
  5.1.1(v) / Play data-deletion requirement).
- Real launcher icons + consistent name (Czechify) across all platforms.
- **AI-content reporting** — every tutor reply carries a report action
  (`report_tutor_reply_sheet.dart`), which is what Play's generative-AI policy
  requires. A report is written locally and pushed through the sync outbox to
  `public.tutor_reply_reports`, where it is triaged (see the review query in
  that table's comment). `kSupportEmail` is now only the fallback for when the
  local write itself fails, and remains the single source of truth shared with
  the public pages.

  **This depends entirely on the backend being deployed.** With the migrations
  unapplied, every push is rejected, retried and dead-lettered while the sheet
  tells the learner the report is on its way — a policy control reporting
  success while doing nothing. Never ship the app ahead of the database.
- Support address published in the in-app policy and both pages under
  `docs/site/`.
- 16 KB page alignment verified across all four ABIs (required for new
  submissions since November 2025).

Before submission:
- [ ] **Replace the test upload keystore.** `android/key.properties` currently
      points at `czechify-test-release.jks` (`CN=Czechify Test`). Whatever key
      signs the first upload is permanent for `com.eminentsite.czechify`.
      Generate the real one, back it up somewhere durable, enrol in Play App
      Signing, and update the `ANDROID_KEYSTORE_*` repo secrets:
      ```
      keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias upload
      ```
- [ ] Host the privacy policy and account-deletion page from
      [docs/site](site/README.md) — enable GitHub Pages with the **GitHub
      Actions** source — then enter both public URLs in Play Console. The policy
      already discloses that audio leaves the device for cloud Whisper STT.
- [ ] Confirm `email.czechify@gmail.com` is monitored before launch. It is the
      published route for data requests, deletion requests, and AI-content
      reports.
- [ ] App Privacy (iOS) + Data safety (Play) questionnaires — declare audio
      upload for transcription; no tracking; data used for app functionality.
      **Update, do not merely review:** in-app reporting now sends the reported
      tutor reply and the learner's free-text note to the backend. That is
      user-generated content leaving the device and was not previously
      declared.
- [ ] Enable Supabase Auth "leaked password protection" (Dashboard →
      Authentication) — the one remaining P1 advisor, dashboard-only.
- [ ] Age rating, screenshots, store descriptions.
- [ ] Verify the anonymous-user cleanup is actually *running* in production.
      The migration (`20260724155330_schedule_anonymous_user_cleanup`) is
      applied; confirm the `cron.job` row exists and has recent entries in
      `cron.job_run_details`, so orphaned accounts do not accumulate.
- [ ] Run the closed-test track if this is a newly created personal Play
      developer account: 12 testers opted in continuously for 14 days.

## Dependency currency

Upgraded 2026-07-24 (analyzer + 242 tests + device build all green):
- Drift ecosystem: `drift`/`drift_dev` 2.20 → 2.34, `sqlite3` 2.7 → 3.5,
  `sqlite3_flutter_libs` 0.5 → 0.6 (clears the EOL flag; codegen regenerated).
- Runtime majors: `go_router` 14 → 17, `record` 6 → 7, `just_audio` 0.9 → 0.10,
  `connectivity_plus` 6 → 7, `flutter_secure_storage` 9 → 10, `share_plus`
  12 → 13 — all API-compatible with our usage, verified on a release device
  build (audio recording + navigation exercised).
- `flutter_lints` 4 → 6. Two brand-new stylistic rules
  (`use_null_aware_elements`, `unnecessary_underscores`) are opted out in
  `analysis_options.yaml` pending a dedicated cleanup; the drift `dispose` →
  `close` deprecation was fixed.

`intl` is pinned `any` to track the Flutter SDK's bundled version. Remaining
behind-but-fine transitives (win32, xml, etc.) carry no security advisories.
