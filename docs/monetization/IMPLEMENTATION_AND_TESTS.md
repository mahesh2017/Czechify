# Implementation sequence and acceptance tests

Implement small, reviewable PRs in the order below. Each PR must preserve compilation and existing learning behavior. Feature flags default off until the complete vertical slice is verified. Do not ship a paywall screen before backend ownership, restore and account isolation work.

## 1. Repository change map

Paths below are relative to the worktree root. Existing files were inspected at the baseline in [README](README.md); proposed files are explicitly marked new.

| Existing path | Required change |
|---|---|
| `lib/domain/engines/curriculum_access_policy.dart` | Make progression phase-local; keep it distinct from commercial access. |
| `lib/domain/engines/level_switch.dart` | Map level/placement through explicit phase and unit order. |
| `lib/presentation/providers/curriculum_providers.dart` | Compose commercial access and progression; derive cards and Continue consistently. Preserve existing staff entitlement semantics. |
| `lib/domain/entities/curriculum_entitlement.dart` and `lib/data/repositories/curriculum_entitlement_repository.dart` | Preserve staff override API; do not silently reinterpret it as a paid or AI entitlement. |
| `lib/presentation/providers/lesson_providers.dart` | Gate `loadLesson` before a new attempt; capture receipt coverage in actual player events; preserve local completion-before-reward ordering. |
| `lib/domain/entities/exercise_attempt_evidence.dart` | Add a separate versioned receipt representation for teaching acknowledgements/initial coverage; do not corrupt existing evidence semantics. |
| `lib/domain/repositories/progress_repository.dart`, `lib/data/repositories/drift_progress_repository.dart`, `lib/data/database/daos/progress_dao.dart` | Extend completion transaction to enqueue eligible referral receipts atomically with an attempt. No synchronous network call in lesson completion. |
| `lib/data/database/database.dart` | Next schema migration, local monetization tables, clear/export lifecycle handling. |
| `lib/presentation/routes/app_router.dart` | Add `/upgrade`, `/referrals`, `/subscriptions`; defend existing lesson, exam, pronunciation and transfer entry points. |
| `lib/presentation/providers/review_providers.dart` | Retain introduced review; filter new introductions through commercial access. |
| `lib/presentation/providers/audio_prefetch_providers.dart`, `lib/data/services/audio/offline_audio_prefetch.dart` | Filter scheduling and execution of new downloads; preserve cache and progress. |
| `lib/presentation/screens/onboarding/offline_setup_screen.dart` and settings audio UI | Display which units can be downloaded under current access. |
| `lib/data/account/account_service.dart` | Integrate account epoch/cancellation and clear/restore semantics; no automatic billing/referral merge on Google account switch. |
| `lib/presentation/providers/account_providers.dart` | Invalidate and rebuild commercial/referral/billing state on account changes. |
| `lib/data/sync/sync_service.dart` | Keep server-owned monetization tables outside the client-upsert allowlist. |
| `lib/presentation/providers/chat_providers.dart` | Handle entitlement, quota, pending request and temporary service failure distinctly; preserve readable history and typed input. |
| `supabase/functions/deepseek-proxy/handler.ts` and `request_policy.ts` | Separate paid conversation/summary authorization from course feedback, enforce request idempotency and quota reservations. |
| `supabase/functions/whisper-proxy/index.ts` | Preserve speech access behavior; verify new shared auth changes do not accidentally require AI chat. |
| `supabase/functions/account-data/index.ts`, `account_policy.ts` | Export safe account data; orchestrate tombstones and referral/privacy cleanup before deletion. |
| `supabase/migrations/20260908202000_export_account_snapshot.sql` | Do not edit an already-applied migration; add a new migration redefining the export function safely. |
| `supabase/config.toml` | Register new functions; external OIDC verification exemption applies only to the notification endpoint. |
| `pubspec.yaml`, Android platform files | Add supported billing/attribution/integrity adapters, resolve native SDK versions, verified App Links and required manifest declarations. |
| `.github/workflows/ci.yml` | Add new Deno entrypoints to check coverage; include new database security tests and cross-language fixture loaders. |

Proposed new files/modules:

```text
lib/domain/entities/monetization_snapshot.dart
lib/domain/entities/referral_receipt.dart
lib/domain/engines/course_access_policy.dart
lib/domain/engines/lesson_admission_policy.dart
lib/domain/repositories/monetization_repository.dart
lib/domain/repositories/billing_repository.dart
lib/domain/repositories/referral_repository.dart
lib/data/repositories/supabase_monetization_repository.dart
lib/data/repositories/play_billing_repository.dart
lib/data/repositories/supabase_referral_repository.dart
lib/data/services/referral_receipt_uploader.dart
lib/presentation/providers/monetization_providers.dart
lib/presentation/providers/billing_providers.dart
lib/presentation/providers/referral_providers.dart
lib/presentation/screens/monetization/{upgrade,subscriptions,referrals}_screen.dart
supabase/functions/monetization-api/
supabase/functions/play-billing-notifications/
supabase/functions/monetization-worker/
supabase/functions/_shared/monetization/
supabase/tests/database/monetization_security.test.sql
test/domain/course_access_policy_test.dart
test/data/monetization_account_isolation_test.dart
test/data/referral_receipt_outbox_test.dart
```

