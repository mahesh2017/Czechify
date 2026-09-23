# Czechify: advertising and Pro subscription research and implementation plan

Research date: 20 September 2026. Status: proposed implementation, not deployed.

**Superseded strategy:** the user has since rejected ads and proposed paid course access with milestone referrals. Read the [current course/referral assessment](MONETIZATION_COURSE_ACCESS_AND_REFERRALS_2026-09-20.md). This document is retained as research history; its advertising backlog and estimates are no longer the active recommendation.

**Latest direction:** [Rewarded hearts and 250/400 CZK subscription tiers](MONETIZATION_REWARDED_HEARTS_AND_TIERS_2026-09-20.md) supersedes this document's recommendation to defer rewarded ads and its single-price/single-product hypothesis. The user confirmed that free learning remains, with 250 CZK/month removing ads and heart limits; the proposed 400 CZK total tier adds AI chat. The original baseline below is retained for its research and engineering detail. Migration of existing free hearts/chat benefits remains a product decision; nothing is implemented.

Branch: `codex/monetization-research-plan`. Baseline: `b852f3c4`, taken from `release/1.1.1-age-signals`; that checkout currently declares **1.1.3+27**. This document does not establish which build Google Play is reviewing. The user reports that a production release is pending review. No Play Console or AdMob account was inspected, and approval timing is unknown.

## 1. Recommended decision

Start with **Google AdMob interstitials at a completed lesson boundary**, then introduce **Czechify Pro through Google Play Billing after 500 cumulative first-time acquisitions**. Verify that milestone in Play Console, rather than scraping the public download badge or counting Supabase accounts. Accounts, reinstalls, downloads, monthly active users, and daily active users are different metrics.

Use the pending release to establish a baseline. Prepare monetization in a subsequent release with ads and purchase availability independently controlled. Begin cautiously: no ad during the first three completed lessons or first 24 hours, then at most one after every two eligible completed lessons, a five-minute cooldown, and a maximum of three per rolling 24 hours. These are proposed product settings, not Google requirements. Keep learning available when an ad cannot be shown.

Pro initially promises **an ad-free learning experience for the paid period**. Preserve existing learning access, hearts settings, offline lessons, and AI quotas. Do not advertise unlimited AI or features that have not been built. Suggested price hypothesis: **79 CZK/month**, with **599 CZK/year** considered after the monthly purchase path is proven. These are test prices, not evidence of willingness to pay or configured store products.

**Do not budget for 400 CZK of advertising revenue per user per month.** At an illustrative 250 CZK eCPM, that requires 1,600 displayed ads per user per month, or about 53 per day. With a three-ad daily cap, even 30 fully active days produce only 22.50 CZK at that eCPM. Revenue is likely to be modest at 500 downloads; actual results require a measured pilot.

## 2. What the revenue research establishes

