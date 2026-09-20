# Czechify: paid course access and milestone referrals

20 September 2026. Assessment of the user's latest proposal, on `codex/monetization-research-plan`. This supersedes the advertising strategy and the earlier assumption that the entire core course stays free. Product recommendations only; no access restrictions, purchases, referral rewards, or production changes have been implemented.

## Assessment and recommended pilot

Paid course access gives 250 CZK/month a clearer benefit than removing ads from a small app. A referral reward tied to learning is a useful acquisition experiment, but acquiring free users does not itself produce revenue. The program must earn incremental paying learners or sufficient retained learners to justify its costs and displaced subscriptions.

Recommend **the first two A1 units free**, **Core at 250 CZK/month**, and **AI chat at an additional 150 CZK/month**. Keep the experience ad-free. Recommend Core include the current A1 and A2 course, with ordinary learning prerequisites; referral grants cover A1 only. Give the AI option a clear usage allowance and allow purchase without Core so learners with referral-earned access can still buy tutoring. A combined offer can total 400 CZK; the AI-only option must not unlock paid course units.

Use **one additional A1 unit for each of the referred learner's first two qualifying unit completions**, at most two units per friend. Do not grant anything for merely registering or installing. This implements the user's staged reward without requiring the friend to pay.

For an initial revenue-focused pilot, recommend a **published cap of six referral-earned units per referrer**, corresponding to three friends completing both milestones. Including the two free units, this grants eight of 17 A1 units, leaving nine outside the free/referral allowance. This cap is a proposed modification to the user's full-A1 reward, not an accepted requirement. If the priority is maximum growth and full-A1 giveaways are intentional, remove the cap: eight fully qualified friends then unlock all 17 units. Never add a lower cap retroactively to rewards already promised.

Do not require a card for the free sample. Explain the limit and paid price from onboarding, and offer upgrade or referral at the boundary. With course access already monetized, retain unlimited attempts or optional hearts rather than making mistake recovery a second payment pressure. Recommend reconsidering the old 500-download launch threshold: billing readiness and a convincing course sample now matter more than reaching the former advertising milestone.

## Two free units versus three

Verified bundled curriculum: A1 has **17 units**; A2 has **14**. The first two A1 units contain **eight lesson files and 92 authored exercises**. Three units contain twelve lessons and 140 exercises. Exercise counts are content inventory, not measured learning time or completion rate.

| Version | Initially free | Maximum reward per fully qualified friend | A1 units beyond initial allowance | Fully qualified friends to unlock all A1, without a program cap |
|---|---:|---:|---:|---:|
| Three-unit proposal | 3 | 3 | 14 | 5 |
| Two-unit proposal | 2 | 2 | 15 | 8 |

The three-unit version reaches 15 credits after five friends; only 14 are needed. The two-unit version reaches 16 credits after eight friends; only 15 are needed. Clip to the remaining A1 inventory and explain this in advance; do not silently turn excess credits into A2 or AI access. Once the learner reaches their cap, remove the promise of further credit from new referral offers.

The reward is **cumulative**: friend finishes unit 1 → one credit total; finishes unit 2 → two total; under the three-unit variant, finishes unit 3 → three total. It is not 1 + 2 + 3 credits from one friend.

Two free units is a sensible starting experiment because it already includes eight lessons, not simply because 17 is a small unit count. However, these units focus on Czech sounds/repair phrases and introductions. Unit 3 begins gender/noun identification; later units show cafés, shopping and daily-life tasks. The paywall should preview these concrete outcomes. If users do not experience useful progress in the first two units, shortening the sample could reduce conversion; three free units remains a valid alternative to test later.

## Growth and revenue are different outcomes

Completion makes a referral more valuable than an installation but does not guarantee retention, payment, or a distinct human. A learner may recruit friends interested only in the same free route. A chain of referrals can grow accounts while leaving subscription revenue near zero.

