# Google Play launch audit — Czechify

**Date:** 2026-08-14 · **Branch:** `fix/audit-phases-1-2` · **Build tested:** signed release AAB, 148.0 MB

## Verdict

**Security is not what is holding this back.** The client and backend are hardened
to a standard well above the median Play submission — I tried to break the proxies,
the RLS, the sync path, and the audio cache, and found nothing exploitable.

What blocks submission is four items in the store/policy layer, none of them large.

> **Status, 2026-08-14:** the code-side items (B1, B2, S1, S2, S3) are done and
> verified — see *Fixed in this pass* at the bottom. What remains is B3, B4, S4,
> S5, and the closed-test clock: all of them are actions in a console or a
> keystore, none of them things a commit can do.

---

## Blockers — do these before you upload

### ~~B1. No way for a user to report offensive AI output~~ — done

Play's **Generative AI policy** requires apps that produce AI-generated content
to give users an in-app path to flag offensive output.

**Fixed.** Every tutor bubble now carries a flag button opening
`report_tutor_reply_sheet.dart`: five plain-language reasons, an optional note,
and a mailto handoff to the support address, with a visible fallback if no mail
app opens. The report carries the tutor's reply and the scenario, never the
learner's own messages — pinned by tests. Answer **yes** to the AI-content
question in the Console.

### ~~B2. Privacy policy has no contact address~~ — done

**Fixed.** `email.czechify@gmail.com` is now published in the in-app policy,
`privacy.html`, and `delete-account.html`, sourced from one constant
(`kSupportEmail`) so the three cannot drift. The deletion page no longer routes
users to a GitHub issue.

**Still yours to do:** make sure that mailbox is actually monitored before
launch — it is the published route for data requests, deletion requests, and AI
reports.

### B3. The release keystore is a test key

`android/key.properties` points at `czechify-test-release.jks`, alias
`czechify-test`, `CN=Czechify Test, OU=Testing`. It is valid to 2053 and signs
fine — that is the problem. Whatever key signs the first upload becomes the
permanent upload key for this package name.

**Fix:** run [`tool/make_upload_keystore.sh`](../tool/make_upload_keystore.sh).
It prompts for the password with `read -s` and passes it to keytool through the
environment, so the secret never reaches a shell history, a process list, or a
transcript — which is the reason this is a script you run rather than something
done for you. It writes `android/key.properties`, prints the fingerprint, and
lists the backup and Play App Signing steps.

### ~~B4. The public pages are not hosted yet~~ — I got this wrong; they are

**Correction.** I filed this from the unchecked box in `docs/RELEASE.md` without
checking the world. Pages is enabled with the GitHub Actions source, the
workflow has run green, and both URLs serve 200 today:

- https://mahesh2017.github.io/Czechify/privacy.html
- https://mahesh2017.github.io/Czechify/delete-account.html

The repo is public, so the old GitHub-issue contact route was at least reachable
— it was the wrong channel, not a dead link.

What is actually left: the **live pages still serve the old text**, because the
fixes are on `fix/audit-phases-1-2`. `pages.yml` triggers on pushes to `main`
touching `docs/site/**`, so merging republishes them automatically. Verify the
contact line says `email.czechify@gmail.com` before pasting the URLs into
Console.

---

## Should fix

### ~~S1. ~6.6 MB of dead native code ships on every device~~ — done

`flutter_onnxruntime` put `libonnxruntime.so` + `libonnxruntime4j_jni.so` in
every ABI for code nothing constructed.

**Fixed.** Removed the dependency, the four source files, `assets/stt/vocab.json`,
and the `main.dart` hook. `test/ctc_decode_test.dart` went with them — it was a
standalone reimplementation of the deleted decode, asserting nothing about the
app. Git history keeps all of it if the feature comes back.

### ~~S2. Dart obfuscation is off~~ — done

**Fixed.** `--obfuscate --split-debug-info=build/symbols` is now in
`docs/RELEASE.md` and both jobs in `release.yml`, which uploads the symbols as a
90-day artifact. **Keep those symbol files** — a release stack trace is
unreadable without the ones from that exact build.

### ~~S3. `android:allowBackup="true"`~~ — done

**Fixed.** Set to `false`. Behaviour was already correct via the exclusion rules;
this closes the pre-API-31 path by construction rather than by configuration.

### S4. Two backend items still open from your own checklist

