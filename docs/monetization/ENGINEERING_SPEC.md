# Engineering specification

Read [README](README.md) for confirmed requirements and explicitly proposed defaults. Normative words below describe the chosen implementation contract, including those defaults.

## 1. Architecture and invariants

Separate four concepts:

1. **Learning progression:** which lesson the learner is ready to take.
2. **Commercial access:** which units/features the account currently owns or rents.
3. **Referral qualification:** evidence accepted for this campaign, independent of ordinary progress sync.
4. **Presentation:** cards, paywalls and messages explaining the first three.

No UI widget may create an entitlement. Only a backend billing verification, a backend referral transaction, a controlled migration or a staff operation can grant access. RLS allows clients to read their own safe projections, never to write grants, purchase state, referral milestones or campaign configuration. A subscription purchase does not create lesson completions, XP or placement results.

The application keeps working offline for free and permanently granted units. Network failure must never erase progress, remove a permanent grant, acknowledge a purchase as successfully provisioned, or award a referral twice. An unknown server state is represented as unknown, not expired or paid.

### Proposed modules

| Layer | Responsibility |
|---|---|
| `CourseAccessPolicy` | Pure computation of commercial unit access and its source. |
| Existing `CurriculumAccessPolicy` | Phase-local lesson progression, independent of price. |
| `LessonAdmissionPolicy` | Intersection of progression and commercial access; structured denial reason. |
| `MonetizationRepository` | Fetch/validate signed snapshots; account-scoped cache and refresh. |
| `BillingRepository` | Store stream, query offers, launch purchases, send tokens, restore and reconcile. |
| `ReferralRepository` | Code/claim, local receipt outbox, status and retry. |
| Backend access service | Only source for live AI access and signed course snapshots. |
| Backend workers | Durable purchase notification processing, acknowledgements, reconciliation and referral processing. |

Use injectable clocks, store adapters and auth/account epochs. Keep Store SDK objects out of domain policy objects and tests. Use integer unit IDs, UTC timestamps, UUID identifiers and explicit string enums. Prices shown at checkout come from the Store, not a hardcoded currency conversion.

## 2. Exact access policy

### Commercial unit set

For the current account, commercial access is the union of:

- campaign free unit IDs `{1,2}`;
- active permanent unit grants from referrals or legacy migration;
- all published A1/A2 units during active Core or migration grace;
- units allowed by the existing active staff/support course entitlement.

Each grant names a specific unit. A placement test, level selector, local `isCompleted`, downloaded audio or a stale UI route cannot add to this set. Staff curriculum access does not imply AI access; a future AI staff entitlement must be explicit.

Return sources as a set, for example `free`, `referral`, `legacy`, `core`, `migration_grace`, `staff`. Cancellation removes only the expiring source. A unit with a referral and a subscription remains available through its permanent source.

### Learning progression must become phase-local

The current evaluator sorts A1 and A2 together by `orderIndex`. This incorrectly creates cross-level dependencies because A1 units 28 and 30 follow several A2 IDs. First compute an ordered list per phase from the curriculum manifest. Within the selected phase, preserve existing lesson order and prerequisite semantics. A1 progression must never require an A2 completion.

Placement can waive learning prerequisites through a phase-specific target, but cannot waive payment. Replace ambiguous global placement comparisons with `{phase, through_unit_id}` after mapping existing stored placement to its actual phase. A2 starting-level selection uses the existing level-selection policy, then sequences within A2. Core pays for A2 access; it does not auto-complete A1. Keep staff `unlockAll` as its deliberate course-wide progression override.

The admission result is one of `allowed`, `loading`, `payment_required`, `prerequisite_required`, `reverification_required`, `account_transition`, `invalid_content`. If a unit is commercially locked, show `payment_required` even if it also lacks prerequisites; otherwise show the learning prerequisite. `loading` is not a paywall.

### Surface behavior