Adapt filenames to established project conventions during implementation, but preserve the responsibility boundaries. Do not create another independent entitlement decision inside a screen.

## 2. Ordered PRs with completion gates

### PR 1 — Domain policy and curriculum correctness

Build pure access/admission entities and explicit phase-local progression. Import the campaign manifest and decision fixtures into Dart tests. Keep monetization disabled so the existing full-course path remains available until rollout.

**Done when:** A1 units 28 and 30 do not require A2 completions; placement never adds commercial access; existing staff access still works; purchase/grants never alter XP or lesson progress; all boundary/expiry/union fixtures pass. Update existing progression tests to the deliberate phase-local behavior, not simply delete failing assertions.

### PR 2 — Backend schema, authorization and signed snapshots

Add new forward-only migrations, private schema, grant/window/account tables, safe read endpoints and snapshot signer. Add owner-select RLS and deny client mutation. Load a reviewed campaign manifest into server configuration; keep its hash and version immutable. Build one backend access resolver shared by snapshot generation and AI authorization.

**Done when:** anonymous users cannot manufacture grants, authenticated users cannot read another user's data, all service RPC execution grants are explicit, expired staff access stays expired, and snapshot signature/account/revision checks have cross-language test vectors. A local database reset and migration from the existing schema both pass.

### PR 3 — Android purchases and backend reconciliation

Implement products, purchase intents, Store adapter, verification, durable jobs, acknowledgement, external notification auth and reconcile worker. Build a minimal subscriptions/settings UI to exercise purchase/restore before enabling any course restriction. Stub Store/Play adapters in tests; run real license-tester scenarios separately.

**Done when:** Core and AI can be purchased independently; pending purchases grant nothing; account mismatch never transfers ownership; app termination after charge recovers on restore; grants commit before acknowledgement; expired/canceled/grace/hold states match the state table; notification replay and out-of-order delivery are safe. Store prices and renewal terms are visible. Resolved native Billing version is supported for release.

### PR 4 — Referral evidence and transactional allocation

Implementation slices: 4a is the private database, pinned manifest, attribution and transactional allocation; 4b adds authenticated API/Integrity/idempotency and durable processing; 4c adds Flutter claim capture, actual player evidence and local outbox upload. Keep every slice disabled until the complete Phase 4 acceptance gate below passes.

Implement code/claim, receipts, manifest validation, integrity challenges, identity waiting/review and locked allocation. Add local receipt outbox to the existing lesson completion transaction. First use manual-code entry; App Links/install-referrer attribution can be included only when its hosting path is verified.

**Done when:** a normal learner completing the first two units grants exactly two units; no subscription is required; skipped/incomplete coverage does not qualify; retries do not double-grant; simultaneous completions allocate distinct units; the fifteenth paid unit is ID 30; extra milestones cannot grant A2/AI. Offline completion uploads after reconnect and account switching cannot move receipts. A crash at each transaction boundary preserves the appropriate retry state.

### PR 5 — Course paywall and all access surfaces

Compose domain policies into providers, route guards and repository admission. Add product/referral explanations and the three monetization screens. Preserve review/history/reference functionality and filter new audio downloads. Offer “Subscribe” and “Invite friends to unlock units” at an A1 boundary; no referral reward promise for A2.

**Done when:** every access surface in the specification is covered; loading is never mistaken for a paywall; prices are Store-sourced; per-product restore and management work; an admitted lesson can finish within its bounded permit; cancellation preserves permanent units and all learning history. Accessibility, large text, offline states and all supported UI locales are checked.

### PR 6 — AI subscription and spend protection

Separate conversation/summary authorization and quotas from course feedback. Implement server-owned prompt inputs, daily reservation counters, bounded context/output, replay and spend ceilings. Show quota and renewal behavior clearly in chat and upgrade UI.

**Done when:** AI-only buyers can chat, Core-only buyers can use course grammar/writing but cannot chat, referral ownership never grants AI, spoofed operation names/lesson IDs cannot bypass authorization, parallel requests cannot exceed the quota, retries cannot double-call the provider, and provider uncertainty has a safe visible state. Canceling one subscription does not affect the other.

### PR 7 — Existing-user migration, lifecycle and privacy

Implement fixed-T0 migration/claim jobs, safe deletion/export, support recovery and operating dashboards. Update privacy wording for purchases/referrals and Play Data Safety declarations as applicable to actual collected data. Keep current no-ads description true. Test legacy Google link/switch flows with the new caches and queues.

