# Entitlement backend: staging setup

Signed access documents, phase-specific placement, server purchase verification, Play notifications, a billing worker and Android checkout are implemented through PR 3c. Referral database operations are added in 4a; see [REFERRAL_BACKEND.md](REFERRAL_BACKEND.md). Referral Integrity/intake/client integration and course paywall enforcement remain later work. All `/configuration` activation switches return false.

## Deployment order

1. Apply the complete forward migration chain for the chosen release to a dedicated staging Supabase project, including its billing and referral migrations. The phase-ceiling migration must precede the entitlement schema. New clients send `phase_ceilings`, so deploy the backend migration before distributing the updated app. Old clients remain compatible after the migration. Referral campaign dates remain unset and its controls disabled until verified intake and the client flow are complete.
2. Provision an Ed25519 signing key in your secret manager. Set `MONETIZATION_SNAPSHOT_PRIVATE_JWK` (private OKP JWK, `crv=Ed25519`) and `MONETIZATION_SNAPSHOT_KEY_ID` for the `monetization-api` function. Never commit the private key or place it in Flutter configuration.
3. Put only the corresponding raw 32-byte public key, base64url encoded, in the app's `MONETIZATION_SNAPSHOT_PUBLIC_KEYS` Dart define: a JSON map of key ID to public key. The default is an empty map, so unconfigured builds cannot accept any signed entitlement. Never use the committed test vector key in a deployed environment.
4. Deploy `monetization-api` with Supabase gateway JWT verification enabled. Its handler also verifies the JWT through Auth and derives the account from the verified user. `GET /entitlements` returns `snapshot_jws`; caller-selected account IDs are rejected, and the purchase routes below derive the account the same way.
5. Test two different staging accounts, the owner-only projections, account switch/rollback, export/deletion, signature rejection, offline expiry and key rotation before enabling any acquisition flow.
6. For purchase verification (PR 3a), also set these `monetization-api` secrets. Until all five exist the purchase routes return `503` and nothing else changes.
   - `MONETIZATION_TOKEN_KEY`: 32 random bytes, base64. Encrypts stored purchase tokens (AES-256-GCM). Losing it strands stored tokens; rotation needs a re-encryption job.
   - `BILLING_ACCOUNT_HMAC_KEY` and `BILLING_ACCOUNT_HMAC_VERSION`: 32 random bytes, base64, and a positive integer. Derive each account's Play `obfuscatedAccountId`. The first derived value per account is frozen in the database, so rotating the key only affects accounts that have never started checkout.
   - `PLAY_PACKAGE_NAME`: the Android application ID.
   - `PLAY_SERVICE_ACCOUNT_JSON`: a Google Cloud service-account key with access to the app in Play Console (financial data and order management).
7. Products ship disabled. Enable them per project with the service-only `set_billing_product_enabled('czechify_core', true)` and `set_billing_product_enabled('czechify_ai', true)` after the Play Console products and `monthly` base plans exist.

8. For notifications and the worker (PR 3b), deploy `play-billing-notifications` and `monetization-worker`. Both run with gateway JWT verification off (`config.toml`) and authenticate callers themselves.
   - Create a Pub/Sub topic, grant `google-play-developer-notifications@system.gserviceaccount.com` the Publisher role on it, and set it as the app's real-time notification topic in Play Console.
   - Create a push subscription to `https://<project>.supabase.co/functions/v1/play-billing-notifications` with authentication enabled, using a dedicated service account and an explicit audience. Set `PLAY_PUSH_AUDIENCE` and `PLAY_PUSH_SERVICE_ACCOUNT` on the function to those exact values, plus `PLAY_PACKAGE_NAME`. If any is missing, every push is refused with `401`.
   - Give `monetization-worker` the billing secrets from step 6 plus `BILLING_WORKER_SECRET` (at least 32 random characters). Without all of them it refuses every call.
   - Schedule the worker every minute. With `pg_cron` and `pg_net`, keeping the URL and secret in Vault:

     ```sql
     select cron.schedule('billing-worker', '* * * * *', $$
       select net.http_post(
         url := (select decrypted_secret from vault.decrypted_secrets where name = 'billing_worker_url'),
         headers := jsonb_build_object('x-worker-secret',
           (select decrypted_secret from vault.decrypted_secrets where name = 'billing_worker_secret')),
         timeout_milliseconds := 55000);
     $$);
     ```

     This is deliberately not a migration: the URL and secret differ per project. Confirm in staging that the job runs, by watching `billing_health()` and the function logs.