- Supabase Auth → **leaked password protection** is still off.

  The local CLI is authenticated and can see the `Czechify` project
  (`pxhjcazremdnsdzpeajo`), and `supabase config push` exists — but **do not use
  it for this**. `supabase/config.toml` contains only `[functions]` blocks, so a
  push would apply CLI-default `[auth]` settings to production and could reset
  the site URL, redirect URLs, JWT expiry, and email templates. One dashboard
  toggle is genuinely the smaller change here.

- `20260724155330_schedule_anonymous_user_cleanup.sql` needs applying to the
  production project, and it requires `pg_cron` to be enabled there.

  `supabase db push --linked` would do it, but both `link` and `db push` want
  the production Postgres password. Preview first, then apply:

  ```
  supabase link --project-ref pxhjcazremdnsdzpeajo
  supabase db push --linked --dry-run
  ```

### S5. Data safety form — one answer people get wrong

Audio is transient, but Play still counts sending it to Whisper as **collected**.
`docs/STORE_DATA_DISCLOSURE.md` already says this correctly; copy it verbatim
rather than re-deriving the answers in the Console UI.

### S6. 154 utterances have no recorded clip, and the app blames the network

4.3% of the curriculum's 3,542 utterances are absent from `manifest.json` for
both voices, and 143 male / 154 female have no file on disk either. Whenever a
neural clip cannot be played for **any** reason, `CzechTts` sets
`usingFallbackVoice` and `DegradedModeBanner` says "Offline — using your
device's voice. Connect to hear the recorded Czech voice." So these utterances
show an offline notice on a perfect connection, then speak in the device voice
— which is what a tester reported as the banner appearing too often.

`tool/regenerate_short_male_clips.py` repairs 39 of the male ones as a side
effect of the pacing work. The remaining 104 male need an ElevenLabs run and
all 154 female an Azure one. Separately, the banner's wording should not
attribute a missing recording to connectivity.

---

## Nice to have

- **Images are 43 MB** of the 44 MB asset payload, with several 2–3 MB PNGs
  (`review_empty_v2.png`, `onboarding_hero_v2.png`, `copybook_hero_v1.png`).
  WebP would cut the download noticeably.
- ~~**A few `debugPrint` calls survive in release.**~~ Gone with S1. The only one
  left in `lib/` is the logger sink in `main.dart`, which is gated to WARNING and
  above in release and fed exclusively by `SafeDiagnostics`.
- **Closed testing**: if this is a newly created personal developer account, Play
  requires 12 testers opted in continuously for 14 days before production access.
  Start that clock early; it is the longest pole in the whole list.

---

## Verified clean — no action needed

Recording these so nobody re-audits them later.

**Build and store mechanics**
- 588 Dart tests pass; `flutter analyze` reports 0 issues.
- Signed AAB builds end to end. Estimated arm64-v8a download **62.5 MB** against
  Play's 200 MB cap.
- **16 KB page alignment: all native libraries pass** (every `PT_LOAD` ≥ 0x4000
  across all four ABIs) — this is the November 2025 requirement, and
  `libonnxruntime.so`, the one most likely to fail, is compliant.
- `targetSdk 36` / `minSdk 24`; Play's floor is 35.
- R8 ran: `mapping.txt` produced, and both the obfuscation map and native debug
  symbols are embedded in the AAB, so Play Console gets readable crash reports
  without a manual upload.