**Done when:** rerunning migration is idempotent, reinstall cannot restart grace, prelaunch learners retain exact granted units, anonymous users are not stranded in purchase or referral flows, and deleting either side of a referral does not remove someone else's earned unit. Account exports contain no tokens or other learners' identifying data.

### PR 8 — Release verification and staged activation

Ship compatible clients with flags off. Run the device and Play test matrix, publish support/help text, take the legacy snapshot at the documented cutoff and activate only the tested cohort. Verify real backend configuration and alert delivery. Use the rollback switches below; do not revert database migrations or delete entitlements.

**Done when:** all release gates pass and a small monitored cohort completes free learning, purchase, restore, referral reward and AI use end to end. Production activation is a distinct release action after implementation review.

## 3. Required automated scenarios

| Area | Assertions |
|---|---|
| Free boundary | Units 1–2 commercially available; unit 3 denied; all A2 denied without another source. |
| Progression | Free does not bypass lesson order; paid does not bypass lesson order; A1 final units depend only on A1; explicit placement only changes progression. |
| Permanent reward | IDs follow `3..15,28,30`; legacy grants are skipped; temporary Core is ignored for allocation; max two events per referee. |
| Final reward | Fourteenth reward is unit 28; fifteenth is unit 30; sixteenth returns cap reached, not an A2 credit. |
| Concurrency | Two qualified claims at once receive distinct units; two retries of one milestone produce one grant; two jobs competing for the final unit create one grant. Use real PostgreSQL transactions, not just mocks. |
| Receipt quality | Missing/duplicate/foreign exercise, wrong manifest/hash, skipped item, missing teaching acknowledgement and forged claim ownership are rejected or nonqualifying as defined. Incorrect but complete participation qualifies. |
| Out-of-order receipt | Unit 2 receipts can arrive first and wait; later unit 1 qualification awards ordinal 1 then 2 exactly once. |
| Identity | Self/same linked identity denied; anonymous held until link; Google switch cannot carry claim to another account; same campaign cannot be claimed twice. |
| Integrity | Expired nonce, replay, wrong request hash/account/package/certificate fail; same committed operation returns its original response without consuming a new nonce. Unsupported device has an explicit review route. |
| Billing state | Pending, active, grace, cancellation-before-expiry, exact expiry, hold, effective pause, revocation and refund-without-revocation each follow the mapping. |
| Billing crash safety | Process death before/after provisioning and acknowledgement recovers; duplicate SDK events/restores do not double-provision; stale lease result cannot overwrite new state. |
| Notification auth | Wrong issuer/audience/service-account email/signature rejected; valid duplicate acknowledged; database failure does not acknowledge; unknown product/package cannot grant. |
| Offline | Free/permanent units survive network failure; paid access stops at the earlier of expiry and seven-day verification lease; backwards clock cannot extend it; snapshot with wrong user/signature/revision denied. |
| Account transition | Late async response from A is ignored after switching to B; receipt upload pauses; pending purchase result cannot attach to B; rollback restores A only before target commit. |
| Deletion/export | Referee deletion preserves referrer grant; beneficiary deletion removes beneficiary access; safe export omits secrets; subscription management explanation is present. |
| Learning persistence | Referral network errors do not prevent local XP/completion; duplicate attempt insert does not enqueue duplicate evidence; account restore and existing checkpoints still work. |
| AI | Core ≠ AI; summaries cannot bypass quota; random lesson ID cannot authorize feedback; same request key/digest reserves once; different payload conflicts; unknown provider result is not redispatched automatically. |
| Migration | Fixed T0, no reinstall reset, no placement-only permanent grants, bounded offline claim window, exact-unit grant union, migration replay no duplicate records. |
| UI | All denial states distinct, localized Store prices, screen reader labels, large text, back navigation from paywall, offline restore messaging, separate Core/AI renewal displays. |

Existing regression suites to extend or retain include `test/curriculum_access_policy_test.dart`, `test/curriculum_entitlement_repository_test.dart`, `test/data/curriculum_entitlement_security_test.dart`, `test/next_lesson_level_test.dart`, `test/curriculum_phase_display_test.dart`, `test/curriculum_path_item_test.dart`, `test/domain/continue_lesson_selector_test.dart`, `test/data/lesson_attempt_persistence_test.dart`, `test/data/google_auth_account_safety_test.dart` and account export/restore/sync contract tests.

The shared JSON decision fixture is a contract, not an implementation or proof that these tests already pass. Both Flutter and Deno test loaders should consume it where relevant; SQL tests assert the same reward outcomes under real constraints and concurrent transactions.

## 4. Commands and real-device verification

