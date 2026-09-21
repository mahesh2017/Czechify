# Implementation status

## Delivery 1 — Access-policy foundation

Implemented on `codex/monetization-research-plan`:

- Immutable campaign catalog with explicit A1/A2 membership, two free units and the ordered 15-unit reward list. Tests compare it with the actual bundled curriculum and pinned lesson manifest.
- Commercial access as a union of free, permanent referral/legacy, Core, migration grace and staff sources. Unknown unit grants and another account's snapshot cannot unlock content.
- Subscription state and offline validity policies, including exact expiry boundaries and aggregation that cannot mix one purchase's expiry with another purchase's verification date.
- Independent Core and AI feature models, immutable account-bound snapshots, and revision/replay checks.
- Structured lesson admission decisions and a two-hour existing-attempt permit bound to account, epoch, lesson and attempt.
- Deterministic referral preview with a two-milestone limit, permanent-ownership filtering, exact A1 reward order and explicit cap-reached outcomes. This is not a client reward-grant mechanism.
- Phase-local learning prerequisites: late A1 units no longer depend on A2 lessons. New explicit placement targets are phase-specific; existing scalar placements retain their previously open span through a compatibility adapter.
- Executable Dart tests for all 40 pure decision fixtures, additional boundary/security cases and curriculum/manifest drift. The three database concurrency fixtures deliberately remain for real database tests.

Validation passed:

- Full Flutter suite: 1,335 tests before the final additional manifest check.
- Final targeted suite with coverage: 85 tests, including that manifest check.
- Changed executable-line coverage: 159/162 lines (98.1%), measured from the staged source diff and LCOV output; above the project's 80% requirement.
- `flutter analyze --no-pub --fatal-infos` and `git diff --cached --check`.

## Delivery 2 — Entitlement backend, signed snapshots and phase placement

Implemented on the same branch; setup and security boundaries are in [BACKEND_SETUP.md](BACKEND_SETUP.md).

- Phase-specific placement persistence: `placement_profiles.phase_ceilings` (server) and the local Drift equivalent keep separate A1 and A2 ceilings. Old clients that write only the scalar `provisional_unit` keep their previously open span, and merges never discard either phase.
- Owner-read-only `monetization_accounts`, `course_unit_grants` and `course_access_windows`; private feature entitlements, audit and outbox. Service-only `set_course_unit_grant` and `apply_verified_feature` serialize on the account and write grant, revision, audit and outbox in one transaction. Neither verifies eligibility or a purchase itself; PR 3 and PR 4 workers must do that first.
- `monetization-api` Edge Function: `GET /configuration` (every activation switch false) and `GET /entitlements`, which derives the account from the verified JWT and returns an Ed25519 compact JWS.
- Dart `SnapshotVerifier` with an embedded key allowlist, and an account-scoped `MonetizationRepository` cache. Replayed or older documents cannot reset the offline clock; clock rollback requires reverification; account transitions suspend the repository so late replies cannot publish another account's access. An unreachable service (including a missing backend client) falls back to the verified cached document.
- Account export includes grant, window and feature history without internal source keys; account deletion removes the beneficiary's access.

Validation passed on the staged commit:

- Full Flutter suite: 1,355 tests. `flutter analyze --no-pub --fatal-infos` clean.
- Changed-line coverage against Delivery 1: 85% (495/577), measured with CI's `diff-cover` exclusions. CI's figure moves about half a point between identical runs.
- Database: `supabase db reset` applies the full migration chain from empty, and `supabase test db` passes 123/123 across all five pgTAP files, using the Supabase Postgres image with Docker Desktop. `supabase db lint --level warning` is clean.
- Edge Functions: `deno fmt --check`, `deno lint`, `deno check` and 49/49 `deno test`.

A plain `postgres:17` container with stubbed Auth and legacy tables passed the new tests but missed three failures the real chain exposed: `placement_profiles.device_id` is required, the account export now has 18 sections rather than 15, and the existing `keep_newest_sync_row` trigger discards updates whose `updated_at` does not advance. Treat only the full Supabase stack as verification for database changes.

