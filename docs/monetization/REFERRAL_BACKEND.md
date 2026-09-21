# Referral backend: 4a handoff

The `20260923100000_referral_foundation.sql` migration implements the database part of Phase 4. Apply it only after the existing entitlement/billing migration chain. No referral HTTP endpoint or Flutter integration is part of this delivery. No production deployment has been performed.

## Service-only operations

| RPC | Responsibility |
|---|---|
| `get_or_create_referral_code(actor, campaign)` | Require an existing linked identity, return the active random code or create it once. No unverified share URL is advertised; first release uses manual codes. |
| `claim_referral(actor, campaign, code)` | Reserve attribution within seven days and before unit 1 completion. Failed code guesses consume the hourly limit. Replays retain the original referrer even after enrollment closes. |
| `accept_verified_referral_receipt(actor, claim, receipt, digest, integrity)` | **Trusted verification boundary.** Persist independently checked ownership, manifest coverage and diagnostic timing. Caller must already have verified request-bound attestation or explicitly selected the supported review path. |
| `process_referral_claim(claim)` | Derive readiness from qualifications and current Auth identities; allocate the next permanent A1 unit under the common account lock. Safe to retry after identity linking, review or processing resume. |
| `resolve_referral_review(claim, resolution, reason)` | Resolve an open support case with a required reason and process the held milestones. Only trusted operator tooling may call it. |

Every RPC is `SECURITY DEFINER` with an empty search path and execution revoked from public, anonymous and authenticated roles. The service role has no direct table-write privilege. Future account endpoints derive `actor` from verified Auth and must never accept a caller-selected user ID. The receipt RPC's integrity parameter is **not** a client protocol field.

Domain uniqueness currently supplies idempotency: one active code per owner/campaign, one claim per invitee/campaign, one receipt per invitee/attempt, and one final event per claim/milestone. Receipt retries require the same semantic digest **and** the same database-computed payload hash. 4b must add the API `Idempotency-Key` contract and return committed results before rechecking an already-consumed nonce.

## Manifest and evidence

The server has eight pinned lesson records for content revision 25, matching `fixtures/campaign_manifest.v1.json`. The campaign hash is SHA-256 over UTF-8 `25|` followed by lesson-ID-sorted rows, separated by `|`. A row is `unit:lesson:source-file-sha256:comma-separated-exercise-ids:comma-separated-teaching-ids`. CI compares the actual database records and digest against the bundled files. This manifest hash is distinct from the canonical receipt digest that 4b will define across Dart and Deno.

All 92 authored exercises must be covered exactly once across the eight lessons. Teaching requires `teaching_acknowledged`; ordinary answers may be correct or incorrect. A skipped exercise stores a nonqualifying attempt; a new complete attempt can qualify that lesson. Missing, duplicate or foreign exercise IDs are invalid. Unit 2 evidence may arrive first and wait for unit 1. Later incomplete attempts cannot remove an accepted qualification.

Client timestamps cannot establish trustworthy historical ordering. The app must capture the claim at attempt start; the database sends pre-claim or implausibly future timestamps to review. The database neither proves a unique human nor substitutes for Play Integrity.

## Allocation and lifecycle

Lock order is beneficiary `monetization_accounts`, then claim, for receipt intake, allocation and review. All other permanent-grant writers already use the same account lock. Under it, select the first unit in `3..15,28,30` without an active permanent grant from any source; temporary subscriptions and grace are ignored. Final outcomes are durable and never reallocated on replay, including after revocation or a previous `cap_reached` result.

The worker must retry identity-held claims after in-place linking and qualified claims after processing resumes. Those scheduling hooks are still 4b work. Existing receipts can be processed after the campaign ends, but new receipt intake closes at `ends_at`. Disabling enrollment stops new codes/claims, not existing receipt intake; `processing_paused` holds awards without losing evidence.

Deleting a referee cascades their private receipts/qualifications and sets the claim's referee to null. It does not delete another account's grants or reward events. Deleting a beneficiary removes their course access and tombstones audit ownership. Export extensions and final audit/rate-limit retention remain Phase 7 work; the private referral tables must never enter generic progress sync or raw account export.

## 4b: authenticated intake

Delivered on `codex/referral-intake` (migration `20260923110000_referral_intake.sql`):