Illustrative, not forecast: if 5% of qualified referred learners buy one month of Core, five referrals yield `5 × 0.05 × 250 = 62.50 CZK` expected gross billings; eight yield `100 CZK`. Compare this with the referrer's probability of buying and renewing without the reward, not with an assumption that every rewarded referrer would have paid. The 5% conversion is an example only.

Evaluate:

```text
incremental referral contribution =
  net receipts from genuinely additional referred learners
  − subscription contribution displaced by free unit grants
  − incremental hosting, course-service/AI, fraud and support costs
```

Measure retained learning and paid conversion for referred cohorts, not just account totals. A reward's cost is not the cost of copying lesson files: it includes potential lost paid access. Keep referral grants out of AI-chat entitlement so the acquisition incentive does not create open-ended inference costs.

## Reward terms and abuse controls

Proposed terms: one immutable referrer per new learner, code claimed within seven days of joining and before qualifying completion, no self-referrals, no retroactive claims by existing accounts, no transferable credits, no cash value, and no rewards for the friend's own referrals. Only direct referrals qualify. Both parties need linked, verified accounts for rewards; free sample learning may remain anonymous. Same email/provider identity is ineligible, but distinct emails alone do not prove distinct people.

Define completion as **all required lessons in the specified free unit completed through normal practice**, not opening a unit, placement credit, imported progress or a client-submitted completion boolean. Permit retries. A brief server-issued unit checkpoint, tied to the curriculum revision and a nonce, can provide extra evidence at the reward boundary; this must not turn a reward into an undisclosed exam. It raises abuse effort without proving unique identity.

Use server verification and an idempotent ledger keyed by referral, milestone and campaign version. A short disclosed pending period can allow duplicate/fraud checks; it is not itself proof of authenticity. First milestone: one credit. Second milestone: one additional credit after validated unit 2 completion. Offline learning remains available, with reward status pending until synced and verified; do not force repeated lesson completion after a network failure.

Flag account farms using several signals: repeated account creation on an installation, replayed checkpoint IDs, implausible sequences, excessive referral velocity and Integrity verdicts. Shared IP or Wi-Fi alone must not disqualify families, schools, workplaces or mobile-network users. Verified sign-in and a real device do not prevent one person from operating multiple accounts. Provide an appeal path, and hold questionable rewards rather than deleting learning progress.

