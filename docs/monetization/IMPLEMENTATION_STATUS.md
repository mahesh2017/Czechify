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

## Activation boundary

Only the phase-local progression correction is connected to the existing runtime. The new commercial policies are not yet wired into screen/provider admission. There is no checkout, production paywall, deployed migration, new external service or real referral grant in this delivery. No production backend was changed.

Do not connect an unverified JSON/cache object to `MonetizationSnapshot`. The next backend/client repository work must verify the signed snapshot, account and protocol before these policies receive it. `ReferralRewardPolicy` is a preview; authoritative rewards require the locked database transaction and uniqueness constraints in the specification.

## Next implementation work

1. Complete phase-specific placement persistence and migration alongside account/sync handling. Existing `LevelSwitch`/`ProgressDao` still persist a scalar ceiling, and `setProvisionalUnit`/remote merge compare numeric IDs. Replace those comparisons with phase/order-aware state before switching callers to the new explicit placement API. Preserve old open spans and learner estimates.
2. Implement the private backend schema, owner-safe projections, signed snapshots, account-scoped cache/clock and database security/concurrency tests (engineering PR 2).
3. Implement and license-test Play purchase/restore, token binding, durable verification, acknowledgement and notifications (PR 3).
4. Implement referral claim/evidence/Integrity/outbox and transactional allocation (PR 4); then course UI/admission, AI authorization/cost controls, existing-user migration and rollout (PRs 5–8).

The pre-existing uncommitted change in `docs/monetization/README.md` was preserved and is not part of this implementation commit.