- **Routes** on `monetization-api`: `POST /referrals/code`, `/claim`, `/challenges`, `/receipts` and `GET /referrals/status`. The account always comes from the verified JWT; unknown fields are refused. Anonymous invitees may claim and submit; only linked accounts get a code. Database outcomes map to the stable error codes in the API contract.
- **Canonical receipts** (`_shared/monetization/referral_receipt.ts`): keys sorted at every level, no whitespace, integers only, ASCII-only strings, coverage sorted by exercise. Values outside that profile are refused rather than risk two JSON libraries encoding them differently. `test/fixtures/monetization/referral_receipt.v1.json`, generated with Python's `json`, pins the bytes, the receipt digest and the Integrity request hash; 4c's Dart implementation must pass the same fixture.
- **Challenges**: `issue_referral_challenge` returns a 256-bit nonce bound to the referee, claim and receipt digest, valid ten minutes; only its digest is stored. `submit_referral_receipt` checks and consumes the challenge and calls the 4a receipt function **in one transaction**. A challenge is spent by any admitted submission, including refused evidence; refused bindings leave it unused.
- **Replays**: `find_referral_receipt` answers a committed attempt before any challenge or token is needed, and reports a conflict for different content under the same attempt.
- **Play Integrity** (`_shared/monetization/play_integrity.ts`): the request hash is SHA-256 over canonical `{account_id, campaign_id, claim_id, nonce, receipt_digest}`. Rejected: wrong request package or hash, a token older than ten minutes or more than a minute in the future, or (when the app was evaluated) a package or signing certificate other than ours, and any token Play cannot decode. Needs review: the binding holds but the app is not Play-recognized, the device lacks `MEETS_DEVICE_INTEGRITY`, or the install is not `LICENSED`. Verified: all three hold. Tokens are never stored.
- **Worker**: `monetization-worker` runs `referral_claims_to_process` (claims held for account linking whose accounts are now both linked, and cleared claims held only by paused processing), calls `process_referral_claim` for each, then `cleanup_referral_records` (failed-claim counters after a day, challenges a day after expiry). Referral work runs without billing secrets; the worker needs only `BILLING_WORKER_SECRET`.
- **Status**: `get_referral_status` returns the account's code, referral units earned out of 15, the next reward unit, the account's own claim as an invitee (including review, so they can contact support), and friends by number with milestone status only. A friend's review or rejection reads as `verification_pending` to the referrer.
- **Operator switch**: service-only `set_referral_campaign` sets the enabled and paused switches and the window; the table checks refuse an enabled campaign without a complete window, and the pinned manifest and reward order are untouched.

Secrets: `PLAY_PACKAGE_NAME`, `PLAY_INTEGRITY_CERT_DIGESTS` (the app's signing-certificate SHA-256 digests exactly as Play Integrity reports them, comma-separated), and `PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON` (falls back to `PLAY_SERVICE_ACCOUNT_JSON`) with the Play Integrity API enabled on its Google Cloud project. Without them, token submissions answer `503`; the review route still works. A malformed value turns Integrity off with a `play_integrity_misconfigured` log line instead of stopping the function.

Still open: operator authorization and audit attribution for review and campaign changes (both are service-only RPCs without an operator identity), a generic `Idempotency-Key` store (all referral mutations are idempotent through domain uniqueness), and export extensions (Phase 7).

## What 4c must add before activation

Items 1–4 of the original handoff are delivered in 4b above; operator identity for reviews remains open.

1. Dart canonical receipts that pass `referral_receipt.v1.json` byte for byte, and a Play Integrity standard token requested with the fixture's request-hash construction.
2. Flutter manual-code claim flow, actual initial-player interaction coverage and teaching acknowledgements, and an account-scoped outbox committed in the same local transaction as the lesson attempt. Network failure must not undo learning progress. Account switches cannot move receipts.

## Verification

Run on the disposable local Supabase stack:

```sh
supabase db reset --local
supabase test db
python3 tool/test_referral_concurrency.py
supabase db lint --level warning
```

The Python harness needs `psql` (set `PSQL` if it is outside PATH), accepts loopback database hosts only and uses no extra Python packages. It checks the published manifest and all three concurrency fixtures using independent PostgreSQL connections. Test accounts and campaign settings are cleaned up. The reset removes disposable local test data; none of these commands target production.