Play Integrity checks genuine-app/device properties and Google explicitly recommends using it alongside other anti-abuse signals. It is not a unique-person identity service. [Play Integrity guidance](https://developer.android.com/google/play/integrity/overview).

Use shareable links and an explicit invitation code fallback. Install Referrer can retrieve attribution data after a Play install, but cannot verify learning or unique identity. Confirm attribution with the server; links must not contain secrets or email addresses. [Google Play Install Referrer](https://developer.android.com/google/play/installreferrer).

The referrer should see reward milestones and credit totals, not a friend's scores, answers, email or detailed activity. Tell referred learners that completing qualifying units benefits their inviter. Update privacy/deletion/retention handling for referral and fraud records. Never use Play Age Signals for growth analytics. Never tie rewards to star ratings, reviews or posting referral codes in Play reviews. Google's policy prohibits illegitimate manipulation of installs/ratings; a learning-based referral campaign still needs compliant implementation and is not automatically approved. [Play ratings, reviews and installs policy](https://support.google.com/googleplay/android-developer/answer/9898684?hl=en).

## Permanent rewards and temporary subscriptions

Recommended reward: permanent account access to the next named A1 unit in the campaign's curriculum version, subject to ordinary lesson prerequisites. Use the next unrewarded unit even while the referrer is subscribed; otherwise paid learners receive no benefit. Granted units remain after subscription expiry. Revoke only demonstrated invalid rewards under published terms, not ordinary subscription cancellation or an invitee later becoming inactive.

Core grants course access for the paid period. Completing a unit while subscribed does not permanently buy that unit. After expiry, retain progress and restore access to initially free, referral-earned and any explicitly grandfathered units; other units relock. Explain this before purchase. Any continued review of previously learned vocabulary should be a deliberate policy, not accidental access to whole paid lessons.

Keep referral units separate from premium status and paid AI. An AI-only subscription can be used alongside the free/referral course; if Core expires while AI is active, show exactly which units and chat remain available. If offering Core, AI-only and a combined tier, implement replacement so purchasing a bundle does not leave redundant subscriptions renewing. Do not automatically cancel a paid subscription because referral rewards now cover A1: show earned access and a management link, and let the learner decide.

Google requires subscriptions to provide sustained value and clear price, renewal and cancellation terms. Present monthly continuing course access as such, never as permanent ownership. Longer-term viability also depends on useful practice and A2 progression after learners finish A1. [Play subscription policy](https://support.google.com/googleplay/android-developer/answer/9900533?hl=en).

## Implementation findings specific to Czechify

- A1 unit IDs are **1–15, 28 and 30**, not 1–17. A2 has IDs between them. Reward a versioned ordered set of A1 IDs; using `unitId <= unlockedCount` would unlock the wrong material.
- The present progression graph sorts A1 and A2 together. Audit cross-level prerequisites before promising all A1 through referrals: access to A1 units 28/30 must not require buying and completing intervening A2 content.
- `CurriculumAccessPolicy` currently combines progression, placement and staff overrides. Add commercial entitlement as a separate check: lesson accessible only when educational prerequisites **and** commercial access are satisfied, except an explicit authorized staff override. Placement/level switching must not bypass payment, and buying access must not incorrectly mark lessons completed.
- Apply access consistently to direct routes, Continue, exams, review introduction, audio downloads and restore, not just curriculum cards. Decide what an A2-starting learner can preview rather than accidentally granting two free units per level when only A1 was promised.
- The current server-managed `curriculum_entitlements` is a reviewer/support `unlock_all` override. Add owner-read/server-write paid and referral unit grants; never allow clients to mint credit or reuse `unlock_all` for a two-unit reward.
- Existing progress is offline-first and client-synced. The portable-history migration explicitly leaves raw lesson/exercise attempts and the reward ledger local. A synced completion field is not authoritative anti-fraud evidence; build a dedicated server milestone-validation path.
- Course JSON is bundled in the app. Entitlement checks protect the ordinary product flow, not against extraction from a modified app. Do not promise perfect DRM or sacrifice offline learning to chase zero piracy.
- Keep granted access cached by account with a verifiable server snapshot. Subscription validity/offline grace and permanent unit grants need different expiry rules. Unknown billing state must not be cached as a permanent free grant; preserve already verified access for a disclosed offline grace period.
- Existing users currently receive broader free access. Recommend preserving their already reached units and providing advance notice plus a transition period; the exact grandfathering policy needs a decision before shipping. A new gate must never erase their progress.

## Rollout and decision gates

First ship and test the free-sample boundary, paid course/AI entitlements, restore, expiry and offline behavior. Then add an invitation-code pilot and staged server-side rewards; automatic link attribution can follow. Remove AdMob/UMP/rewarded-hearts work from the active backlog, since ads were never implemented. Retain the existing non-ad privacy promises unless the new referral/billing data flows require specific updates.

Pilot two free units and at most six earned units, with the terms visible before invitations. Track sample completion, paywall-to-purchase conversion, first paid renewal, referred D7/D30 learning retention, milestone approvals, fraud/appeal rates, incremental support cost and net subscription contribution. At small sample sizes, report counts and uncertainty rather than claiming a statistically proven winner. Expand toward full-A1 earning only if acquisition quality and economics justify it; honor existing grants if new referrals are paused.

The earlier engineering estimates covered advertising and a simpler entitlement model; they are superseded, not additive. A fresh estimate must cover course-wide access, migration, account restore, the referral ledger/validation, and optional AI-only/bundle billing. No guarantee of quick growth or fraud elimination follows from the proposal.
