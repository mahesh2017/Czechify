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

## Delivery 4b — Referral API, challenges and Play Integrity

Implemented on `codex/referral-intake`, stacked on 4a. Details and secrets: [REFERRAL_BACKEND.md](REFERRAL_BACKEND.md).

- Five referral routes on `monetization-api`, with the account from the verified JWT and stable error codes.
- Canonical receipt bytes with a Python-generated cross-language fixture, and a Play Integrity request hash binding account, campaign, claim, receipt and a single-use nonce.
- Challenges consumed in the same transaction as receipt persistence; committed receipts replay before any challenge or token check.
- A Play Integrity verifier: reject a token not made for this request, review verdicts Play cannot vouch for, verify the rest. Devices without Integrity take an explicit review route.
- Privacy-safe status with numbered friends and cursor pagination; worker processing of claims released by account linking or resumed processing; retention; a service-only campaign switch.
- Refactor: service-account OAuth moved to `_shared/monetization/google_auth.ts` for Play billing and Integrity; the monetization worker no longer requires billing secrets for referral work.

Validation:

- Database: `supabase test db` passes 323/323 on the full migration chain (45 new intake checks); all three concurrency fixtures pass; lint is clean.
- Edge Functions: fmt, lint, `deno check` on all entry points, 114 unit tests. The canonical bytes match the independently generated fixture.
- End to end, on the local stack with only Integrity faked: a linked friend claimed a code and submitted all eight lessons through challenge, token check and receipt. While paused the learning was recorded without rewards; once resumed, the worker granted units 3 and 4, and a retried receipt returned the original result without a new token check or reward. The billing integration test still passes after the worker change.

Not in 4b: the Flutter claim flow, player coverage capture and receipt outbox (4c); operator identity for reviews; real Play Integrity tokens, which need a Play-distributed build.

## Delivery 4c — Flutter referral client

Implemented on `codex/referral-client`, stacked on 4b. Details: [REFERRAL_BACKEND.md](REFERRAL_BACKEND.md).

- Dart canonical receipts and Integrity request hash matching the shared Python-generated fixture byte for byte.
- Receipt coverage from the real lesson player, recording teaching cards as acknowledged although the player reports their Continue as a skip.
- The claim captured when an attempt starts and kept in the resume checkpoint; receipts only for the free units, never in exam mode, never across an account switch.
- Drift schema 10: an account-scoped claim table and receipt outbox, cleared with learner data and never synced. The receipt commits in the same transaction as the lesson attempt.
- An uploader (challenge, Integrity token, submit) with backoff, permanent and held outcomes, account fencing, and triggers after a lesson, at startup, on resume and on reconnect.
- A native Play Integrity channel (`integrity:1.6.0`) mapping Play's error codes to unsupported, misconfigured and retry.
- A claim provider for the Phase 5 screen.

Validation:

- Flutter: 1,430 tests pass, `flutter analyze --fatal-infos` is clean, changed-line coverage is 92%. The debug APK builds with the new native code.
- Atomicity is proven by failing the receipt insert inside the lesson transaction: the attempt row is rolled back too. A v9 database upgrades to v10 with both tables.

Not verified on a device: a real Integrity token needs a Play-distributed build with the Cloud project configured, and no screen calls the claim yet.

## Delivery 5a — Course admission

Phase 5 is split into 5a (one admission decision enforced at every entry point), 5b (upgrade and referral screens, paid-unit visuals and the course-boundary prompt) and 5c (audio downloads, accessibility and locale review).