Known limitations to resolve before activation:

- Content revision `25` is hard-coded in `get_monetization_snapshot` and in `SnapshotVerifier`. A content release must change both together, or clients reject every signed snapshot.
- `private.placement_unit_order` uses unit ID as `order_index`. This matches the current A1 order (1–15, 28, 30) but must become explicit if a unit is ever inserted out of numeric order.
- `keep_newest_sync_row` still discards an entire placement write whose `updated_at` is older than the stored row, so a phase ceiling from a device with an older timestamp is dropped rather than merged. This matches the pre-existing scalar behavior.
- The staging signing key, public-key distribution and a staging Supabase project have not been provisioned; nothing has been deployed.

## Delivery 3a — Server-side purchase verification

PR 3 is split into 3a (server verification), 3b (Play notifications and the retry worker) and 3c (Flutter checkout, restore and subscriptions screen). 3a is backend only.

- Private billing tables: products (seeded disabled), frozen per-account Play bindings, purchase intents, purchases with SHA-256 token digests and AES-GCM encrypted tokens, fenced verification/acknowledgement jobs and an audit log. A deleted owner leaves a tombstone that no other account can claim.
- Service-only RPCs for binding, intents, registration, job leases, applying a Play result, completing an acknowledgement, failing a job, owner-scoped status and an operator product switch. `apply_play_verification` rechecks the lease and the account binding, provisions through `apply_verified_feature`, and only then creates the acknowledgement job.
- `monetization-api` routes: `POST /purchase-intents`, `POST /purchases/verify` and `GET /purchases/status/<id>`, all requiring a linked account. Verification runs inline and returns `202 verification_pending` when Play is slow or failing. The purchase routes return `503` until all billing secrets are configured.
- A Play Developer API client (service-account OAuth, `subscriptionsv2.get`, `subscriptions.acknowledge`) and a pure normalizer that maps every documented `SubscriptionState` and refuses unknown ones instead of guessing.
- Contract change: `/purchases/verify` requires `product_id`, because Play's lookup is keyed by product.

Validation:

- Database: `supabase test db` passes 173/173 on the full migration chain, including 50 new billing checks for client isolation, frozen bindings, intent idempotency and rate limits, foreign and tombstoned tokens, fencing, binding mismatch, pending purchases, acknowledgement ordering and backoff.
- Edge Functions: `deno fmt --check`, `deno lint`, `deno check` and 76/76 `deno test`.
- End to end: `billing_integration_test.ts` drove the real handler, RPC wiring, Auth and database on the local stack with only Play faked. A linked account bought Core and was acknowledged; a second account and an anonymous account were refused.

Not in 3a: the background retry worker, Play notification intake and daily reconciliation (3b); the Flutter purchase flow (3c); the generic `operation_results` idempotency table (purchase verification is idempotent through the token digest, and intents through their own key); and real Play license tests, which need the staging setup in [BACKEND_SETUP.md](BACKEND_SETUP.md).

## Delivery 3b — Play notifications and the billing worker

- `play-billing-notifications` Edge Function: verifies Google's Pub/Sub OIDC token, parses the developer notification and records it once per message ID by token digest, then queues a Play refresh for a known purchase. Success is returned only after storage; unusable messages are acknowledged and logged.
- `monetization-worker` Edge Function, called every minute by a scheduler with a shared secret: queues reconciliation, runs due jobs with acknowledgements first within a 40-second budget, and reports `billing_health()` counts.
- Database: notification inbox; refresh queueing that brings a waiting job forward and queues one more behind a running one; reconciliation selection; due-job ordering; health counts. Jobs are marked dead after 80 attempts.
- Found and fixed while testing: reconciliation originally reused the notification path, which would have cancelled every backing-off job's delay on each one-minute run. Reconciliation now skips purchases with an open refresh; a regression test covers it.