- Permissions are minimal and all justified: `RECORD_AUDIO`, `INTERNET`,
  `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, plus `ACCESS_NETWORK_STATE` and
  `VIBRATE` from plugins. Notifications use `AndroidScheduleMode.inexact`, so no
  exact-alarm permission is requested — that avoids a Console declaration entirely.

**Secrets**
- No secret is in the repo or the client. `env/prod.json` carries only the
  publishable key, which is what RLS is for. DeepSeek and OpenAI keys exist only
  as Edge Function secrets. `.env` is untracked and has never been committed.

**Edge functions** (`deepseek-proxy`, `whisper-proxy`, `account-data`)
- JWT verified server-side on every call; `verify_jwt = true` in `config.toml`.
- Per-user and per-project burst windows plus daily caps, all consumed *after*
  input validation, with refunds on any post-consumption failure.
- CORS denies by default and never emits `*`; matching is exact, `Vary: Origin`
  always set.
- Upstream status codes are never echoed to the client.
- Request bodies are bounded (messages ≤ 24 / 4 000 chars / 12 000 total; context
  values ≤ 2 000; audio base64 ≤ 14 MB with a charset check).
- System prompts explicitly instruct the model to treat learner text as data,
  not instructions.

**Database**
- RLS on every sync table, owner-scoped via `auth.uid()`.
- Quota tables revoked from `anon`/`authenticated` entirely; quota functions are
  `SECURITY DEFINER` with `set search_path = ''` and granted only to
  `service_role`.
- Check constraints on every user-writable column; a trigger enforces
  last-write-wins at the database boundary rather than trusting the client.

**Client**
- Supabase session and PKCE verifier live in Keychain/Keystore, with a migration
  off the package's SharedPreferences default.
- Account deletion is in-app (`Settings → Account & data`) and server-side:
  confirmation header, a recent-auth freshness gate, global session revocation,
  then user deletion cascading to all sync rows. Data export exists alongside it.
- Downloaded audio verifies SHA-256 before use, and remote filenames are
  validated before becoming local paths — no traversal.
- The self-hosted phoneme recogniser refuses any non-HTTPS URL rather than
  sending voice in the clear.
- Cloud speech is **off by default** and gated behind an explicit dialog naming
  OpenAI, the United States, and a 16+ age requirement — this satisfies Play's
  prominent-disclosure rule for microphone data.
- `SafeDiagnostics` allowlists what it logs, so no learner text, audio, prompt,
  or account id can reach a log line.

---

## Fixed in this pass

All verified with `flutter analyze` clean and the full suite green (586 tests,
including 8 new ones covering the report flow).

| Item | Change |
|---|---|
| B1 | Report action on every tutor reply → `lib/presentation/widgets/chat/report_tutor_reply_sheet.dart`, wired into `_MessageBubble`; `url_launcher` added as a direct dependency; `<queries>` entry for `mailto` so package visibility does not hide mail apps on API 30+ |
| B2 | `kSupportEmail` in `legal_content.dart`, published in the in-app policy, `privacy.html`, and `delete-account.html`; both pages stop routing users to a GitHub issue |
| S1 | `flutter_onnxruntime`, 4 source files, `assets/stt/`, the `main.dart` hook, and the orphaned `ctc_decode_test.dart` removed |
| S2 | `--obfuscate --split-debug-info` in `RELEASE.md` and both `release.yml` jobs, with symbols uploaded as a 90-day artifact |
| S3 | `android:allowBackup="false"` |

Rebuilt and re-measured afterwards, obfuscated:

- Estimated **arm64-v8a download: 55.0 MB**, down from 62.5 MB.
- 16 KB page alignment re-verified across all 15 shipped libraries — still clean.
- No library ships DWARF debug sections. `gen_snapshot` warns about
  unobfuscated DWARF during the build; AGP's strip step removes it before
  packaging, so the warning describes an intermediate artifact, not the bundle.
- Assets are now 44 MB of the 55 MB, so the WebP conversion below is what is
  left if the download size ever needs to come down further.

### Two production bugs CI found on the way

Neither was visible from reading the code — the functions exist, are granted,
and are called. Only exercising them as the real role shows it, which is what
`quota_refunds.test.sql` does. It failed the first time it ever ran in CI.

**The quota refunds have never refunded anything.** `20260803120000` fixed the
table names they were written against but kept a `current_user <> 'service_role'`
guard. In a `security definer` function `current_user` is the function owner,
not the caller, so it rejects every call — including the only caller there is.
This was the third appearance of that defect: fixed for `consume_ai_quota` in
`20260719182220`, for `consume_service_daily_quota` in `20260724150803`, then
reintroduced when the refund functions were written from the older template.
The Edge Functions only `console.error` a failed refund, so every learner who
hit a DeepSeek timeout or a Whisper error kept losing a unit of allowance,
silently. Authorization now rests on the EXECUTE grants, as it does for both
`consume_*` functions.

**The AI allowance would never have displayed.** `service_role` was never
granted anything on `ai_daily_usage`. The proxy reads that counter directly to
report remaining turns and PostgREST runs the read as `service_role`, so it
returned permission denied, `remaining_today()` swallowed it, and the client
showed nothing. The sibling table added later got this right — which is why the
pronunciation allowance works and the tutor one does not.

Both fixed in `20260814120000` and `20260814120100`. 56 pgTAP tests and
`db lint` pass on a clean reset.

The in-app policy gained a paragraph on reporting AI replies, and
`kPrivacyPolicyVersion` was deliberately **not** bumped: publishing a contact
address and describing an existing safety route does not change what a learner
agreed to, and bumping it would re-prompt every existing user for no reason.