- **Switch:** `course_paywall_enabled` from `/configuration`, off by default; `--dart-define=MONETIZATION_PAYWALL_PREVIEW=true` turns it on in staging builds. While it is off, every published unit counts as accessible and only learning progression applies, as before.
- **One configuration fetch per account,** shared by the checkout and paywall switches. Lessons wait on it, so it times out after three seconds; the account's last answer on this device then applies (a paywall that was on stays on offline), and with no answer ever received everything is off. A second account on the device never inherits the first one's answer.
- **Providers:** `commercialAccessProvider` (the verified snapshot's access, or null while off), `playableLessonIdsProvider` (open by progression and paid for), `lessonAdmissionProvider` (Delivery 1's policy: payment ahead of prerequisites, loading never read as a paywall, account switches admit nothing), `examAdmissionProvider` and `paidBoundaryLessonProvider` (the lesson Continue would choose by progression alone, for 5b's prompt).
- **Entry points:** the lesson player checks admission before every new attempt, so deep links, restored routes and checkpoint resume pass through it; it shows distinct screens for payment, reconnect-to-verify, an account switch in progress and an unfinished prerequisite. Continue and the evidence-based next lesson use playable lessons. The course map's lesson rows use playable lessons. Starting a new mock exam needs access to the whole level; results stay readable and a saved exam can be resumed. Review introduces new cards only from accessible units; cards already introduced stay. Grammar, quick reference and copybook keep their progression-only gate, since reference pages stay readable. Previously assigned transfer review stays open.
- The old `lessonUnlockedProvider` is removed so no screen can use a second, weaker gate.

Validation:

- Flutter: 1,449 tests pass, `flutter analyze --fatal-infos` is clean, changed-line coverage is 85% before the added exam tests.
- On the Pixel emulator with the paywall preview on and the local stack: Daily Arrival and Home continue with the free-unit lesson; that lesson opens and resumes its checkpoint; the A1 mock exam shows the options message instead of Start; the course map is unchanged for the free units.

Not in 5a: the upgrade and referral screens (the payment screens link to `/subscriptions` for now), paid-unit visuals on the course map, the course-boundary prompt, and audio-download filtering.

## Delivery 5b — Upgrade and referral screens

- **Switch:** `referral_claims_enabled` from `/configuration`, off by default; `--dart-define=MONETIZATION_REFERRALS_PREVIEW=true` shows invitations in staging builds. The server still refuses codes and claims while the campaign is closed.
- **Upgrade screen** (`/upgrade?unit=`): every payment prompt now leads here instead of straight to `/subscriptions`. It offers Core, and for A1 units (with invitations open) inviting friends. An A2 unit never promises a referral reward and says A2 comes with Core.
- **Referral screen** (`/referrals`, also from Settings when invitations are open): anonymous learners are asked to link their account first. Linked learners get their code with Share and Copy, units earned and the next reward unit, and their friends by number only with each milestone's status. An invited learner enters a friend's code (each server refusal has its own message) and then sees their own lesson progress, including review and rejection. A reward is shown only once the server has committed it.
- **Course map:** units the account has not paid for carry a notice with a button to the upgrade screen, in both the path and list layouts. Nothing shows while access is loading or while the paywall is off.
- **Home:** at the paid boundary (`paidBoundaryLessonProvider`), Continue shows "Ready for the next unit?" instead of "All caught up".
- Every prompt that mentions invitations falls back to Core-only wording while invitations are closed.

Validation:

- Flutter: 1,470 tests pass, `flutter analyze --fatal-infos` is clean, changed-line coverage is 89% against 5a. New widget tests cover the upgrade and referral screens (14), the lesson paid view (it passes its unit), and Home and the course map at the boundary (7). The course-map tests use the path layout; the list layout already trips Flutter's debug check for a ListTile under a coloured DecoratedBox (its expansion header, not the new notice), so it is not driven in tests yet.
- On the Pixel emulator with the paywall, referral and checkout previews on and the local stack: the course map marks unit 3 with the A1 notice; See your options opens the upgrade screen with Core and Invite friends; Settings shows Invite friends; the referral screen asks an anonymous learner to link first. That run caught the screen saying "0 of 15 earned" beside "You've unlocked every A1 unit" when the status had not loaded; it now says nothing about rewards until the status loads and claims every unit only when that is true. Linking an account and a real invite round trip were not run on the device.

Not in 5b: audio-download filtering and the accessibility and locale review (5c).

## Delivery 5c — Audio downloads, accessibility and locale review

- **Audio downloads:** `offlineAudioUnitsProvider` narrows the audio fetched ahead (onboarding setup, a level change, a voice change) to the level's first units the account can open. Clips already on the device stay and still play; a unit opened later streams its audio as its lessons play. While the paywall is off every unit is accessible, so nothing changes. An A2 learner without access downloads nothing ahead, and setup continues straight to Home.
- **Locale:** the offline setup screen and the end-of-A1 prompt were hard-coded English; both are now in English and Czech. Setup no longer promises "your first three units", since fewer may be downloadable.
- **Accessibility:**
  - Page and section titles on the upgrade and referral screens are marked as headings.
  - The invite code is read letter by letter.
  - The paid-unit button meets the 48 dp touch target.
  - The upgrade screen, the referral screen and a course map with a paid unit join the screen smoke matrix (light and dark, 1x and 2x text, Czech at 2x). At 2x text that matrix found the course map's unit header overflowing on the current unit, where the "UNIT n" label and the "IN PROGRESS" pill share a row. This predates monetization: the old smoke case rendered no units. The row now wraps.
- **Out of scope, found in passing:** the mock exam and parts of Home still carry hard-coded English that predates monetization. The list layout's ListTile debug assertion is being fixed separately.

## Delivery 6a — Paid AI chat and spend protection (server)

PR 6 is split into 6a (server: AI entitlement, idempotent reservations, replay and spend protection), 6b (course grammar/writing authorized against server content, separate from chat) and 6c (chat and upgrade UI: quota, denials, AI purchase page).

- **Database:** migration `20260924100000_ai_request_reservations.sql` adds chat sessions, per-day chat allowances, request reservations and project spend, all in `monetization_private` and reached only through service-role functions.
- **Proxy:**
  - Chat requests that carry a `request_id` go through `paid_chat.ts`: an entitlement check when `AI_PAID_CHAT_REQUIRED` is on, then an atomic reservation, a single provider call, and a sealed replay.
  - The emergency switch and the daily spend ceiling sit in front of every provider call.
  - Old clients keep the previous path until paid chat is required, and are then asked to update.
- **Configuration:** `/configuration` reports `paid_chat_required` from the same switch.
- **Worker:** clears replay content after 24 hours and tombstones after seven days.
- Setup, switches and secrets: [BACKEND_SETUP.md](BACKEND_SETUP.md#paid-ai-chat-and-spend-protection-pr-6a).

Validation:

- `supabase test db`: 373 tests across 10 files. The new file covers:
  - access: AI buyer yes; staff, Core, expired and on-hold no; grace yes;
  - reserve, replay and conflict; account-scoped replay;
  - summaries need a known session with a new turn;
  - release refunds and may retry; abandon and an expired lease never redispatch;
  - the allowance stops at the limit;
  - the ceiling trips once;
  - retention;
  - privileges.
- Deno: 136 function tests pass; fmt and lint are clean. They cover every reservation outcome, provider unknown vs failed vs reply, digest stability, the emergency switch, the spend ceiling, old-client refusal under enforcement, course feedback unaffected by the chat subscription, and worker retention.
- Concurrency relies on the same conditional-update pattern as the existing quotas: a row at the limit matches nothing, so parallel requests cannot pass together. pgTAP runs in one session and does not exercise real parallelism.

Not in 6a: course-operation authorization (6b); the app sending request and session IDs, and the chat and purchase UI (6c).

## Audit fixes after 6a

An audit of #39–#49 found eight defects. All are fixed, and each fix has tests that fail on the old behaviour:

1. **AI double charge under simultaneous retries.**
   - `reserve_ai_request` locked nothing when the reservation row did not exist yet, so two identical first calls both took an allowance and both dispatched.
   - Migration `20260925100000_ai_reservation_concurrency.sql` serializes each account's reservations with a transaction advisory lock.
   - It also fences summaries while one is in flight. A released summary may retry; an abandoned one stays spent.
   - `tool/test_ai_reservation_concurrency.py`, now run in CI, forces real lock contention. It fails on the 6a schema (`['reserved', 'reserved']`) and passes now.
2. **Referral claim lost after reinstall or account switch.** Lesson evidence now recovers the account's claim from `/referrals/status` when no local claim exists. An offline local claim still works without a network call.
3. **Earned referral units stayed locked.** A referral status fetch now reloads the signed entitlement snapshot, and so do app resume and reconnection. Status is never treated as access.
4. **Lesson retry skipped the access check.**
   - The two-hour, account-bound permit is now connected to the player and saved with the checkpoint.
   - Retry and a replacement attempt always get fresh admission.
   - An account switch revokes permits immediately.
   - A long-running attempt is rechecked at the two-hour boundary.
5. **Pausing checkout hid restore.**
   - Subscriptions stays reachable, with restore and management, whenever checkout, the course paywall or a subscription applies to the account.
   - It remains hidden before launch; the audit's first fix would have shown it to every Android user.
6. **Referral actions stuck on network errors.** Claiming and code requests always clear their busy state and explain the failure.
7. **Review introduced paid cards when access failed to load.** It now fails closed.
8. **Audio downloads not rechecked when work starts.**
   - Access is refreshed when a queued download starts and checked again before each file.
   - A change of account stops the batch.
   - Access reads hold a subscription: an unlistened provider pauses after invalidation, so a bare read would never complete and a download would stay stuck on "Starting…".

Validation:

- Flutter: 1,520 tests pass; `flutter analyze --fatal-infos` is clean; changed-line coverage is 85% against 6a.
- Database: `supabase test db` passes (376 tests) from a clean `supabase db reset`, followed by both concurrency tools and `supabase db lint`.
- Pixel emulator with the paywall preview on:
  - a free lesson is admitted and resumes its checkpoint;
  - its permit is saved, bound to account, epoch, lesson and attempt;
  - leaving and reopening resumes the same attempt under the same permit.

## Delivery 6b — Course feedback authorization

- The app's only course AI call is mock-exam writing evaluation; nothing sends `grammar_check`. Writing requests now name a task (`examTaskId`), and the server evaluates against its own copy.
- The server's copy lives in `monetization_private.course_ai_tasks`, seeded by migration `20260926100000_course_ai_tasks.sql` from a manifest generated from the bundled exam banks. CI checks assets, fixture and database agree.
- Free-form task text can no longer become an arbitrary prompt once `AI_COURSE_ACCESS_REQUIRED` is on. Before this, any client could put any text in `task_description` and get a paid model call.
- **Access:** the level must be open to the account by the same rule the app uses. Referral units and the AI subscription never open A2 or the exam alone.
- **Allowance:** course feedback has its own daily allowance (default 30), apart from paid chat.
- **Errors:** proxy refusals map to specific messages in the app (`llmFailure`), and keep their code for 6c. A chat limit is never reported as a feedback limit.
- Setup and switches: [BACKEND_SETUP.md](BACKEND_SETUP.md#course-feedback-authorization-pr-6b).

Not in 6b: review-exercise AI authorization. No lesson or review exercise calls the AI today, so there is nothing to authorize. Any future one needs a manifest entry and a recorded review assignment, never a client-supplied lesson ID.

## Delivery 6c — Paid chat in the app

- **Request identity:**
  - Tutor turns, greetings and summaries carry a `request_id` and a `session_id` (the UUID in the conversation's `conv_` ID).
  - A retry of a failed turn resends the exact request the first attempt sent, under the same ID, without re-summarizing. Otherwise the payload would change and the server would treat it as a conflict.
  - While the server reports `request_in_progress`, the app asks again about that same request (up to three times, five seconds apart), never under a new ID.
  - After `result_unavailable` or a conflict, "Send again" is an explicit new turn, and the app says it uses a reply.
- **Refusals:** each has its own localized message, in English and Czech. A missing subscription offers the AI plan instead of a retry. A used-up day and an old app offer no retry at all. A new conversation refused for subscription never shows a stand-in greeting.
- **Gate:**
  - When `/configuration` reports `paid_chat_required` (or a staging build sets `MONETIZATION_PAID_CHAT_PREVIEW`), new conversations need an active AI chat subscription in the verified snapshot. Core does not count.
  - Without one, the situations are replaced by an explanation and the plan. Past conversations stay listed and readable.
- **AI plan:** the card states the daily reply limit the server enforces (`ai_daily_turn_limit` in `/configuration`, parsed from the proxy's own setting), and that lessons and exams are not included.

Validation: 1,546 Flutter tests pass with 96% changed-line coverage; 144 function tests pass. On the Pixel emulator with the paid-chat preview, a new account sees the chat lock (with the enforced limit and the Core separation) and the AI plan card states the limit. Staging still needs the proxy with `AI_REPLAY_KEY` set and a real AI subscription purchase, to see replay and quota end to end.

## Delivery 7a — Existing-user migration (server)

Phase 7 is split into 7a (the fixed-cutoff migration ledger), 7b (the app's explanation and offline claim, safe deletion and export, privacy wording) and 7c (support recovery and operating dashboards).

- **Migration `20260927100000_legacy_migration.sql`:**
  - `course_lessons`, generated from the bundled lessons and checked in CI;
  - `legacy_migration_runs`, with a fixed `cutoff_at`, `grace_ends_at` = T0 + 30 days, and the claim window;
  - an immutable per-run snapshot of pre-cutoff progress;
  - `legacy_migration_claims`, statuses `planned` / `applied` / `needs_review` / `rejected`.
- **Operations:**
  - `legacy_migration_prepare` snapshots once at or after the cutoff, plans, and returns the dry-run summary.
  - `legacy_migration_apply` grants the grace window to every pre-cutoff account and the exact reached units as permanent legacy grants. Rerunning it changes nothing.
  - `submit_legacy_claim` accepts one offline claim per account inside the window; larger claims wait for support's `resolve_legacy_claim`.
- **Unit rule:** reached units are those with a completed or attempted lesson. A phase's next unit is added only after every earlier lesson in that phase is complete. Placement, empty rows, unknown lessons and client-written unit IDs are ignored. A2 stays A2, and legacy grants never take a referral reward.
- Operator steps: [BACKEND_SETUP.md](BACKEND_SETUP.md#existing-user-migration-pr-7a).

Validation: `supabase test db` passes (451 tests; the new file has 45). They cover:
- the unit rules;
- a dry run grants nothing;
- the fixed snapshot and immutable cutoff;
- exact grants;
- grace for accounts with no units;
- no migration after the cutoff;
- idempotent reapply (no duplicate grants, windows or events);
- no grace restart after progress is wiped;
- each offline-claim path (ineligible, not ready, applied, repeat, already claimed, already owned, review and approval, rejected, window closed);
- privileges.

## Delivery 7b — Legacy claims, deletion and export

- **Migration `20260928100000_account_lifecycle.sql`:**
  - `legacy_claim_status` reports the latest applied run for an account: cutoff, grace end, claim window, eligibility, the kept units and any claim;
  - `export_account_snapshot` adds the account's own purchases, referral code, claim, receipts and rewards, AI allowance and chat sessions, and legacy claims. It uses fixed column lists: no tokens or digests, no replay content, no fraud signals, no internal keys, and nothing about the other side of a referral;
  - `account_deletion_notice` counts subscriptions still renewing.
- **`monetization-api`:** `GET legacy/status` and `POST legacy/claim`. The account comes from the token and the run from the database; lesson IDs are validated, deduplicated and capped at 500. `LEGACY_CLAIM_REVIEW_UNITS` sets the review threshold.
- **`account-data`:** a deletion that would leave a Play subscription renewing answers `409 store_subscription_active` until the learner has been told. An export missing any monetization record is refused.
- **App:**
  - an explanation card for pre-cutoff accounts at the top of the upgrade screen, and on Home during grace (dismissible per account). It shows the grace end and the units kept for good.
  - The one offline claim is offered only when this device holds lessons from before the cutoff that reach a unit the account doesn't already keep. Only attempts recorded before the cutoff are sent, never lessons learned during grace. A reply for an account that has since switched is dropped.
  - Account deletion warns that Google Play keeps charging, from the verified snapshot or when the server asks.
- **Privacy:** wording and Data safety changes are drafted in [PRIVACY_AND_DATA_SAFETY.md](PRIVACY_AND_DATA_SAFETY.md) and go live with activation. The EU rules apply to every learner:
  - Migration `20260928110000_privacy_retention.sql` adds `cleanup_privacy_records`, run by `monetization-worker` on each pass.
  - A deleted account's purchases stay only while Google Play could still restore them, then 30 days.
  - Referral lesson summaries go 90 days after the invitation is decided or the campaign ends.
  - The existing-user snapshot goes 90 days after its claim window closes.
  - Operational rows go after 30 days.
  - The Play Integrity check is opt-in (ePrivacy Art. 5(3)): a switch on the invite screen, off by default. Without consent, receipts go to support review and the device is never asked.
- **Checked, no change needed:**
  - Deleting an invitee erases their receipts and keeps the referrer's earned units.
  - Deleting a referrer removes only their own code and access; their open claims earn nothing further.
  - Anonymous learners reach linking from both the subscriptions and the invite screens.
  - Account switches clear the monetization snapshot, referral claim and receipt outbox (`clearLearnerDataRows`).

Validation:
- `supabase test db`: 505 tests; `account_lifecycle.test.sql` adds 34 and `privacy_retention.test.sql` 20. They cover export privacy for both sides of a referral and for purchases, the deletion notice, tombstoning on buyer and referrer deletion, and migration status before and after apply.
- Deno: 156 tests, including the legacy routes and the deletion warning policy.
- Flutter: the new claim flow, local record, providers, card, deletion request and account-screen warning tests.

## Activation boundary

Phase-local progression is connected to the existing runtime. The subscriptions screen reads verified entitlement snapshots and supports Play checkout and restore, gated by Android support and the server checkout switch (or an explicit staging preview build). Server products remain disabled. Lesson admission, the course map and Home enforce commercial access once `course_paywall_enabled` is on (5a, 5b); it is off. Referral routes, challenges, Integrity verification and allocation exist on the server with the campaign disabled and processing paused. The app records and uploads lesson receipts for learners holding a claim; the referral screen (5b) creates claims and shows progress, hidden until the server opens the campaign. No production backend was changed.

Do not connect an unverified JSON/cache object to `MonetizationSnapshot`. Course admission must consume the existing repository's signature-, account- and protocol-verified result. `ReferralRewardPolicy` is a client preview; only verified server intake followed by the 4a database transaction may issue real referral rewards.

## Next implementation work

1. Real Play license tests of the whole purchase path (see the matrix in [IMPLEMENTATION_AND_TESTS.md](IMPLEMENTATION_AND_TESTS.md)). They need a staging Supabase project, Play Console subscription products with license testers, a Play Developer API service account, a notification topic, and a staging build with `MONETIZATION_CHECKOUT_PREVIEW=true` and the staging public key.
2. Real Play Integrity tokens end to end from an internal-track build (`PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER`, `PLAY_INTEGRITY_CERT_DIGESTS`), then the referral screen and course-boundary prompts against them.
3. Support recovery tooling and operating dashboards (7c), then staging verification and release activation (PR 8), which also publishes the privacy wording. Course admission and its screens (Phase 5) and the AI subscription with spend protection (PR 6: 6a–6c) are done.