Validation:

- Database: `supabase test db` passes 204/204 on the full migration chain, including 31 new notification and worker checks.
- Edge Functions: `deno fmt --check`, `deno lint`, `deno check` on all six entry points, and 90 unit tests. Push-token checks sign real RS256 tokens against a local key set and refuse the wrong issuer, audience, email, unverified email and a foreign signing key.
- End to end: the integration test now also sends a cancellation notification (plus its redelivery) through real intake and runs the real worker against the local stack. The worker re-read Play and recorded the cancellation, and Core access stayed active until the paid-through date.

Not in 3b: deploying the functions, the Pub/Sub topic and the scheduler; alert routing for `billing_attention_required`. See [BACKEND_SETUP.md](BACKEND_SETUP.md).

## Delivery 3c — Flutter purchase, restore and subscriptions screen

- `in_app_purchase` 3.3.1 with `in_app_purchase_android` 0.5.3, which bundles Play Billing Library 8.0.0 (version 7's update deadline passed on 2026-08-31).
- `PlayStoreAdapter` offers each product's configured `monthly` base plan without promotional offers, and binds every purchase to the server's obfuscated account reference.
- `BillingFlow`, one per signed-in account: listens to the store before any purchase can start; creates a server intent; verifies purchased and restored tokens with the server, polling briefly while verification is pending; completes the store transaction only after the server provisioned; refreshes entitlements. A pending payment grants nothing, and a purchase begun for another account is never verified under the current one.
- `/subscriptions` screen: Store-localized prices, status from the signed entitlement snapshot only, separate Core and AI purchases, restore, management in Google Play, a link-account prompt for anonymous learners, and a live-region message for each outcome. English and Czech. The Settings entry and the screen appear only when `/configuration` enables checkout on Android, or in a build with `--dart-define=MONETIZATION_CHECKOUT_PREVIEW=true`. The server still refuses disabled products.

Found by running the app, then fixed:

- **Delivery 2 bug:** `monetizationRepositoryProvider` invalidated `monetizationLoadProvider`, its own dependent, from an auth listener. Riverpod raises `CircularDependencyError`, so in debug builds every sign-in event threw and entitlements were never refreshed after an account change. The load provider now rebuilds on account changes itself and takes the account from the live session, not the account stream, which can still hold the previous account during a switch. Regression tests cover both; the second fails if the account is taken from the stream.
- `BillingNotifier` kept the previous account's disposed flow reachable after sign-out. It now clears it on every rebuild.
- Final lifecycle review also found that an already-started checkout could resume after its flow was disposed. Checkout and restore now reject stale accounts and disposed flows before side effects, and checkout rechecks disposal after creating its intent. Purchase-stream errors report failure while allowing subsequent updates to recover. Four regression tests cover these cases.

Validation:

- Flutter: 1,392 tests pass, `flutter analyze --no-pub --fatal-infos` clean, 87% changed-line coverage (364/415 executable lines against the 3b branch).
- On the Pixel emulator (Google Play image) against the local stack, with `monetization-api` served locally and a throwaway signing key: the Settings entry and screen render; an anonymous learner sees the link-account prompt with purchase and restore disabled; and the app fetched, verified and cached the signed entitlement document for its own account, confirmed in the device database. This was the first device run of the Delivery 2 entitlement path.
- Not verified on a device: the emulator was not signed in to Google Play (`In-app billing API version 3 is not supported`), and no Play products exist yet, so no real price, purchase or restore ran. The linked-account screen state is covered by widget tests only.

## Delivery 4a — Referral database foundation

Phase 4 is split into 4a (database attribution, evidence and reward allocation), 4b (authenticated API, canonical receipts, request-bound Play Integrity and worker/review integration), and 4c (Flutter claim flow, real player coverage and durable account-scoped receipt upload). The referral screen and course boundary UI remain part of Phase 5.

Implemented on `codex/referral-foundation`, stacked on the billing client branch:

- Private, client-inaccessible campaign, code, claim, receipt, qualification, milestone, review and reward audit tables. Enrollment ships disabled, processing paused, and campaign dates unset.
- The immutable revision-25 catalog pins all eight free lessons, their 92 exercise IDs, teaching acknowledgements and source hashes. An independently computed manifest digest and a CI check compare the server rows against both the planning fixture and actual bundled lesson files.
- Service-only manual-code creation and claim operations: random opaque codes, linked referrers, a seven-day invitee window, no self-referral or already-completed first unit, fixed attribution, idempotent domain operations and rate-limited code creation/claim attempts (including failed guesses).
- A **trusted-worker-only** verified-receipt persistence operation rechecks ownership, exact manifest coverage, teaching acknowledgements, attempt replay and conflicting payloads. Skipped attempts cannot qualify; incorrect answers can. Timing anomalies and unsupported attestation outcomes wait for review. This RPC does not verify Play Integrity itself and has no HTTP route in 4a.
- Reward allocation derives both milestones from accepted lesson evidence, handles unit 2 arriving first, waits for in-place anonymous linking, and serializes with all permanent-grant writers on the beneficiary account. It skips existing permanent ownership, ignores temporary Core, grants at most two units per claim and caps at A1 unit 30. Grant, revision, audit, outbox and reward event commit together.
- Invitee deletion removes receipt details and tombstones attribution while preserving the referrer's earned units. Review decisions are explicit; replay cannot resurrect a revoked award or turn a previous cap outcome into banked credit.
- A local-only concurrent PostgreSQL harness consumes the three previously deferred transaction fixtures. It holds the beneficiary lock until both competing transactions are confirmed blocked, then checks grants, reward events, audit and outbox counts. CI runs it after the normal database suite.

Not in 4a: public referral endpoints/status projections, generic request idempotency, challenge consumption and Integrity verification, a scheduled retry/link-trigger worker, Flutter claim storage and player receipts, local atomic outbox, referral UI, App Links or install attribution. Do not expose the trusted receipt RPC through an API accepting a client-provided `verified` result. See [REFERRAL_BACKEND.md](REFERRAL_BACKEND.md) for the handoff.

Validation: full local Supabase reset; all 278 pgTAP tests pass (74 new referral checks); all three real concurrency fixtures and the server/bundled-manifest comparison pass; database lint is clean. This slice changes no Flutter or Edge Function runtime code. CI also runs the new contention harness after pgTAP.

## Activation boundary

Phase-local progression is connected to the existing runtime. The subscriptions screen reads verified entitlement snapshots and supports Play checkout and restore, gated by Android support and the server checkout switch (or an explicit staging preview build). Server products remain disabled. Lesson admission and the course paywall do not yet enforce commercial access. Referral evidence validation and allocation exist behind service-only database operations; verified intake and client integration remain pending. No production backend was changed.

Do not connect an unverified JSON/cache object to `MonetizationSnapshot`. Course admission must consume the existing repository's signature-, account- and protocol-verified result. `ReferralRewardPolicy` is a client preview; only verified server intake followed by the 4a database transaction may issue real referral rewards.

## Next implementation work

1. Real Play license tests of the whole purchase path (see the matrix in [IMPLEMENTATION_AND_TESTS.md](IMPLEMENTATION_AND_TESTS.md)). They need a staging Supabase project, Play Console subscription products with license testers, a Play Developer API service account, a notification topic, and a staging build with `MONETIZATION_CHECKOUT_PREVIEW=true` and the staging public key.
2. Complete referral API, canonical request/nonce binding, Play Integrity and durable processing (4b), then the Flutter claim/player-receipt/outbox integration (4c). Database allocation and the three concurrency fixtures are implemented in 4a.
3. Course UI/admission, AI authorization/cost controls, existing-user migration and rollout (PRs 5–8).
