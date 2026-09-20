# Czechify monetization engineering plan

Specification date: 2026-09-20. Status: ready to break into implementation PRs; no runtime changes made by this plan.

This is the implementation entry point and supersedes the advertising, rewarded-heart and subscription-packaging proposals in the older monetization documents. The accepted product direction is paid course access with permanent A1 referral rewards, without advertising.

## Read and implement in this order

1. [Engineering specification](ENGINEERING_SPEC.md): product rules, access evaluation, purchase lifecycle, referral qualification, offline and account behavior.
2. [API and database contracts](API_DATABASE_CONTRACTS.md): schemas, authorization, payloads, transactional algorithms, retries and errors.
3. [Implementation and verification](IMPLEMENTATION_AND_TESTS.md): repository change map, ordered PRs, acceptance tests and rollout.
4. [Campaign manifest](fixtures/campaign_manifest.v1.json) and [shared decision cases](fixtures/decision_cases.v1.json): test inputs and expected outputs. These are planning fixtures, not deployed configuration.

The earlier [product assessment](../MONETIZATION_COURSE_ACCESS_AND_REFERRALS_2026-09-20.md) explains the business reasoning. Where an older document differs, this specification takes precedence for engineering.

## Confirmed product requirements

| Area | Required behavior |
|---|---|
| Free course | First two A1 units are free. |
| Core | Target price 250 CZK/month. |
| AI chat | Additional 150 CZK/month; combined target spend 400 CZK/month. |
| Ads | No advertising SDK or ad placements in this release. |
| Referral first milestone | Invitee completes unit 1: one additional A1 unit for the referrer. |
| Referral second milestone | Same invitee completes unit 2: one more A1 unit. |
| Per-invitee maximum | Two additional units in total, without requiring a purchase. |
| Reward ceiling | All 15 paid A1 units are earnable; no six-unit campaign cap. |
| Persistence | Earned units remain accessible after Core cancellation. |

Seven invitees completing both units earn 14 units. An eighth completing unit 1 earns the final unit. The last invitee need not finish unit 2 for the referrer to own A1. This is a growth experiment; 250–500 CZK divided by eight is hypothetical forgone gross revenue per acquired learner, not a measured all-in acquisition cost.

## Explicit engineering defaults

These resolve otherwise ambiguous implementation choices. They are recommendations, not additional decisions attributed to the user. If a product answer changes one, change the associated contract and test fixture before implementing it.

| Decision | Default in this specification |
|---|---|
| Core coverage | All published A1 and A2 units while entitled; normal learning prerequisites still apply. No promise about future levels. |
| AI dependency | AI can be bought independently, including by users who earned A1 through referrals. |
| Store packaging | Two independent monthly subscriptions; no third combined SKU in v1. |
| Existing learners | Retain units already reached before launch, plus full-course access until 30 days after a fixed launch cutoff. |
| Hearts | Preserve the existing optional-heart behavior. No new paid heart restriction or paid recovery. |
| Purchase identity | Link the anonymous account to Google before buying. Linking in place retains progress. |
| Referral identity | Claim can be reserved anonymously; final rewards require both accounts to be linked to distinct Google identities. |
| Referral timing | New account claims within seven days of creation, before completing unit 1. No backdated rewards. |
| Offline paid use | Signed cached access lasts until the earlier of paid validity and seven days since server verification. |
| AI allowance | Start with 20 conversation turns and 60 internal summaries per UTC day, bounded context/output and project spend controls. These are operational defaults, not an unlimited-use promise. |
| Platforms | Launch Play purchases on Android. Keep other builds compiling; enable paywalls only where the complete acquisition/restore flow has shipped. |

The existing-user and independent-AI choices were presented for product input. Until answered, implementation should use these labelled defaults rather than silently invent a different policy.

## Repository baseline and delivery boundary

- Branch: `codex/monetization-research-plan` in `worktrees/monetization-plan`.
- Inspected application baseline: `b852f3c4`; `pubspec.yaml` declares `1.1.3+27`, bundled content revision 25, Drift schema version 8.
- Stack: Flutter/Riverpod/GoRouter/Drift, Supabase anonymous authentication, Edge Functions and Postgres.
- A1 order is **1–15, 28, 30**. A2 order is **16–27, 29, 31**. Never infer a level or the next reward from numeric ranges.
- Current progress and evidence sync are client writable. They cannot independently authorize paid access or referral grants.
- Lessons and answer keys are bundled. This design controls normal application access and server-funded features; it does not make downloaded course content impossible to extract.

Implement the ordered PRs against a refreshed baseline, resolving any intervening schema changes. Do not activate production flags or migrate production data as part of documentation work. Delivery is complete only when the contract tests, real Play sandbox purchase tests, account isolation tests and rollout gates all pass.

## Plan validation

The handoff includes 43 expected-outcome cases. Documentation checks verified relative links, referenced existing source paths, curriculum membership/order, all eight lesson-file hashes, 92 exercise IDs and reward allocation examples. These checks validate the plan artifacts; application, database and Store integration tests remain implementation work.
