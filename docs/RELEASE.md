# Release & Store Submission — Czechify

## Build configuration

Every real build needs the Supabase dart-defines, or the backend (sync, AI
tutor, cloud Whisper) is silently disabled:

```
flutter run   --dart-define-from-file=env/prod.json   # or tool/run_prod.sh
flutter build appbundle --release --dart-define-from-file=env/prod.json
flutter build ipa       --release --dart-define-from-file=env/prod.json
```

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

## Store compliance checklist

Done:
- Mic + speech-recognition usage strings (iOS `Info.plist`, Android manifest).
- Account deletion in-app via the `account-data` Edge Function (App Store
  5.1.1(v) / Play data-deletion requirement).
- Real launcher icons + consistent name (Czechify) across all platforms.

Before submission:
- [ ] Configure Android upload signing (`android/key.properties` locally or the
      release workflow secrets) and build a production `.aab` successfully.
- [ ] Host the privacy policy and account-deletion page from
      [docs/site](site/README.md), then enter both public URLs in Play Console.
      The policy must disclose that audio leaves the device for cloud Whisper
      STT.
- [ ] App Privacy (iOS) + Data safety (Play) questionnaires — declare audio
      upload for transcription; no tracking; data used for app functionality.
- [ ] Enable Supabase Auth "leaked password protection" (Dashboard →
      Authentication) — the one remaining P1 advisor, dashboard-only.
- [ ] Age rating, screenshots, store descriptions.
- [ ] Apply and verify the anonymous-user cleanup migration in the production
      Supabase project so orphaned accounts do not accumulate.
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