| Surface | Rule |
|---|---|
| Course map and Continue | Use the same admission policy; Continue finds the next playable lesson. If learning has reached a commercial boundary, show a clear upgrade/referral action. |
| `/lesson/:id` and loader | Check account/content/admission before loading a new attempt, including deep links and restored routes. |
| Checkpoint resume | Same access gate as a new lesson unless resuming an already admitted, unexpired attempt session. |
| Placement and level switch | Change progression only; display paid A2 eligibility honestly. |
| `/pronunciation/:id` | Resolve exercise to lesson/unit and apply its access policy; unrestricted dictionary pronunciation remains free. |
| `/transfer/:id` | Previously assigned review remains available; prevent minting new assignments from locked lessons. |
| Review | Existing introduced cards and learning history remain usable. Do not introduce new cards from a locked unit, even if local progress says completed. |
| Exams | A1 requires commercial ownership of all A1 units, or current Core/grace/staff; A2 requires current access to all A2 units. Existing exam learning requirements also apply. Results remain readable. |
| Grammar/reference/copybook | Keep independent reference pages, saved notes and previously generated feedback readable. Interactive exercises attached to lessons use lesson admission. |
| Audio prefetch | Only schedule new unit downloads for commercially accessible units; preserve cached files and progress on expiry. Recheck eligibility when a queued batch starts. |
| Chat | History remains readable. New conversations and summaries require AI entitlement and quota. |

Allow an admitted lesson attempt to finish for up to two hours after admission, even if Core expires meanwhile. Bind the permit to account ID, account epoch, lesson ID and attempt UUID; revoke it immediately on account switch. It cannot start another lesson or authorize AI chat. Recheck long-lived sessions at each new attempt. Server operations require their own live authorization.

## 3. Subscription products and lifecycle

Configure two Play subscriptions, proposed IDs `czechify_core` and `czechify_ai`, each with a `monthly` base plan and target Czech prices 250 and 150 CZK respectively. Verify actual Store-localized prices in the release track. Do not promise a single 400 CZK bill: these are two purchases, potentially with different renewal dates. A combined marketing card launches one selected purchase at a time and reports each result separately. No bundled third SKU or tier replacement flow in v1.

Core cancellation does not cancel AI, and AI cancellation does not cancel Core. The account screen shows both renewal states, localized prices and individual management links. Before buying AI alone, show its exact inclusions and the fact that paid course access is separate. No subscriptions are required to claim or qualify a referral.

### Purchase protocol

1. Require a linked account; support the existing safe Google account-link/switch flow.
2. Backend creates a short-lived purchase intent bound to account, platform and permitted product; return a stable opaque `obfuscatedAccountId` derived server-side from account ID. Do not use email or raw Supabase user ID as the store identifier.
3. Subscribe to the Store purchase stream before launch. Pending remains pending and grants nothing.
4. Send the purchased/restored token and intent reference to the authenticated backend. Backend queries Play, verifies package, product, purchase state, account binding and token ownership. Device assertions cannot override Play state.
5. Transactionally persist the verified purchase and resulting feature validity, then acknowledge on the backend. Retry acknowledgement durably on failure; never lose the purchase because the client closes.
6. Fetch the new signed entitlement snapshot. Only then show access as provisioned. Client completes/clears its SDK transaction as required by the selected adapter, after server provisioning; test that backend acknowledgement and SDK completion cooperate.
7. Restore queries Store purchases and submits each token. A token bound to another Czechify account produces an account-recovery explanation, never an automatic reassignment.

Tokens, not order IDs, are the purchase identity. Follow linked replacement tokens when Play supplies them, even though v1 offers no tier-switch UI. Acknowledge eligible initial purchases within Google's required window; Google documents a three-day acknowledgement deadline and different handling for pending purchases. [Billing security](https://developer.android.com/google/play/billing/security), [subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions).

### State-to-access mapping

| Verified state | Access |
|---|---|
| Pending, pending canceled, unverified | None from that purchase. |
| Active | Through verified line-item validity. |
| In grace period | Through the latest verified grace validity; refresh promptly. |
| Canceled but not yet expired | Continue until verified paid-through time. |
| Paused before pause takes effect | Continue until current verified access ends. |
| Paused effective, on hold, expired | No ongoing subscription access. |
| Revoked | Remove affected access when authoritative verification confirms revocation. |
| Refunded | Re-fetch authoritative entitlement state; do not assume every refund revokes immediately. |
| Play temporarily unavailable | Preserve last verified bounded cache; do not extend validity. |