AdMob defines eCPM as estimated publisher earnings per 1,000 impressions. An ad request is not an impression, and an install produces no recurring revenue unless the learner returns and sees eligible ads. Geography, demand, format, consent, and engagement affect results. [AdMob: understanding eCPM](https://support.google.com/admob/answer/15337570?hl=en).

Duolingo's 2025 annual report says advertising contributed **7.7% of revenue**, while subscriptions contributed **$873.4 million out of $1,037.6 million** overall. Its model supports using free learning to build a paying audience; it does not establish 400 CZK of monthly ad revenue per learner. Do not divide full-year revenue by a single quarter's user count and call it measured monthly ad ARPU. [Duolingo 2025 Form 10-K, revenue discussion and advertising risk disclosure](https://investors.duolingo.com/static-files/f19d76fb-dee4-4f13-96ae-138ebfd0f2d3).

No authoritative Czechify-specific or Czech Android education interstitial eCPM was established. The following values are **sensitivity assumptions**, not market benchmarks or confidence intervals. All currency values are CZK, so no exchange-rate assumption is hidden in the calculation.

```text
monthly displayed impressions =
  MAU × eligible free share × active days per MAU
      × capped ad opportunities per active day × fill rate × show rate

monthly ad revenue = displayed impressions × publisher eCPM / 1,000
```

Eligible free share excludes subscribers and learners ineligible for ads. Opportunities are counted after onboarding exclusions, placement rules, frequency caps, and cooldowns. Fill rate represents successfully loaded ads per opportunity in this simplified model; show rate represents loaded ads actually displayed. In production, report the actual request/load/impression funnel separately because preloads do not map one-to-one to opportunities.

| Assumption at 500 cumulative downloads | Low case | Working case | Strong case |
|---|---:|---:|---:|
| MAU | 100 | 150 | 300 |
| Eligible free share | 50% | 70% | 80% |
| Active days per MAU/month | 8 | 12 | 20 |
| Capped opportunities per active day | 1 | 1.5 | 2 |
| Fill rate | 65% | 80% | 90% |
| Show rate | 80% | 90% | 95% |
| Publisher eCPM | 40 | 120 | 250 |
| Expected displayed impressions/month | 208 | 1,360.8 | 8,208 |
| **Ad revenue/month** | **8.32** | **163.30** | **2,052.00** |
| Revenue per total MAU/month | 0.08 | 1.09 | 6.84 |

Fractional impressions are expected values in a model. Actual counts are integers. The strong case assumes substantial retention and frequent completed lessons; it is not a forecast. These amounts precede operating costs and income taxes. Do not subtract a second ad-network share from a publisher-revenue eCPM.

For comparison, **five monthly subscribers at 79 CZK produce 395 CZK in gross consumer billings**. Applying only a 15% Play fee yields 335.75 CZK, **before accounting for VAT/tax treatment, refunds, and costs**; this is not a payout prediction. Google lists a 15% fee for automatically renewing subscriptions under its standard fee schedule. Use actual Play financial reports to calculate net proceeds. [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622?hl=en-GB).

When combining ads and Pro, remove subscribers from the ad-eligible population. Track contribution margin as ad earnings plus net subscription proceeds minus AI text/speech, hosting, storage, payment tooling, and support costs. Existing AI quotas should remain in place until usage and cost per active learner are measured. No production cost or retention data was available for this report.

## 3. Product behavior

### Ad placement

The first placement is **ordinary lesson completion → visible results → learner chooses Continue → eligible preloaded interstitial → curriculum**. Tell eligible learners on the results screen that a short ad may follow. Never insert an ad before the result is saved. Never show a late-loading ad after the curriculum or next lesson has appeared.

Exclude exams, failed attempts, retries, abandoned lessons, review-card answers, tutor chat, microphone recording, onboarding, app launch/resume, account flows, and navigation Back. Initially also exclude unit-completion ceremonies: the current Finish unit button queues a celebration before navigating, and an ad would compete with it. Persist a per-attempt handled marker so rebuilds, double taps, process restoration, or repeated callbacks cannot generate duplicate ads.

Google requires predictable, non-disruptive placement and disallows interstitials at app load/exit, repeated disruptive displays, or ads that suddenly appear during content. The learner must retain access to content and navigation. [AdMob interstitial guidance](https://support.google.com/admob/answer/6201362?hl=en).

Play's general rule disallows full-screen interstitials that cannot be closed after 15 seconds, with specified exceptions including certain natural-break placements and opt-in rewarded formats. Do not treat an exception as a target ad length. Review actual SDK creatives, dismissal behavior, ad-content rating, and available AdMob controls on the release build. Do not build a custom close button over the ad. [Google Play Ads policy](https://support.google.com/googleplay/android-developer/answer/9857753?hl=en).

Start with one network and one Android ad unit. Banners distract from learning and add little useful evidence to this pilot. App-open ads are excluded by product choice. Defer mediation and rewarded ads until there is enough traffic to justify the complexity. In particular, do not sell heart refills through ads while Settings already permits disabling hearts.

### Pro offer

Pro removes third-party ads and upgrade prompts for the paid period. Its paywall remains dismissible, with a clear free-learning option. Use localized prices returned by Play, disclose full billing amount, period, automatic renewal, cancellation, and the precise benefit. Show Restore purchases and Manage subscription in Settings. Annual pricing must prominently show the annual charge; a monthly equivalent is secondary.

Use one proposed subscription product `czechify_pro`, starting with base plan `monthly`; add `annual` later. No free trial in the first version reduces lifecycle and pricing complexity. Product IDs are proposals and must be checked for conflicts before creation. An ongoing ad-free service is the intended recurring benefit; do not describe it as a permanent unlock. Review conversion and cancellation feedback before adding benefits or trying a one-time ad-removal product. [Play subscription policy](https://support.google.com/googleplay/android-developer/answer/9900533?hl=en).

Use standard Google Play Billing for this Android launch. Ad removal and education subscriptions are digital in-app benefits covered by the payments policy. Regional alternative-billing programs exist, but add requirements unnecessary for this first release. [Google Play payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en).

When the measured acquisition count passes 500, enable the paywall only after billing acceptance tests pass and products are available. This is an operator-controlled global rollout, not a client-side test of its own install count. Build the paid entitlement check into the ad architecture from the start, even while checkout is disabled.

## 4. Privacy and audience prerequisites

### Existing promises must change with the monetized release

The repository currently says there are no ads or third-party analytics in both the bundled policy and public policy source. Update these together with Data safety and the Play Console Contains ads declaration. Cover the chosen SDK's collection/sharing, purposes, recipients, privacy controls, subscription records, account deletion, and retention. Non-personalized advertising is not automatically consent-free.

Google's Mobile Ads disclosure lists IP-derived approximate location, interactions, diagnostics, and device/account identifiers among SDK data flows. Match declarations to the **resolved native SDK and actual configuration**, rather than copying generic answers or assuming that adding no Firebase means there is no ad analytics. Inspect the merged Android manifest, including AD_ID permission behavior. [Google Mobile Ads data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure).

### Consent and age must remain separate

Use AdMob Privacy & messaging with UMP for the relevant markets. Google's certified-CMP requirements cover personalized advertising in the EEA, UK, and Switzerland. Consent withdrawal must remain accessible. [Google CMP requirements](https://support.google.com/admob/answer/13554116?hl=en), [Flutter European consent guide](https://developers.google.com/admob/flutter/privacy/gdpr).

Czechify's minimum age is 16, so a permitted learner is not necessarily an adult. Also, `ageEligibilityProvider` reduces the Play response to allowed/blocked, and NOT_SHARED/unsupported cases may allow access. None of these outcomes proves adulthood or advertising permission.

Play Age Signals terms prohibit using their data for advertising, marketing, profiling, or analytics. Keep those signals in the existing access/compliance flow; do not pass their values or derived age bands to ads, consent targeting, revenue reporting, or analytics. [Play Age Signals terms](https://developer.android.com/google/play/age-signals/overview).

**Proposed conservative pilot:** use an independently obtained, neutral advertising-audience declaration with 16–17, 18+, and prefer-not-to-answer options; do not prefill it from Play signals, collect exact birth dates, or imply that one answer unlocks learning. Only the adult-declared cohort enters the ad pilot. Under-18 and unknown cohorts remain ad-free, with Pro promotion suppressed where it offers no useful current benefit. Validate this design against intended distribution countries before enabling ads; a self-declaration is not a claim of verified age or universal legal sufficiency. If a suitable independent audience approach is not ready, keep ads off. This does not change the app's 16+ learning-access policy.

For the eligible free cohort, refresh UMP information at launch, present a required form, and check `canRequestAds()` before requests. This boolean is permission to request ads, not proof of personalized-ad consent. Do not replace it with the app's cloud-speech consent or a homemade persistent consent boolean. Provide UMP Privacy options when required; invalidate preloaded ads after choices change. Avoid duplicate initialization/requests from concurrent consent callbacks. [UMP Flutter integration](https://developers.google.com/admob/flutter/privacy).

The recommended first pilot requests non-personalized ads where allowed by the chosen SDK configuration and consent outcome. If the valid consent state does not permit the intended request, skip it; never condition learning on agreeing. Do not silently escalate to personalized ads later. Retain a privacy-options route for prior ad users who become Pro, while stopping new ad loads.

### AdMob account and website setup

Create/link the Android app `com.eminentsite.czechify`, configure publisher/payment details, the production interstitial unit, consent messages, content restrictions, and test devices. Complete AdMob's app readiness process. New apps require app-ads.txt verification. [AdMob app verification](https://support.google.com/admob/answer/14538460?hl=en).

The code names `https://eminentsite.cz/czechify/` as the website. Confirm that this matches the actual Play listing. Publish the AdMob-issued seller line at the appropriate website root, expected to be **`https://eminentsite.cz/app-ads.txt`**, and confirm the crawler reports success. Placing a file only at `/czechify/app-ads.txt` is not sufficient. The existing Pages workflow publishes `docs/site`; verify how that maps to the production domain root. Research fetches of the live privacy page and root app-ads.txt were unsuccessful, so their current deployment status is **unverified**, not confirmed missing.

## 5. Codebase findings and implementation map

The app uses Flutter, Riverpod, GoRouter, Drift, and anonymous-first Supabase authentication. Neither `google_mobile_ads` nor `in_app_purchase` is currently in `pubspec.yaml`. No ad service, billing lifecycle, or monetization remote configuration was found in the inspected application paths. Existing curriculum entitlements are reviewer/support overrides, not purchases.

| Existing file or area | Implementation action |
|---|---|
| `pubspec.yaml`, Android manifest/build configuration | Add compatible ads/UMP and billing plugins; separate test and production IDs; verify merged SDK permissions and requirements |
| `lib/main.dart` | Attach a lifecycle-aware monetization coordinator after app access/init; avoid SDK calls in widget build; refresh purchase state on resume without blocking lessons |
| `lib/presentation/providers/lesson_providers.dart`, `_onLessonComplete` | Preserve transactional completion; expose a stable completed-attempt ID for ad deduplication without moving ad display into the learning engine |
| `lib/presentation/screens/lesson/lesson_player_screen.dart` | Route the ordinary completion Continue action through an async boundary handler; skip exams, unit ceremonies, unsuccessful attempts, and Practice again |
| `lib/presentation/providers/account_providers.dart` | Invalidate paid entitlement, audience state, and loaded ads on identity changes; coordinate link/restore paths |
| `lib/data/repositories/curriculum_entitlement_repository.dart` | Reuse owner-scoped caching principles, but create a separate paid-entitlement repository with expiration and verification timestamps |
| `lib/presentation/screens/settings/settings_screen.dart`, routes, `lib/l10n/*.arb` | Add Pro status, paywall entry, restore, manage billing, and privacy controls with existing accessibility/localization patterns |
| `lib/core/legal/legal_content.dart`, `docs/site/privacy.html`, `docs/STORE_DATA_DISCLOSURE.md`, `docs/RELEASE.md` | Update policy/version, store answers, and release procedure together |
| `supabase/functions`, migrations and database tests | Add billing verification, authenticated notification handling, reconciliation, and owner-read-only paid entitlement state |
| `.github/workflows/ci.yml`, `.github/workflows/release.yml` | Add relevant tests, dependency checks, and test-ID/production-ID checks |

Candidate additions: `lib/core/monetization/` for configuration, eligibility and ad adapters; `lib/presentation/providers/monetization_providers.dart`; a billing repository and a Pro screen. Names are proposals, not existing modules.

At research time the official packages list `google_mobile_ads` **9.1.0** and `in_app_purchase` **3.3.1**. Resolve versions against Czechify's Flutter/Dart and Android toolchain at implementation time, pin the resulting lockfile, and use that release's APIs. Google documentation currently spans legacy and next-generation ad SDK guidance; do not mix examples from different SDK generations. [Google Mobile Ads package](https://pub.dev/packages/google_mobile_ads), [Flutter in-app purchase package](https://pub.dev/packages/in_app_purchase).

The Billing 7 update deadline was 31 August 2026, except approved extensions. Use a supported Billing 8+ native dependency and verify Gradle's resolved graph and merged version metadata; the Dart package version alone is not evidence of compliance. [Billing version deadlines](https://developer.android.com/google/play/billing/deprecation-faq.html).

### Ad coordinator contract

Evaluate eligibility before both load and show. Unknown entitlement suppresses ads during a bounded background refresh; learning never waits. Missing/expired monetization config defaults to no ads and no new checkout. Pro status, a privacy change, logout, an access gate, or a kill switch disposes any cached ad.

For the initial ads-only release, a verified global `pro_ever_launched=false` configuration may resolve the otherwise empty paid-entitlement system as free. Once any Pro product has launched, that flag is permanently true and every supported client must resolve purchase state before advertising. Disabling checkout later must never reset existing subscribers to free. Require an app build with working entitlement resolution before enabling Pro.

Keep one preloaded interstitial. Handle loading, ready, showing, dismissed, failure, and disposal explicitly. At a permitted Continue tap, atomically mark the attempt handled, check the current foreground route and all gates, and show only if ready. If absent or invalid, navigate immediately and consume that opportunity; never hold a learner on a spinner while loading an ad. Lock out repeated taps and navigate exactly once after dismissal or show failure. Pause lesson audio/TTS around the full-screen presentation. Respect SDK single-use/disposal rules. [Flutter interstitial integration](https://developers.google.com/admob/flutter/interstitial).

Use a durable device-level rolling impression history for caps so account switching cannot reset the daily limit; use account-scoped entitlement and attempt keys. Guard clock rollback and concurrent callbacks. Reinstallation may reset local frequency history; do not introduce fingerprinting to prevent it. Record successful impressions for revenue and cap accounting, with an in-flight reservation preventing simultaneous displays.

Proposed config fields: `ads_enabled`, `pro_purchase_enabled`, `rollout_percent`, `min_app_build`, `policy_version`, cooldown, daily cap, and lesson interval. Serve a small validated, read-only config from Supabase; clients cannot mutate it. Cache for at most 15 minutes, refresh on resume, and skip ads once stale until refreshed. Rollout assignment is stable and independent of Play age data. An ad already showing cannot be remotely recalled; the kill switch prevents subsequent loads/shows when refreshed. Purchase disablement must never disable restore, management, or existing Pro access.

## 6. Billing architecture and entitlement lifecycle

**Proposed default: Flutter `in_app_purchase` plus the existing Supabase backend.** This avoids another customer-data processor and fits existing account/RLS architecture, but Czechify must own lifecycle reliability. A managed alternative is RevenueCat: its published pricing is free up to $2,500 monthly tracked revenue, then 1% of tracked revenue. It can reduce billing operations, at the cost of another SDK, provider, identity integration, and disclosures. Decide before the billing implementation begins; do not implement both paths. The tasks below assume direct billing. [RevenueCat pricing](https://www.revenuecat.com/pricing).

Prefer linking the current anonymous Czechify account to Google/email before starting checkout, without forcing an account for free learning. Binding a subscription only to a disposable anonymous ID makes reinstall and cross-device recovery harder. Preserve the same Supabase identity when linking where possible. Account merge/restore conflicts need a deliberate recovery flow; never silently give one purchase to two Czechify accounts.

1. Subscribe to Play purchase updates early. Query products, display store prices, pass an obfuscated account reference, and distinguish pending, purchased, cancelled, error, and restored results.
2. Send the purchase token to an authenticated verification function. Derive the user from the verified JWT; never trust a submitted user ID, price, or `isPro` flag.
3. Verify package, product/base plan, purchase state, expiry and account binding with the Play Developer API. Persist the token association and entitlement idempotently. Keep service credentials server-side.
4. Acknowledge verified new purchases promptly with a server retry path; complete the client purchase flow as required by the plugin. Do not acknowledge a pending transaction. Avoid lost acknowledgements if the app closes. [Play purchase security](https://developer.android.com/google/play/billing/security), [Flutter purchase completion](https://pub.dev/packages/in_app_purchase).
5. Ingest Real-time Developer Notifications through authenticated Pub/Sub delivery. Validate Google OIDC issuer/audience and allowed service-account identity, durably enqueue/dedupe, then re-fetch authoritative Play state; a notification alone is not an entitlement. Add retry/dead-letter handling and scheduled reconciliation for missed events. [RTDN reference](https://developer.android.com/google/play/billing/rtdn-reference).

Proposed private purchase ledger: unique token hash plus securely stored token, owner, package, product/base plan, linked-token association, acknowledgment state, and verification timestamps. Do not log tokens or place them in exportable analytics. Public `subscription_entitlements` should expose only its owner's needed state (`pro`, status, expiry, last verification), with SELECT-only owner RLS and server-only writes. Keep raw billing records in a private schema. Supersede old linked tokens during replacements; reconciliation must not reactivate an obsolete purchase.

| Authoritative state | Pro behavior |
|---|---|
| Pending payment | No newly granted entitlement; show pending status without repeated checkout |
| Active, renewed, recovered | Ad-free for verified paid period; dispose preloads immediately |
| User cancelled, paid period still valid | Keep Pro until the verified expiry |
| Billing grace period | Keep Pro while the store reports grace |
| Account hold or effective pause | Suspend Pro; explain billing management |
| Expired | Remove paid entitlement after authoritative refresh |
| Revoked or refunded with access revoked | Remove promptly; re-query state rather than inferring access from a refund label alone |
| Network/verification unavailable | Preserve a valid cached paid period and temporarily suppress ads while uncertain; no new unverified paid-feature grant |

New purchases generally must be acknowledged within three days or Google refunds/revokes them. Pending transactions start that clock when they become purchased. Cancellation is not immediate expiration. These lifecycle distinctions must be tested. [Play subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions).

For the ad-only benefit, favor the learner under offline uncertainty: permit learning and show no ads until an authoritative result arrives. Cache by account with expiry and last verification; never reuse another account's Pro. Do not reuse this leniency to grant costly server AI features. Restore on reinstall/new device must query Play and reconcile the token with the signed-in Czechify account. Account deletion does **not** itself cancel Play billing: provide the management link and a clear notice before deletion, allow deletion regardless, and define minimal billing retention and future restore handling without retaining unnecessary learning data.

## 7. Sequenced implementation backlog

Estimates are engineering working days for one developer familiar with this app, including focused tests. They exclude Google reviews, account verification, policy review, and observation time. Total: approximately **18–27 days**, with an ads-only milestone after roughly **9–13 days** if external prerequisites are ready.

| Step | Work and deliverable | Acceptance gate | Estimate |
|---|---|---|---:|
| M0 | Confirm release baseline, audience approach, account setup, seller domain, budget/price hypotheses; record download and usage baseline | Source release identified; accounts and policy/config decisions documented | 1–2 days |
| M1 | Config, kill switch, entitlement interface, no-op platform adapter, frequency policy and deduplication | Ads default off; unknown/Pro/unsupported platforms never load ads | 2–3 days |
| M2 | AdMob/UMP Android integration, completion placement, policy/store disclosure updates, test IDs | Consent, failure, completion persistence, and ceremony exclusions verified on devices | 4–5 days |
| M3 | Internal-track AAB, console readiness, production configuration and small ad pilot | No SDK/ad blocker; app-ads.txt verified; operational rollback demonstrated | 2–3 days |
| M4 | Subscription products, Play API credentials, private ledger/RLS, verification, RTDN, reconciliation | Token replay/account isolation/acknowledgement/notification tests pass | 4–6 days |
| M5 | Paywall, account linking, restore/manage, expiry/offline UI, localization and disclosures | Real internal-track test purchases restore and suppress ads correctly | 3–5 days |
| M6 | Full billing lifecycle QA; enable Pro at 500 verified acquisitions when ready | State matrix and release checks signed off; metrics/support process ready | 2–3 days |

Suggested future PRs follow M1, M2, M4, and M5 as separate changes. M0/M3/M6 also require operator work in Google consoles. This planning branch adds no SDK, database migration, price change, or release artifact. Keep the currently submitted release separate, and rebase implementation onto whichever release is actually approved before preparing a new AAB.

## 8. Verification and rollout gates

**Automated tests to add during implementation:** pure eligibility/frequency rules; fake-clock rolling caps; account switch and Pro preemption; attempts handled once; consent changes while preloaded; absent/stale config; no-fill and show-failure navigation; completion-save failure prevents advertising; unit/exam exclusion; purchase state transitions; duplicate/out-of-order notifications; replayed or wrong-package tokens; acknowledgment retry; revoked purchase; RLS denial of self-granted Pro. Keep UI tests focused on real failure paths and retained learning progress.

**Device/store checks:** use Google test ads and registered test devices during development, and Play license testers/internal track for billing. Exercise pending approval/decline, accelerated renewals, cancellation, grace/hold, restore, refund/revocation and app termination during checkout. Test on a phone and tablet/foldable, edge-to-edge layouts, rotation, TalkBack, large text, reduced motion, interrupted audio, background/foreground, and offline mode. Google provides billing test tooling and accelerated subscription scenarios. [Play Billing testing](https://developer.android.com/google/play/billing/test).

Run the repository's existing Flutter analyze/test, changed-line coverage, edge-function checks, pgTAP and platform build checks for affected code. Resolve actual plugin/native compatibility before accepting the AAB. Android is the monetization launch scope; iOS/web/desktop use no-op monetization adapters, and existing platform builds must still compile. Ensure any plugin auto-registration/manifest requirements are satisfied even where runtime calls are disabled. iOS monetization needs a separate StoreKit/privacy/ATT assessment before activation.

Release progression: internal testing → approximately 10% eligible-user cohort → 25% → broader rollout. Keep a stable holdout while volume permits. Verify that the consent form and native billing/ad UI actually appear on Play-installed builds, not only debug builds. Use AdMob and Play reports for revenue and Android Vitals for stability. This does not require adding Firebase solely to launch monetization.

Establish 7–14 days of baseline and seek at least two weeks of pilot observation. At 500 downloads, a small cohort cannot establish statistically reliable retention or price differences quickly; report counts, denominators, and uncertainty, and do not claim a winning experiment from a handful of users.

Immediate ad kill-switch triggers: an ad during an exercise, ad shown to verified Pro, privacy gating failure, duplicated display, lost progress, or blocked navigation. Pause expansion for a material crash/ANR increase, policy warnings, or credible learner complaints. A **5 percentage-point** D7 retention decline or **10% relative** completion-rate decline is a proposed investigation threshold, not proof of causation at low sample sizes. Fix behavior before increasing frequency to chase revenue.

## 9. Measurement and operator handoff

Track download milestone, MAU/DAU, completed lessons, D1/D7 retention, eligible opportunities, requests, loads, impressions, eCPM by country/format where available, ad earnings, paywall views, purchases, refunds, cancellations, active paid subscriptions, and support complaints. Report both revenue per total MAU and per ad-eligible MAU. Distinguish cash billings from normalized monthly recurring revenue for annual plans.

Prefer existing store/AdMob aggregates first. If adding product events, document that as new analytics processing, choose its lawful basis and controls, and update disclosures before sending events. Proposed event vocabulary: `lesson_completed`, `ad_opportunity`, `ad_skipped_reason`, `ad_impression`, `paywall_view`, `purchase_result`, `restore_result`. Use a minimal pseudonymous installation scope, a bounded queue, and an initial 30-day raw-event retention proposal; aggregate afterward. Exclude lesson answers, tutor messages, audio, emails, purchase tokens, and all Play age signals. Suppress optional analytics when its permission is absent. Do not mislabel pseudonymous events as anonymous.

Before live activation, the owner/operator supplies or confirms:

- The approved production build, current acquisition count, countries, audience declarations, and baseline usage/cost reports.
- AdMob publisher/app/unit identifiers, payment setup, app readiness, seller-file verification, published consent messages, and production privacy deployment.
- Play product/base-plan configuration and local prices, developer API service access, Pub/Sub topic and authenticated notification delivery, tester accounts, and reconciliation monitoring.
- Final Pro terms and cancellation/deletion wording, independent audience handling, and remote rollout settings.

These are implementation prerequisites, not reasons to delay this research deliverable. No credentials belong in the report or source control. At this scale, the principal success criteria are continued learning, reliable purchases, and useful revenue evidence—not matching Duolingo's scale or a fixed per-user advertising target.
