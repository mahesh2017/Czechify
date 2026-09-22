# API and database contracts

These contracts implement [the engineering specification](ENGINEERING_SPEC.md). Names are proposed implementation names. Freeze them in migrations and generated client models before UI work; do not implement competing definitions in individual screens.

## 1. Trust boundary and schema rules

All times are `timestamptz` UTC. Validity intervals are half-open: access is valid when `now < valid_until`; equality means expired. Use UUID primary keys except stable content IDs and explicit configuration keys. Monetary amounts in internal analytics use integer minor units with an ISO currency, never floating point or an assumed conversion rate.

Use a non-exposed `monetization_private` schema for sensitive purchase and risk data. Safe projections can live in `public` with owner-select RLS and no client writes. If RPC functions must be in `public` for the Supabase client, grant execution only to the service role. `SECURITY DEFINER` functions must set a fixed empty/restricted search path, fully qualify objects and explicitly revoke default public execution. [Database functions](https://supabase.com/docs/guides/database/functions).

Every account endpoint validates the Supabase JWT using the server auth client and derives the acting user from that result. Never trust a body `user_id`. Anonymous users also use the `authenticated` role, so linked-account checks must inspect the verified identity, not merely the role. [Anonymous authentication](https://supabase.com/docs/guides/auth/auth-anonymous).

Backend service credentials, Play service-account credentials, token-encryption keys, snapshot signing keys and HMAC keys never enter Flutter, committed fixtures, crash reports or analytics. Safe API errors never echo a purchase token or another account's identity.

## 2. Tables and constraints

### Account state and course grants

| Table | Required columns and constraints |
|---|---|
| `monetization_accounts` | `user_id` PK; `revision bigint default 0`; `policy_cohort`; `created_at`; `updated_at`. Row is also the lock target for all permanent grant writers. |
| `course_unit_grants` | `id`, `user_id`, `unit_id`, `source` (`referral`,`legacy`,`staff_permanent`), `source_key`, `campaign_id nullable`, `created_at`, `revoked_at nullable`, `revocation_reason_code nullable`. Unique `(user_id,source,source_key)`. Partial unique `(user_id,campaign_id,unit_id)` for active referral grants. No client insert/update/delete. |
| `course_access_windows` | `id`, `user_id`, `kind` (`migration_grace`), `starts_at`, `ends_at`, `source_key`; check `ends_at > starts_at`; unique `(user_id,kind,source_key)`. |
| `legacy_migration_runs` | `migration_id`, fixed `cutoff_at`, fixed `grace_ends_at`, manifest revision, dry-run summary, applied timestamp, operator audit ID. |
| `legacy_migration_claims` | Unique `(migration_id,user_id)`; input fingerprint, resolved unit IDs, status (`applied`,`needs_review`,`rejected`), server received time. |
| Existing `curriculum_entitlements` | Keep its existing expiring staff/support course override. Read it when deriving course access; do not overload it with billing or AI fields. |

All permanent-grant writers lock `monetization_accounts` first, including migration and support adjustments. Different grant sources may refer to the same unit; the access evaluator computes a union. Referral allocation skips every active permanent grant across sources. Increment the account revision in the same transaction as an effective access change. Revocation is an audited update, never an unexplained row deletion.

### Billing and durable jobs

| Private table | Required columns and constraints |
|---|---|
| `billing_products` | Product ID, platform, base plan ID, feature (`core`,`ai_chat`), enabled flag, allowlisted package ID. Unique platform/product/base-plan tuple. Prices remain store-sourced. |
| `purchase_intents` | UUID, owner, product/base plan, stable obfuscated account reference, created/expires time (30 minutes), consumed time. Expiry prevents a new checkout; it does not invalidate a pending purchase subsequently verified by Play. |
| `store_purchases` | UUID, platform, unique `token_digest`, encrypted token, owner or deleted-owner tombstone, product, base plan, lineage ID, linked-token digest, normalized state, raw state enum, `valid_until`, `auto_renewing`, acknowledgement state, last verified time, source-response fingerprint, last error code. |
| `feature_entitlements` | Unique `(user_id,feature,purchase_id)`; starts/ends time, normalized status, last verification. Do not overwrite one purchase's state with another token's data. Active feature access is the union of eligible purchase rows. |
| `billing_notification_inbox` | Unique `(provider,subscription_resource,message_id)`; sanitized event metadata, encrypted purchase token reference if required, received time, job state, attempt count, retry time. No client access. |
| `billing_jobs` | ID, purchase/lineage reference, operation (`verify`,`acknowledge`,`reconcile`), dedup key, `ready/running/retry/done/dead`, attempt count, not-before time, lease owner, lease expiry, monotonically increasing fencing number. |
| `billing_audit_events` | Append-only normalized state transitions and verification outcomes; no cleartext tokens or chat content. |

Store a SHA-256 digest for token lookup and an encrypted token for Play verification. Restrict decryption to billing code. Persist a stable account-binding HMAC version; rotating unrelated secrets must not silently change an existing account's Play binding. Do not use a client-provided obfuscated account ID as evidence of ownership.

For retries use exponential backoff with jitter, 5 seconds through a 1-hour maximum, respecting provider `Retry-After`. Transient authentication/configuration errors alert operators rather than marking every subscription expired. A dead-letter job preserves the last verified entitlement and is visible to support. Acknowledgement jobs receive priority and alert when an eligible purchase remains unacknowledged for one hour.

### Referrals and receipt evidence

| Table | Required columns and constraints |
|---|---|
| `referral_campaigns` | Stable ID, immutable manifest revision/hash, starts/ends/claim-close times, free IDs, ordered reward IDs, per-referee maximum 2, enabled state. Check free/reward sets disjoint; every ID belongs to manifest A1. |
| `referral_codes` | Random public code, owner, campaign, revoked time; unique code and active `(owner,campaign)` code. Codes contain no PII. |
| `referral_claims` | ID, campaign, referrer, referee, created time, identity/risk status, revision; unique `(campaign,referee)`; check `referrer <> referee`. Code is resolved once; later code edits cannot change attribution. |
| `referral_receipts` | UUID, claim, referee, lesson ID, attempt UUID, content revision, canonical digest, normalized coverage, diagnostic attempt times, server received time, identity state, evidence state. Unique `(referee,attempt_uuid)`; repeat UUID with a different digest is a conflict. |
| `referral_lesson_qualifications` | Unique `(claim,lesson_id)`; accepted receipt ID, qualification timestamp. One complete attempt is enough; a later replay cannot unqualify it. |
| `referral_milestones` | Unique `(claim,ordinal)` with ordinal in `(1,2)`; required unit ID, qualified timestamp, status (`waiting_identity`,`needs_review`,`granted`,`cap_reached`,`rejected`), grant ID nullable. `granted` requires a grant ID. |
| `referral_reward_events` | Unique `(claim,ordinal)`; beneficiary, grant ID nullable, outcome (`granted`,`cap_reached`,`rejected`), campaign and timestamp. Use for audit and deterministic responses. |
| `integrity_challenges` | Random nonce digest, account, claim, semantic receipt digest, expiry (10 minutes), consumed operation key; unique nonce digest. Raw attestation tokens are transient. |
| `referral_review_cases` | Claim/receipt, reason codes, opened/resolved time, reviewer and resolution. Never expose private risk signals to other learners. |

Do not cascade deletion of a referee into a referrer's grant. Separate live attribution PII from reward audit identifiers: on account deletion, replace affected references with a non-reversible audit subject/tombstone and clear learner detail. The benefit belongs to the beneficiary account. Deleting the beneficiary removes its active account access but need not delete another learner's own progress.

### Operational idempotency and events

`operation_results`: unique `(actor_user_id,route,idempotency_key)`, semantic request digest, state, safe result, created/expires times. Default retain seven days, but retain financial/referral uniqueness in permanent domain constraints beyond that period. A replay with the same digest returns the original result; a different digest returns `409 idempotency_conflict`.

`monetization_outbox`: domain event UUID, subject account, event type, minimal payload, created/published time. Insert atomically with access changes. Notifications and analytics consume it after commit; failed delivery cannot undo the grant or grant it again.

`ai_request_reservations`: unique `(user_id,request_id)`, operation, semantic payload digest, UTC quota day, reservation state, token usage, optional encrypted replay reference, timestamps. Different payload under one request ID is a conflict. Quota counters and reservations update in one transaction. An `in_flight` lease must not result in a second provider call after expiry when the first outcome is unknown.

### Local Drift migration

After rebasing, allocate the next schema number (currently 8 → 9). Add:

- `monetization_snapshots`: account ID PK, signed payload, revision, server anchor, maximum observed adjusted time, last refresh result.
- `referral_receipt_outbox`: account ID + attempt UUID unique, claim ID, canonical receipt, semantic digest, status, attempt count, next retry, last safe error. Keep account IDs even in an otherwise single-account DB.
- `billing_pending_verifications`: account ID, store transaction reference/token digest, intent ID, retry metadata. Prefer retrieving tokens from the Store on resume; any transient token persisted locally uses platform-secure storage, not plain Drift export.
- If adding an attempt admission/checkpoint field, version its serialization and cover restore from existing checkpoints.

These tables are not cloud-synced through `SyncService`. Commercial snapshots are refreshed from the backend; only receipt payloads go to the referral endpoint. Local export may include safe earned-access and referral status for transparency, but excludes tokens, integrity nonces, encryption material and internal risk signals. Account switch/deletion tests must enumerate these new tables.

## 3. API surface

Proposed Supabase functions: `monetization-api` (authenticated account routes), `play-billing-notifications` (external OIDC push), `monetization-worker` (internal scheduler authentication). Keep project JWT verification enabled for account routes, with explicit handler authentication consistent with the existing project. External Google notifications require different verification. [Edge Function authentication](https://supabase.com/docs/guides/functions/auth).

All mutations except authenticated external notifications accept `Idempotency-Key: <UUID>`. Bodies reject unknown fields and enforce size limits. Standard response metadata: `{request_id, server_time, policy_version}`. GET endpoints return `Cache-Control: private, no-store`. Account APIs never accept arbitrary destination account IDs.

| Method / account route | Request | Successful response |
|---|---|---|
| `GET /configuration` | Supported client/protocol version | Campaign summary, feature flags/cohort, allowed product IDs, protocol minimum; no secrets. |
| `GET /entitlements` | Optional known revision | Signed current snapshot, or explicit unchanged revision plus fresh verified signed snapshot if validity was refreshed. |
| `POST /purchase-intents` | `{product_id,base_plan_id,platform:"android"}` | `201 {intent_id,expires_at,obfuscated_account_id,product_id,base_plan_id}`. Reject anonymous owner or disabled product. |
| `POST /purchases/verify` | `{purchase_token,product_id,intent_id?,source:"purchase"|"restore"}`. `product_id` is required because Play's `subscriptionsv2` lookup is keyed by product. | `200 {status:"provisioned",verification_id,state,access,revision}` (a pending Play purchase is provisioned with `access:false`) or `202 {status:"verification_pending",verification_id,retry_after_seconds:5}`. Token limit 16 KiB; full body 24 KiB. |
| `GET /purchases/status/<verification_id>` | None | Owner-scoped status, safe error, current revision. No token or another owner's details. |
| `GET /subscriptions` | None | Own Core/AI status, paid-through times, auto-renew state, safe management links. Store supplies display price. |
| `POST /referrals/code` | `{campaign_id}` | Existing or newly minted `{referral_code}`. Linked account required. No `share_url` until verified App Links exist; the first release uses manual codes. |
| `POST /referrals/claim` | `{campaign_id,code,attribution_source:"manual"}` (only `manual` until App Links and install-referrer attribution are verified end to end) | `201 {claim_id,status,required_units:[1,2]}`. Same referrer retry returns existing claim. Different referrer returns `409 referral_already_claimed`. |
| `POST /referrals/challenges` | `{claim_id,receipt_digest}` | `201 {nonce,expires_at}` for the authenticated referee: 64 hex characters, valid ten minutes, single use, only its digest stored; 120/account/hour. |
| `POST /referrals/receipts` | Envelope below, with either `integrity_token` or `integrity_unavailable:true` (a device without Play Integrity; the claim goes to review) | `202 {receipt_id,status:"accepted"|"nonqualifying"}`, or the original result for a committed attempt before any challenge or token is checked. `409 challenge_invalid` needs a fresh challenge. Claim ownership required. Max body 64 KiB. |
| `GET /referrals/status?cursor=&limit=` | Friend-number cursor; limit 1–100, default 20 | Permanent units earned, next reward unit/null, own invitee claim and privacy-safe referred-friend progress; cursor pagination 20, max 100. |
| `GET /legacy/status` | None | `{available:false}` until an operator applies an existing-user migration; then `{available:true,cutoff_at,grace_ends_at,claim_window_ends_at,eligible,claim_window_open,legacy_unit_ids,claim:{status,unit_ids}|null}`. The migration ID stays on the server. |
| `POST /legacy/claim` | `{completed_lesson_ids,attempted_lesson_ids}`: unique positive integers, at most 500 each, from before the cutoff | `200 {status:"applied"|"needs_review"|"rejected",unit_ids}` against the latest applied migration; the same record again returns the same answer. Anonymous pre-cutoff accounts may claim. Refusals: `409 migration_not_ready`, `409 claim_window_closed`, `409 already_claimed`, `403 not_eligible`. |

Rate limits initial defaults: purchase-intent creation 10/account/hour, verification 30/account/hour, code creation 5/account/day, claim attempts 10/account/hour, challenges/receipts 120/account/hour. A valid replay from `operation_results` returns before consuming another expensive verification. Device/network signals can constrain abuse, but shared network IP is not a hard identity rule. Return `429` with a retry time; do not delete outbox items.

### Entitlement payload, before JWS signing

```json
{
  "schema_version": 1,
  "user_id": "authenticated-account-uuid",
  "revision": 42,
  "issued_at": "2026-10-01T12:00:00Z",
  "verified_at": "2026-10-01T12:00:00Z",
  "policy_version": "course-access-v1",
  "campaign_id": "a1-referral-v1",
  "manifest_revision": 25,
  "features": {
    "core": {"state": "active", "valid_until": "2026-10-15T12:00:00Z", "offline_valid_until": "2026-10-08T12:00:00Z"},
    "ai_chat": {"state": "inactive", "valid_until": null, "offline_valid_until": null}
  },
  "permanent_unit_grants": [
    {"grant_id": "grant-uuid", "unit_id": 3, "source": "referral"}
  ],
  "migration_grace_until": null,
  "staff_course_until": null,
  "staff_course_unlimited": false
}
```

`staff_course_unlimited` maps an existing unexpired staff override without expiry; the boolean is not an AI entitlement. Top-level `verified_at` refers to the snapshot/account state. `offline_valid_until` is calculated from each eligible purchase's own expiry and authoritative verification time as specified in the engineering document; a routine GET cannot extend it. AI still requires a live server call. The snapshot may include only a backend allowlist of fields. For refreshed snapshots with the same entitlement revision, accept a later signed `verified_at`; reject an older one. A state change increments the revision. Client key lookup uses `kid`, but the allowed signature algorithm is fixed in code. Unknown schema/key produces `reverification_required`, never free-form interpretation.

### Receipt envelope

```json
{
  "receipt": {
    "schema_version": 1,
    "claim_id": "claim-uuid",
    "campaign_id": "a1-referral-v1",
    "content_revision": 25,
    "lesson_id": 100,
    "attempt_id": "attempt-uuid",
    "started_at_client": "2026-10-01T11:40:00Z",
    "completed_at_client": "2026-10-01T11:52:00Z",
    "initial_coverage": [
      {"exercise_id": 898, "interaction": "teaching_acknowledged"},
      {"exercise_id": 899, "interaction": "answered_incorrectly"}
    ]
  },
  "nonce": "server-issued-random-value",
  "integrity_token": "transient-play-integrity-token"
}
```

This abbreviated example is **not** a qualifying complete lesson: production coverage must contain every manifest exercise. Other allowed interactions are `answered_correctly` and `skipped`; `skipped` makes the attempt ineligible, but ordinary progress remains completed. Teaching exercises accept only acknowledgement; other types accept answered outcomes. Sort coverage by exercise ID before canonicalization and reject duplicates or foreign IDs.

Use an agreed canonical JSON implementation, with cross-language byte fixtures, for SHA-256. Semantic idempotency covers the receipt only. Integrity `requestHash` covers a canonical object containing the receipt digest, verified account ID, claim ID, campaign ID and nonce. Renewing a nonce/token does not change the semantic receipt digest or operation key. On successful intake, consume the nonce and persist the receipt in the same transaction. If a replay is already committed, return its result before requiring the now-consumed nonce again.

Maintain accepted manifest versions rather than recomputing expected lesson content from the latest app. Retain revision 25 for this campaign; new content revisions need explicit equivalence mappings or a new reviewed manifest. A retired or unknown revision returns `409 content_update_required`, preserving the pending receipt and offering support for completed historical lessons.

### Stable errors

| HTTP / code | Client action |
|---|---|
| `401 authentication_required` | Refresh auth once, then show sign-in; retain local work. |
| `403 linked_account_required` | Start safe link-account flow. |
| `403 account_binding_mismatch` | Offer correct-account restore/support; do not reveal the other account. |
| `402 subscription_required` | Show the relevant product and free alternatives; history remains readable. |
| `403 integrity_rejected` | Explain verification failed and offer support; no automatic endless retry. |
| `409 idempotency_conflict` | Treat as implementation/data conflict and preserve diagnostics. |
| `409 content_update_required` | Fetch compatible content/configuration; retain receipt for resolution. |
| `409 referral_already_claimed` | Show the existing own claim without changing attribution. |
| `422 referral_ineligible` | Show a safe reason: self-referral, outside eligibility window or completed before claim. |
| `429 quota_exceeded` / `rate_limited` | Show next reset/retry time; do not sell a duplicate subscription as a fix. |
| `503 verification_unavailable` | Retry with backoff; show bounded existing access. |
| `503 ai_temporarily_unavailable` | Preserve typed input; no extra quota charge before provider dispatch. |
| `409 request_in_progress` | Poll request status; never start another provider request. |
| `503 result_unavailable` | Explain uncertain result; require a deliberate new user action/request ID to try again. |
| `409 already_claimed` / `claim_window_closed` | The one legacy claim is used or its window closed; say so, no retry. |
| `409 store_subscription_active` (`account-data` DELETE) | A Play subscription keeps renewing after deletion. Tell the learner, then resend with `x-confirm-store-subscription: KEEPS RENEWING IN GOOGLE PLAY`. |

## 4. Required transactions and worker algorithms

### A. Referral claim

1. Resolve authenticated referee and valid campaign/code; create account lock row if absent.
2. In one transaction, lock referee account, enforce created-at window and no existing conflicting claim, no prior first-unit completion in available synced history or accepted receipt history, referrer identity and non-self rules.
3. Insert claim with unique campaign/referee constraint. Store attribution once. Reserve anonymous claims as `waiting_identity`; campaign participation does not itself grant access.
4. Commit safe idempotency result. Never use an analytics event as the claim record.

### B. Receipt qualification and reward

1. Intake validates authentication, limits, challenge and integrity before durable receipt insertion; asynchronous review/qualification can follow.
2. Worker validates receipt against its immutable manifest and account claim. Insert lesson qualification idempotently. Derive completed units from all required accepted lesson IDs.
3. Derive eligible ordinals: unit 1 → 1; units 1 and 2 → 1 and 2. Preserve lower milestone first even when receipts arrive out of order. Identity/risk-pending milestones remain pending without grants.
4. In a transaction, lock beneficiary `monetization_accounts` row **before** locking claim/milestone rows. All allocation, migration and support code uses this lock order to avoid deadlocks.
5. For each eligible ordinal in ascending order, return existing terminal event if present. Otherwise compute active permanent unit IDs, iterate `reward_unit_order`, and select the first ID not owned. Temporary Core/grace/staff access does not enter this calculation.
6. If a candidate exists, insert one grant and one reward event, set milestone `granted`, increment beneficiary revision, and insert an outbox event. Otherwise set `cap_reached` with no grant. Commit all these writes together.
7. Retry serialization/unique conflicts by re-reading the winner. Never increment a separate mutable `credits += 1` balance without a ledger.

Multiple invitations may finish simultaneously; the account lock makes each allocation see earlier committed grants. If two jobs both qualify the last slot, one gets unit 30 and the other becomes `cap_reached`. A later fraud revocation does not cause old cap-reached events to be silently replayed; remediation is an explicit audited support operation.

### C. Purchase verification and acknowledgement

1. Authenticate buyer, persist verification request and deduplicated job; return a verification ID if not completed within the request budget.
2. A worker acquires a lease for the token/known lineage with a new fencing number. Only the lease owner may apply its result. Resolve linked tokens and merge/serialize lineage jobs before applying replacements.
3. Fetch Play outside a long-running SQL transaction. Validate product/package/state and authoritative account binding. If token is already owned by another account, return a generic conflict without reassigning it. Never bind a new token solely because a caller knows it.
4. In a short transaction, recheck lease ownership/fencing/expiry; reject stale worker output. Update purchase and feature state, increase account revision if access changed, enqueue acknowledgement if needed, and commit audit/outbox records.
5. Acknowledgement is retried separately; it cannot run before provisioning commits. Already-acknowledged responses are success. A failed grant transaction must not be followed by an acknowledgement.
6. Reconcile active, grace, held and recently canceled purchases at least daily, and when their known validity boundary approaches. Queue immediate refresh on verified notification, purchase/restore and explicit account refresh. Do not ask Play to verify every lesson tap.

Use a unique queue key per lineage/operation and generation-fenced leases; do not rely on an Edge Function process mutex, a transaction-pool session lock or provider notification arrival order. Worker wakeups may be best effort after durable insertion; a scheduler running at least every minute recovers missed wakeups. Document the actual deployed scheduler and verify it in staging.

### D. Google notification intake

Google Pub/Sub push uses Google OIDC, not a Supabase user JWT. Configure this function's gateway JWT verification off **only** for this endpoint; its handler must verify Google's signature/issuer, exact configured audience and expected verified service-account email before decoding an allowlisted message. Do not trust a header merely because it contains a JWT. Validate package ID, body size and message structure. [Authenticated push](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions).

After authentication, transactionally insert the unique inbox record and job, then acknowledge transport with a success response. If persistence fails, return an error for redelivery. An already durably stored duplicate gets success. Processing failure after durable intake uses the internal retry/dead-letter queue. Never return success before durable storage or wait for all Play/API work before accepting the message.

## 5. Retention, recovery and operations

Proposed operational retention: raw normalized referral coverage 90 days after terminal qualification; transient Integrity tokens zero persistence; nonce rows 24 hours after expiry; AI replay content 24 hours; content-free AI request tombstones seven days; sanitized operational logs 30 days. Keep minimal grant/milestone audit records while they explain an active grant. Delete linked learner detail on account deletion. Billing retention and deleted-owner tombstones require a documented policy matched to actual accounting/support obligations before launch; do not guess a legal duration in code.

Export only the account's own referral participation and benefits, not other learners' identifying data or fraud signals. As delivered in 7b (`20260928100000_account_lifecycle.sql`), the export adds `store_purchases` (product, plan, state, validity, auto-renewal, times; no token, digest or lineage), `referral_codes`, `referral_claims` (campaign and time only; no referrer), `referral_receipts` (lesson, attempt, times, evidence state; no integrity verdict or coverage), `referral_rewards` (unit, outcome, time; no claim ID), `ai_daily_allowance`, `ai_chat_sessions` (no replay content) and `legacy_migration_claims`. A deletion transaction must schedule required purges/tombstoning before auth user deletion. Test both directions of referral account deletion. Staff tools must audit grant/revoke/review actions with a reason and operator identity.

Required counters: verification latency/failures, pending acknowledgements and age, job retry/dead-letter depth, notification auth failures, entitlement refresh failures, receipt backlog, milestone/reward counts, review queue age, quota reservations, provider cost estimates and project spend ceiling trips. Attach opaque request/event IDs for support; never log tokens or raw learning conversations.