Process notifications as hints to re-fetch Play state, not commands to grant days. Serialize verification per purchase lineage. Out-of-order notifications must not resurrect revoked access or overwrite a fresher state. A per-lineage worker lock spans the fetch/apply sequence; duplicate requests queue behind it. Periodic reconciliation covers missed notifications and acknowledgement backlog.

Use a Flutter adapter with a supported native Play Billing dependency. Inspect the resolved Gradle dependency, not just the Dart package version: Billing Library 7's normal update deadline passed on 2026-08-31; 8's deadline is 2027-08-31. [Deprecation schedule](https://developer.android.com/google/play/billing/deprecation-faq.html).

## 4. Referral qualification and grants

### Attribution

Expose `https://eminentsite.cz/czechify/r/<opaque-code>` with Android App Links, Play install-referrer attribution and a manual code fallback. The deployment must provide verified association files and preserve the code on the store redirect. If that web path is unavailable, manual entry is sufficient for the first release; do not pretend deferred linking works without an end-to-end test. Install referrer transports attribution, not identity proof. [Install Referrer library](https://developer.android.com/google/play/installreferrer/library).

Only linked accounts can publish an invite code. An invitee may reserve one code within seven days of account creation and before completing unit 1. The client checks local completion and the server checks already-synced unit completion as eligibility signals; neither is reused as reward evidence. Freeze the referrer once claimed; each campaign invitee has one claim, including across devices. Reject self-referral, same linked identity, expired campaign, malformed/revoked code and an account already participating under another referrer. No rewards for ratings, reviews or installing alone.

An anonymous invitee can learn both units and submit receipts; hold rewards until linking succeeds. Google linking in place retains the same user ID. Switching to an existing Google account does not import the anonymous claim or receipts. UI must explain this before switch confirmation, using the existing account-safety workflow.

### What counts as completing a unit

Use the immutable campaign manifest for the first eight lessons, not client-supplied lesson counts. Each lesson needs one accepted complete attempt under that manifest version. Each authored initial exercise must appear exactly once in normalized coverage, with a non-skipped interaction; teaching exercises require their acknowledgement. Incorrect answers still count as learning participation. Repair and transfer attempts do not substitute for missing initial coverage. Do not set a score threshold or require a purchase.

Only attempts started after the claim was reserved are eligible; record the claim ID when the attempt begins. Client timestamps cannot independently prove this ordering, so enforce the normal client flow and use server receipt history/risk review for anomalies. Keep ordinary lesson completion unchanged. For referral qualification, a skipped exercise leaves that lesson unqualified; show which lesson needs completing again. Repeating a whole lesson with complete coverage can qualify it. Four accepted lessons qualify unit 1; four more plus unit 1 qualify unit 2. Unit 2 arriving first waits for unit 1, rather than being rejected forever.

The existing `ExerciseAttemptEvidence` has phase/outcome IDs but not an authoritative teaching-acknowledgement record. Add versioned receipt coverage that explicitly distinguishes `teaching_acknowledged` from answered outcomes. Emit it from real player interactions; never synthesize coverage from `lesson_progress.isCompleted`. Keep it in the same local commit as the lesson attempt.

This proves that the normal application reported complete participation. Bundled answers and client-side events cannot prove a unique human or prevent a determined modified client from fabricating learning. Strengthen with linked identity, server-side immutable milestones, request-bound Play Integrity, account/device risk checks and a review queue. Avoid a claim that completing two units guarantees genuine users.

### Offline receipts and anti-abuse

Persist receipt and outbox entry atomically with the local lesson attempt. Upload after reconnecting with a fresh server nonce and a Play Integrity standard token bound to the canonical receipt hash, account, claim, campaign and nonce. Offline timestamps are diagnostic only; server receipt time determines the campaign transaction ordering. Integrity at upload attests the requesting app/device context, not historic offline activity. Backend validates package/certificate/request binding and replay policy. [Standard Integrity requests](https://developer.android.com/google/play/integrity/standard).

Transport failures stay retryable. Invalid signatures or mismatched request hashes reject the submission. Unsupported integrity, unusual velocity or repeated device association sends a claim to review; it must not erase learning progress or silently label someone fraudulent. Do not reject solely on shared IP or a fast lesson time. Do not claim an installation ID uniquely identifies a person. Keep Play Age Signals out of referral analytics and fraud features.

Published rewards have exactly these semantics:

- Milestone 1 grants the earliest still-unowned paid A1 unit.
- Milestone 2 grants the next, at most two reward events per invitee.
- Ignore temporary Core, grace and staff access when choosing a permanent unit. Subscribers can earn for after cancellation.
- Skip active permanent legacy and referral grants. Never grant an already-owned unit to consume a reward.
- If all paid A1 units are permanently owned, mark further qualified milestones `cap_reached`; no banked A2, AI, cash or future-level credit.
- Referral grants are permanent unless a documented fraud correction revokes that specific grant. Ordinary cancellation or invitee account deletion cannot revoke them.

Serialize allocations with a database lock on the beneficiary's `monetization_accounts` row. A uniqueness constraint on claim/milestone prevents duplicate rewards, and a second constraint prevents duplicate unit grants. Seven complete invitees produce units 3–15 and 28. The next first milestone produces unit 30. Never calculate the next unit using `last_unit_id + 1`.

### Referral UI

Show permanent units earned out of 15, the next unit, and privacy-preserving invite rows such as “Friend 1: first unit complete; second unit in progress.” Do not expose email, real names or study details without separate consent. Distinguish `waiting_for_learning`, `waiting_for_account_link`, `verification_pending`, `reward_granted`, `cap_reached`, `needs_review`, `rejected`. Never promise a reward before the server commits it. Provide a way to contact support for verification disputes.

## 5. Offline, identity and migration

### Signed cache

Backend signs a canonical snapshot containing schema version, user ID, monotonic entitlement revision, issued time, feature validity, explicit permanent grants and campaign revision. Embed verification public keys in the app; store private keys only server-side. Use a vetted JWS implementation and a fixed algorithm/key-ID allowlist. Retain verification keys while any permanent snapshot may still exist; key retirement requires a planned online refresh strategy.

For one eligible purchase, paid offline validity is `min(purchase.valid_until, purchase.verified_at + 7 days)`. For multiple eligible purchases of the same feature, sign `feature.offline_valid_until` as the maximum of those individual bounds; never combine one purchase's later expiry with another's newer verification time. Each source retains its own last authoritative Store verification time. Re-signing a snapshot or verifying the other product cannot refresh this clock. Permanent grants have no routine offline expiry. Known revocations apply on next successful refresh. This leaves a deliberate offline revocation window; client storage and clocks are not tamper-proof DRM.

Within a running process, derive time from a server anchor plus monotonic elapsed time. Across restart, use the persisted maximum observed server-adjusted wall time so moving the clock backwards cannot extend paid validity. Major clock inconsistency returns `reverification_required` for paid features and retains free/permanent units. Refresh on sign-in, resume, purchase, restore and detected connectivity, with backoff and coalescing. Never replace a higher revision with a lower one for the same account.

### Account isolation

Every request, cached snapshot, purchase intent, receipt and async callback belongs to an account ID and epoch. Increment epoch at transition start; cancel streams/workers and ignore late completions from the old epoch. Clear in-memory commercial state before exposing the target account. Preserve the current transactionally safe account-switch implementation, including rollback before target commit.

Add monetization caches and pending receipt queues to `clearLearnerDataRows`, provider invalidation and account export/restore policy. Do not put server-owned rows into generic sync upserts. On logout/switch, do not upload one account's receipts under another JWT. Anonymous in-place identity linking preserves account ownership; account switching never merges it automatically.

On account deletion, explain that the Store subscription must be managed separately. Canceling Czechify data is not Play cancellation. Delete private referral learner details, preserve other users' earned grants, and tombstone purchase ownership for a defined recovery workflow. A support recovery must require a verified Store restore and explicit ownership reconciliation, never a client-supplied new account ID alone. Financial retention must follow the configured privacy/legal policy; do not leave it implicit in cascading foreign keys.

### Existing users

Use a fixed UTC launch cutoff `T0` and `legacy_grace_until = T0 + 30 days`, not 30 days from each reinstall. The migration takes one immutable server snapshot of accounts created before T0. A unit is reached when its snapshot contains a lesson row with `is_completed = true` or a non-null `last_attempted`; empty default progress rows do not count. Grant those exact units, plus the next unit in each participating phase only when all required lessons of its preceding units are complete. Ignore placement for this migration calculation. Offline claims can additionally establish a reached unit using a persisted local attempt. Never mark unfinished lessons complete to establish commercial access.

Server progress has limited evidence and is client writable. This is a deliberate one-time goodwill migration, not referral proof. For offline-only prelaunch learners, allow one legacy claim per eligible pre-T0 account, submitted within 30 days of T0, using the old local attempt/progress export; flag implausible claims for support. The pre-T0 account check limits the concession but cannot fully authenticate historical offline dates. Newly created accounts after T0 get the normal two-unit rule.

Materialize exact permanent unit IDs and the fixed grace end in a rerunnable migration ledger. Dry-run aggregate counts and sample accounts, then run the grant operation once per account with a unique migration ID. Users see an explanation before the first paywall. A2 legacy grants, if any, remain A2-only; they do not consume referral rewards.

## 6. AI separation and cost controls

The existing proxy supports `conversation`, `conversation_summary`, `grammar_check` and `writing_evaluation`. Require AI entitlement only for the first two. Preserve grammar/writing that belong to accessible course exercises, plus existing speech behavior. Do not accidentally turn Core learning exercises into a second subscription requirement.

For course operations, require a real lesson/exercise reference; backend resolves its unit and operation against a published server content manifest and checks access. Build prompts server-side from approved exercise metadata and bounded learner input. Do not accept arbitrary client system prompts or a claimed `operation=grammar_check` as a bypass to chat. Previously introduced review exercises may be authorized through a separate recorded review assignment; do not accept any lesson ID supplied by the client as proof of such an assignment.

For AI chat, reserve quota atomically before calling the provider. A client retry with the same request ID and same payload must not reserve twice or create a second provider request. Store short-lived request status and encrypted response replay data separately from telemetry; replay is account-scoped. Unknown provider outcomes consume the reservation conservatively and return `result_unavailable`, not an automatic expensive retry. Expire content replay after 24 hours and retain a content-free idempotency tombstone for seven days.

Default allowance: 20 conversation turns/day, 60 internal summaries/day, per-account and project burst limits, bounded input/context, existing output caps (conversation 700 tokens; summary 400) and a configurable project daily spend ceiling. Summaries must reference a server-known chat session and minimum new-turn count; users cannot call unlimited summaries directly. Separate paid chat quotas from course feedback and speech quotas.

At the spend ceiling, stop new paid provider requests with a clear temporary-unavailability state; record it as an operational incident. The AI purchase page states daily limits. Quotas protect margins but are not a substitute for budgeting against observed token use. Log token counts/model/cost estimates, not learner message text. Do not grant AI to course staff overrides or referral owners automatically.

## 7. Release scope and known limitations

Production activation requires accurate prices, recurring-payment disclosures, cancellation/restore UI, privacy updates and support procedures. Subscription value and terms must be clear. [Play subscription policy](https://support.google.com/googleplay/android-developer/answer/9900533?hl=en).

Old clients already contain course content and can continue opening it locally. A server flag cannot retroactively secure those assets. Introduce backend protocol compatibility checks for paid AI and referral endpoints, ship a compatible client, then enable the cohort. Do not impose a global AI backend requirement before supported clients can purchase/restore. Inventory all currently supported platforms before activation; either ship their complete flow or keep that platform/cohort on the legacy policy explicitly.

No plan can verify store settlement, human uniqueness or purchase restoration through unit tests alone. The release checklist includes real devices and Play license-test accounts. The accepted v1 tradeoff is low-friction growth with measurable fraud and cannibalization, not perfect identity verification or DRM.
