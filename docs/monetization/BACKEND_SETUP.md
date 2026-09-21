# Entitlement backend: staging setup

This delivery implements signed access documents and phase-specific placement. Server-side purchase verification exists (PR 3a); the in-app checkout, Play notifications, referral qualification/Integrity and paywall activation remain later phases. All `/configuration` activation switches return false; no existing screen enforces paid access yet.

## Deployment order

1. Apply the three `20260921` migrations to a dedicated staging Supabase project. The phase-ceiling migration must precede the entitlement schema. New clients send `phase_ceilings`, so deploy the backend migration before distributing the updated app. Old clients remain compatible after the migration.
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
- Failed jobs back off (5 s doubling to 1 h, or Play's `Retry-After`) and keep the last verified entitlement. In 3a nothing retries them in the background: the next verify or restore call does. The scheduled worker and Play notifications are PR 3b.
- `billing_integration_test.ts` runs the real handler and RPC wiring against a local stack with Play faked; its header shows how to run it.


## Schema and operation boundaries

- `monetization_accounts`, `course_unit_grants` and `course_access_windows` expose owner-only reads. Clients cannot write them.
- Private feature sources, audit and outbox records are not exposed. Service role cannot bypass the grant/revision transaction with a direct table write.
- Service-only `set_course_unit_grant` serializes on the account, deduplicates source keys, increments the revision and records audit/outbox entries atomically. It is a persistence primitive, **not referral eligibility verification**. The referral worker must prove eligibility and apply the two-milestone rule before invoking it.
- Service-only `apply_verified_feature` accepts state only after the future billing worker verifies Play and holds its fenced lineage lease. It cannot itself verify a purchase token. Do not expose it in a client mutation endpoint.
- Access windows are read by the snapshot resolver, but the fixed-cutoff legacy migration writer is intentionally deferred to the existing-user rollout phase.
- `get_monetization_snapshot` reads a consistent statement snapshot, omits revoked grants, separates Core from AI, and computes each purchase's offline bound before aggregating. Routine snapshot requests do not refresh purchase verification timestamps.
- Account export includes safe grant/window/feature history, excluding source keys and internal audit records. Account deletion cascades owned access/cache data and removes the user's ID from retained audit records. Define final audit retention with the production privacy/accounting policy before rollout.

## Cache and signing behavior

The Dart client uses `cryptography` Ed25519 verification with an embedded key allowlist and fixed compact-JWS header. It validates schema, account, feature bounds, campaign/manifest and grant membership after verification. A valid signature alone is insufficient.

Cache rows are account-scoped, excluded from generic sync and erased with learner data. Account transitions suspend the repository before session or local-data changes; late callbacks cannot write or publish access for the next account. Failed remote refresh retains only an independently verified cached document. Identical or older signed documents cannot reset the clock anchor. Clock rollback requires reverification for time-limited access; permanent grants remain available. A genuinely newer verified server document establishes a new clock anchor.

Retain old public keys while permanent offline documents may still exist. Publish the next public key in clients before switching the backend signer. Removing an old key without an online refresh path can strand offline learners.

## Verification scope

The new migrations and pgTAP security suite are tested in a disposable local PostgreSQL 17 container. That harness supplies minimal Auth/legacy relations; CI's normal Supabase reset remains responsible for exercising the complete historical Supabase migration chain. Tests cover owner isolation, rejected client writes/RPCs, idempotent grants, revision/outbox atomicity, purchase-bound offline validity, old/new placement merges, export redaction and deletion.

The standard Deno suite includes JWT-routing and JOSE signing tests. A committed public test vector produced by `jose` is verified by Dart's independent Ed25519 implementation. Its ephemeral private key was discarded.

Primary library references: [Supabase function security](https://supabase.com/docs/guides/database/functions), [Dart cryptography](https://pub.dev/documentation/cryptography/latest/).

## Notifications and the worker (PR 3b)

- A notification is only a hint. Intake verifies Google's OIDC token (issuer, exact audience, service-account email, verified email), checks the package name, stores the message once per Pub/Sub message ID and queues a refresh for a known purchase. It answers `204` only after storing, so a storage failure is redelivered. Unusable messages (another package, malformed) are acknowledged and logged, because redelivery can never fix them. Tokens are matched by digest and never stored in the inbox.
- A notification for a token no account has registered is kept as `unmatched`; the owner's own verify call provisions it. A notification that arrives while a refresh is running queues one more behind it, because the running one may have read Play before the change.
- Every minute the worker queues reconciliation for purchases that grant or may soon change access and were not verified in the last day, those within a day of their paid-through time, and pending purchases hourly. Purchases with an open refresh are skipped, so reconciliation never cancels a backoff. It then runs due jobs, acknowledgements first, for up to 40 seconds.
- A job that has failed 80 times (two to three days with backoff) is marked dead and keeps its last verified access. `billing_health()` reports unacknowledged paid purchases older than an hour, dead jobs, the oldest due job and unmatched notifications; the worker logs `billing_attention_required` when the first two are non-zero. Wire that log to an alert before launch: Play refunds purchases left unacknowledged for three days.