Use the project's configured Flutter version and Deno/Supabase versions from CI. After adding dependencies or Drift tables, run the repository's code-generation workflow and commit generated files consistently. Do not hand-edit generated Drift code.

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze --fatal-infos
TZ=Europe/Prague flutter test --coverage
deno fmt --check supabase/functions
deno lint supabase/functions
deno test --allow-env supabase/functions
supabase start
supabase db reset
supabase test db
python3 tool/test_referral_concurrency.py
supabase db lint --level warning
git diff --check
```

Also run `deno check` for all existing and new entrypoints, the existing changed-line coverage gate, and Android/iOS/macOS compile jobs. Confirm the repository still uses `build_runner` before invoking generation on a rebased implementation branch. Supabase commands above must target the local stack, never the production project; deployment smoke tests use staging credentials and explicit project checks.

Real Play license-tester matrix: new purchase for each product; pending approval/decline; purchase while network disconnects; kill/restart before client verification; restore after reinstall; same Store account with a different Czechify account; renew; cancel; expire; grace; hold; revoked purchase; both subscriptions with different dates. Use accelerated test renewals and verify server records, not just UI badges. [Play billing tests](https://developer.android.com/google/play/billing/test).

Real referral matrix: share to already-installed Android app; Play install via referrer; manual code; interrupted onboarding; anonymous learning followed by link; unit 2 uploaded before unit 1; complete offline and reconnect; two different friends finishing simultaneously; eight friends reaching the full-A1 boundary; account deletion afterward. Test production-signed/internal-track Integrity behavior separately from debug emulators.

## 5. Flags, configuration and rollout

Use server-assigned cohorts and versioned configuration. Suggested independent controls:

- `course_paywall_enabled`: controls commercial course restriction for compatible cohorts; emergency off restores ordinary learning progression.
- `play_checkout_enabled`: can pause new sales while existing purchase verification/restore continue.
- `referral_claims_enabled`: stops new claims without deleting current claims or grants.
- `referral_processing_paused`: queues receipts for later processing; UI states the delay.
- `paid_chat_required`: enable only for a cohort with a compatible purchase/restore client.
- `ai_provider_requests_enabled`: emergency spend switch; preserve history and explain temporary downtime.

Flags never fabricate paid ownership or delete earned units. Offline clients use their last signed policy until refresh, so a remote flag cannot guarantee an immediate offline change. Do not disable billing notification intake or acknowledgement workers when pausing new sales.

Required deployment configuration: Play package/product/base-plan allowlist; Play Developer API service account; Google push issuer/audience/email; token encryption and account-binding keys; JWS signing key plus public-key distribution; immutable campaign manifest; Integrity cloud-project/signing-certificate settings; worker scheduler credentials; database secrets; AI caps/model settings; launch cutoff/grace; support and store-management URLs. Use separate staging and production resources and test accounts.

Recommended activation: internal testers → closed external cohort → 10% compatible new users → 50% → all compatible users. Keep assignments stable per account. Progress after at least 48 hours per external stage and observed successful purchase, restore and referral events; low traffic means extend the stage rather than treating absence of errors as evidence. Existing-user migration is a separately audited cohort.

Immediate pause triggers: duplicate or wrong-account grant, cross-account data exposure, an acknowledged purchase without committed provisioning, or course access loss beyond its contracted expiry. Other initial investigation thresholds: purchase verification p95 above 30 seconds for 30 minutes, unresolved eligible acknowledgement above one hour, referral queue age above 15 minutes, or sustained provider-cost ceiling trips. For small samples inspect every failure instead of relying on unstable percentages.

Rollback procedure: pause checkout/new claims if needed, disable course paywall for affected cohorts, preserve grants and local progress, keep verification/acknowledgement/restore running, pause only the faulty reward worker, then reconcile affected event IDs. Fix data through audited compensating operations; never reset all subscribers or drop the ledger.

## 6. Measurement and definition of done

Collect minimal first-party events: free-unit started/completed, paywall shown with reason, checkout started/result, subscription state changed, referral claimed, milestone qualified, reward granted/cap reached, AI entitlement denial/quota/cost aggregate. Use opaque account/event IDs, schema versions and server timestamps; deduplicate server monetary/reward events through the outbox. Do not log message content, purchase tokens or Age Signals.

Measure install/claim → first unit → second unit → purchase conversion, renewal/churn by product, referral completion rate, invitee retention, rewards per retained learner, suspected abuse and support load. Distinguish actual cash acquisition spending from estimated forgone subscription contribution. Referral signups are not automatically incremental retained customers.

Release completion means: all invariant/security tests pass; real Store restore and notification lifecycle pass; all admission surfaces are covered; no account data bleed; receipt retries and concurrency are proven; migration and rollback rehearsed; product prices/limits/privacy wording match reality; and support can trace a purchase or reward through opaque event IDs. Do not label the implementation finished merely because the paywall renders.