No production project or Store configuration was changed by implementation.

## Purchase verification (PR 3a)

- `POST /purchase-intents` and `POST /purchases/verify` require a linked (non-anonymous) account. Verification looks the token up by SHA-256 digest; a token already recorded for another account, or for a deleted account, is refused with `account_binding_mismatch` and never reassigned.
- Play's `obfuscatedExternalAccountId` must equal the owner's frozen binding. A purchase without it (for example, redeemed outside the app) is not provisioned and needs support.
- Each verification or acknowledgement is a job with a lease and a fencing number. Only the current lease holder can apply a result, and only one job per purchase lineage runs at a time. Acknowledgement jobs are created by the provisioning transaction, so Play is never acknowledged for access that was not committed.
- Failed jobs back off (5 s doubling to 1 h, or Play's `Retry-After`) and keep the last verified entitlement. The PR 3b worker retries them in the background once its scheduler is configured; verify and restore can also drive processing.
- `billing_integration_test.ts` runs the real handler and RPC wiring against a local stack with Play faked; its header shows how to run it.


## Schema and operation boundaries

- `monetization_accounts`, `course_unit_grants` and `course_access_windows` expose owner-only reads. Clients cannot write them.
- Private feature sources, audit and outbox records are not exposed. Service role cannot bypass the grant/revision transaction with a direct table write.
- Service-only `set_course_unit_grant` serializes on the account, deduplicates source keys, increments the revision and records audit/outbox entries atomically. It is a persistence primitive, **not referral eligibility verification**. The referral worker must prove eligibility and apply the two-milestone rule before invoking it.
- Service-only `apply_verified_feature` accepts state only after the billing worker verifies Play and holds its fenced lineage lease. It cannot itself verify a purchase token. Do not expose it in a client mutation endpoint.
- Access windows are read by the snapshot resolver, but the fixed-cutoff legacy migration writer is intentionally deferred to the existing-user rollout phase.
- `get_monetization_snapshot` reads a consistent statement snapshot, omits revoked grants, separates Core from AI, and computes each purchase's offline bound before aggregating. Routine snapshot requests do not refresh purchase verification timestamps.
- Account export includes safe grant/window/feature history, excluding source keys and internal audit records. Account deletion cascades owned access/cache data and removes the user's ID from retained audit records. Define final audit retention with the production privacy/accounting policy before rollout.

## Cache and signing behavior

The Dart client uses `cryptography` Ed25519 verification with an embedded key allowlist and fixed compact-JWS header. It validates schema, account, feature bounds, campaign/manifest and grant membership after verification. A valid signature alone is insufficient.

Cache rows are account-scoped, excluded from generic sync and erased with learner data. Account transitions suspend the repository before session or local-data changes; late callbacks cannot write or publish access for the next account. Failed remote refresh retains only an independently verified cached document. Identical or older signed documents cannot reset the clock anchor. Clock rollback requires reverification for time-limited access; permanent grants remain available. A genuinely newer verified server document establishes a new clock anchor.

Retain old public keys while permanent offline documents may still exist. Publish the next public key in clients before switching the backend signer. Removing an old key without an online refresh path can strand offline learners.

## Verification scope

The migrations and pgTAP suite are tested against a full disposable local Supabase stack and again in CI, including a reset through every historical migration. The earlier minimal PostgreSQL harness was insufficient and is not release evidence. Tests cover owner isolation, rejected client writes/RPCs, idempotent grants, revision/outbox atomicity, purchase-bound offline validity, old/new placement merges, export redaction and deletion. Phase 4a additionally runs real concurrent reward transactions and compares its server manifest with the bundled lesson files.

The standard Deno suite includes JWT-routing and JOSE signing tests. A committed public test vector produced by `jose` is verified by Dart's independent Ed25519 implementation. Its ephemeral private key was discarded.

Primary library references: [Supabase function security](https://supabase.com/docs/guides/database/functions), [Dart cryptography](https://pub.dev/documentation/cryptography/latest/).

## Notifications and the worker (PR 3b)

- A notification is only a hint. Intake verifies Google's OIDC token (issuer, exact audience, service-account email, verified email), checks the package name, stores the message once per Pub/Sub message ID and queues a refresh for a known purchase. It answers `204` only after storing, so a storage failure is redelivered. Unusable messages (another package, malformed) are acknowledged and logged, because redelivery can never fix them. Tokens are matched by digest and never stored in the inbox.
- A notification for a token no account has registered is kept as `unmatched`; the owner's own verify call provisions it. A notification that arrives while a refresh is running queues one more behind it, because the running one may have read Play before the change.
- Every minute the worker queues reconciliation for purchases that grant or may soon change access and were not verified in the last day, those within a day of their paid-through time, and pending purchases hourly. Purchases with an open refresh are skipped, so reconciliation never cancels a backoff. It then runs due jobs, acknowledgements first, for up to 40 seconds.
- A job that has failed 80 times (two to three days with backoff) is marked dead and keeps its last verified access. `billing_health()` reports unacknowledged paid purchases older than an hour, dead jobs, the oldest due job and unmatched notifications; the worker logs `billing_attention_required` when the first two are non-zero. Wire that log to an alert before launch: Play refunds purchases left unacknowledged for three days.

## Paid AI chat and spend protection (PR 6a)

- **Switches** (Edge Function secrets, shared by `deepseek-proxy` and `monetization-api`):
  - `AI_PAID_CHAT_REQUIRED`: `true` requires a verified AI subscription for `conversation` and `conversation_summary`, and `/configuration` then reports `paid_chat_required: true`. Default off. While it is on, a chat request without a `request_id` (an app too old for paid chat) gets `426 client_update_required`.
  - `AI_PROVIDER_REQUESTS_ENABLED`: `false` is the emergency stop. Every AI request, course feedback included, answers `503 ai_temporarily_unavailable`, and nothing is charged.
- **Spend ceiling:**
  - `AI_DAILY_SPEND_CEILING_MICROS` caps the estimated provider spend per UTC day. The default is 20,000,000 micros, which is 20 units of the billing currency.
  - Costs are estimated from token counts using `AI_INPUT_MICROS_PER_MILLION_TOKENS` and `AI_OUTPUT_MICROS_PER_MILLION_TOKENS`. The defaults (300,000 and 1,200,000) are placeholders; set them from the provider's price list before launch.
  - A call whose outcome is unknown is counted at its worst case.
  - Reaching the ceiling stops new provider requests with `503 ai_temporarily_unavailable` and logs `ai_spend_ceiling_tripped` once. Wire that log to an alert.
- **Replay:** `AI_REPLAY_KEY` is a base64 32-byte AES-256-GCM key that seals chat replies stored for replay. Paid chat answers 503 without it. Rotating the key makes stored replays unreadable, and they then answer `result_unavailable` rather than being resent.
- **Summaries:** `AI_SUMMARY_MIN_NEW_TURNS` (default 1) is the number of completed turns a server-known chat session needs since its last summary.
- **Idempotency:** a chat request carries a `request_id` and `session_id` (lowercase UUIDs). `reserve_ai_request` binds the ID to a digest of the operation, session, context and messages, and takes the daily allowance in the same transaction. A retry then gets one of four answers:
  - the sealed reply (`replayed: true`);
  - `request_in_progress` while the first attempt's 90-second lease runs;
  - `result_unavailable` once the outcome is unknown;
  - `idempotency_conflict` for a different payload under the same ID.

  Nothing reaches the provider twice. A definite provider failure refunds the turn to the day it was taken from. A timeout keeps it spent.
- **Allowances:** chat allowances (`AI_DAILY_REQUEST_LIMIT`, default 20 turns; `AI_DAILY_SUMMARY_LIMIT`, default 60 summaries) are counted in `monetization_private.ai_daily_allowance`, apart from the course-feedback counters in `public.ai_daily_usage`.
- **Access and retention:**
  - AI access is `has_ai_chat_access`: an active, in-grace or canceled-but-paid `ai_chat` purchase. Staff course overrides and referral grants never count.
  - The worker calls `cleanup_ai_request_records()`, which clears replay content after 24 hours and removes content-free tombstones after seven days.
- **Unchanged here:** requests without a `request_id` (today's app) take the previous path while paid chat is not required; their cost now counts toward the ceiling. `grammar_check` and `writing_evaluation` also still take that path; PR 6b authorizes them against course content.

## Course feedback authorization (PR 6b)

- **Tasks:**
  - Writing feedback names a server-known task: `context.task_id` = `<exam id>/s<section>/q<question>`.
  - The server takes the task's text and level from `monetization_private.course_ai_tasks`. The client's `task_description` and `level` are ignored for such requests.
  - A task request carries exactly one learner answer.
  - Unknown tasks answer `404 unknown_task`.
- **Manifest:**
  - `tool/generate_course_ai_tasks.py` builds the task list from the bundled exam banks: 11 writing tasks, with the fixture in `docs/monetization/fixtures/course_ai_tasks.v1.json`.
  - CI checks the fixture against the assets (`--check`) and the local database against the fixture (`--check-db`).
  - A changed or new exam task needs a regenerated fixture and a new migration that ships before the app that uses it.
- **Access:** `has_course_level_access` mirrors the app's `CourseAccessPolicy`. A level is open when every one of its units comes from one of these:
  - the free units;
  - an active staff override;
  - Core;
  - a migration grace window;
  - permanent grants that have not been revoked.

  The AI subscription alone is not course access.
- **Switch:**
  - `AI_COURSE_ACCESS_REQUIRED=true` refuses feedback for a level the account cannot open (`403 course_access_required`).
  - It also refuses free-form writing feedback (`426 client_update_required`) and every `grammar_check`, which the app never sends (`403 course_task_required`).
  - Default off. Today's app keeps the previous path until it is on.
- **Allowance:** course feedback has its own daily counter, `AI_DAILY_FEEDBACK_LIMIT`, default 30, apart from chat turns and the legacy counter. Any failure refunds it to the day it was taken from, and the provider cost still counts toward the spend ceiling.

## Paid chat in the app (PR 6c)

- `/configuration` now also reports `ai_daily_turn_limit`, parsed from `AI_DAILY_REQUEST_LIMIT` the same way the proxy parses it, so the AI plan states the limit that is enforced. Set it on both functions together; it is one project-wide secret.
- Staging builds can show the AI subscription gate before the server requires it with `--dart-define=MONETIZATION_PAID_CHAT_PREVIEW=true`. The server still decides what it serves.

## Existing-user migration (PR 7a)

Run by an operator with the service role, once per launch cutoff. All functions are idempotent.

1. **Choose the cutoff.** Choose `T0` (UTC) and a migration ID (for example `t0-2026-11-01`). Grace always ends at `T0 + 30 days` and offline claims close then too. Neither can be changed for a run, and a reinstall or new device finds the same window.
2. **Dry run.** At or after `T0`, call `select legacy_migration_prepare('<id>', '<T0>', <manifest revision>);`. The first call copies every pre-`T0` account's completed or attempted lesson rows into an immutable snapshot. Every call plans the unit grants and returns the dry-run summary:
   - eligible accounts;
   - accounts with units;
   - grants in total and per unit;
   - five sample accounts.

   Review it before applying. Later changes to `lesson_progress` cannot move the snapshot.
3. **Apply.** Call `select legacy_migration_apply('<id>', '<operator>');`. It gives every pre-`T0` account the grace window, and each planned account its exact units as permanent `legacy` grants through `set_course_unit_grant` (audited, revisioned). Calling it again changes nothing.
4. **Offline claims.** `submit_legacy_claim` accepts one claim per pre-`T0` account until the window closes, from the app's local lesson record. Units already granted are not counted again. More new units than the review threshold go to `needs_review`, and support decides with `resolve_legacy_claim('<id>', '<user>', true|false, '<operator>')`. The app sends claims through `POST monetization-api/legacy/claim`, which always uses the most recently applied run. `LEGACY_CLAIM_REVIEW_UNITS` (default 3, range 0–31) sets the review threshold. Find claims waiting for support with `select user_id, resolved_unit_ids, received_at from monetization_private.legacy_migration_claims where status = 'needs_review' order by received_at;`.
5. **What learners see.** Once the course paywall is on, the app reads `GET monetization-api/legacy/status`. Pre-`T0` accounts get an explanation on Home (dismissible, gone when grace ends) and at the top of the upgrade screen: the grace end date, the units they keep, and a one-time "Send this phone's record" button when this device holds lessons from before `T0` that would reach a unit the account does not already keep. Only lessons whose recorded attempt is before `T0` are sent; lessons learned during grace never are.

**How units are resolved.**
- **Reached units:** any unit with a completed or attempted lesson in the snapshot.
- **Next unit:** each phase's next unit is added only when every lesson of every earlier unit in that phase is complete, which is the app's own progression rule.
- **Lesson mapping:** lessons map to units through `monetization_private.course_lessons`, generated by `tool/generate_course_lessons.py` and checked by CI. The unit ID a client wrote into its own progress is never used.
- **Ignored inputs:** placement, empty default rows and unknown lessons count for nothing.
- **Scope:** A2 grants stay A2, and legacy grants carry no campaign, so they never take a referral reward.

## Account deletion and export (PR 7b)

- **Renewing subscriptions.** `account-data` DELETE asks `account_deletion_notice` first. While an active, grace, on-hold or paused Play subscription is still auto-renewing, it answers `409 store_subscription_active` until the request carries `x-confirm-store-subscription: KEEPS RENEWING IN GOOGLE PLAY`. The app warns up front when its verified snapshot shows a subscription, and again if the server knows of one the device did not. An unreadable notice warns rather than deleting silently.
- **What deletion keeps.** A deleted buyer's purchases stay as ownerless tombstones (`user_id` null) for the 7c support recovery; they are never reassigned by deletion. A deleted referrer loses their code and their own grants; the invitee keeps their claim record, with the referrer tombstoned, and no further rewards are issued on it. A deleted invitee's receipts are erased, and the referrer keeps the units already earned.
- **Export.** `export_account_snapshot` adds the account's own purchases, referral code, claim, receipts and rewards, AI allowance and chat sessions, and legacy claims, through fixed column lists. It never includes purchase tokens or digests, replay content, fraud signals, internal source keys, or the other side of a referral. `account_policy.ts` lists these keys in `serverOwnedExportKeys`; an export missing any of them is refused.
- **Retention.** `monetization-worker` calls `cleanup_privacy_records` on every run and reports the counts under `privacy.retention`. Periods and their legal reasons are in [PRIVACY_AND_DATA_SAFETY.md](PRIVACY_AND_DATA_SAFETY.md#decisions-22-sep-2026).
