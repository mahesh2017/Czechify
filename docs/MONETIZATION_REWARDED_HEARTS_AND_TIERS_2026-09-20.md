# Czechify: rewarded hearts and course/AI subscription tiers

20 September 2026. Follow-up to the [initial monetization plan](MONETIZATION_RESEARCH_AND_PLAN_2026-09-20.md), on `codex/monetization-research-plan`. Research and product proposal only; no app behavior or store products changed.

**Superseded:** the user has moved to a limited free course and referrals, with no advertising. Read the [current assessment](MONETIZATION_COURSE_ACCESS_AND_REFERRALS_2026-09-20.md); the rewarded-heart work and free-full-course assumption below are historical.

## Recommendation

Test optional **one rewarded ad for one heart**, retain a free recovery route, and evaluate **250 CZK/month for Pro** and **400 CZK/month for Pro + AI chat**. Present the extra 150 CZK as the difference between two tiers, with one active subscription, rather than requiring two separate purchases. Rewarded ads can complement subscriptions, but frustration alone is a poor measure of success: users can leave instead of buying.

**Confirmed by the user:** keep free learning; 250 CZK/month removes ads and heart limits. The full core course remains available to free learners. The proposed additional 150 CZK buys AI chat, giving a 400 CZK/month combined tier. These remain proposed launch prices, not configured store products or validated willingness to pay.

## Current hearts behavior, verified in source

| Behavior | Evidence |
|---|---|
| Default maximum is five hearts | `lib/domain/entities/gamification_state.dart`; database defaults and gamification provider |
| One missing heart regenerates every 30 minutes | `heartRegenInterval` and `_checkHeartRegen()` in `lib/presentation/providers/gamification_providers.dart` |
| A completed review of at least five cards can restore one heart | `lib/presentation/providers/review_providers.dart` |
| Anyone can disable hearts | Switch in `lib/presentation/screens/settings/settings_screen.dart` and `heartsEnabled` settings |
| There is a one-heart refill method | `GamificationNotifier.refillHeart()`; currently also resets the regeneration timestamp |
| Running out of hearts leads to review/retry/navigation options | `_GameOverScreen` in `lib/presentation/screens/lesson/lesson_player_screen.dart` |

Moving unlimited hearts into Pro therefore changes an existing free benefit. My recommendation is to preserve existing users' hearts-off option and evaluate a clearly disclosed hearts-limited policy for new users, rather than silently switching existing users back to five hearts. This cohort rule and its persistence/reinstall implications need a product decision before implementation. In the meantime, only show rewarded heart offers when a user has enabled hearts and has room for a refill.

## Rewarded video: supported, but optional

Google permits non-transferable in-app rewards such as extra lives. The action and reward must be clear before display; ordinary rewarded ads require an affirmative opt-in, must be dismissible, and refusing/skipping must not interfere with normal app use. Deliver the earned reward. A mandatory ad wall as the only way to continue normal learning is not the recommended compliant implementation. [AdMob rewarded-ad policy](https://support.google.com/admob/answer/7313578?hl=en).

Offer these choices at an out-of-hearts screen:

- **Watch an ad → +1 heart**, only when an eligible ad is ready.
- **Review five words → +1 heart**, with a usable practice fallback when fewer than five due cards exist.
- **Wait for the next free heart**, showing the actual regeneration countdown.
- **Explore Pro**, plus an ordinary way back to learning/navigation.

Do not auto-play a video when a learner makes a mistake. Do not require clicking the advertisement or installing the advertised app. Closing before earning the reward gives no bonus heart, but never removes existing progress/hearts or blocks the free alternatives. The ad SDK determines the completion condition; do not promise a fixed 15- or 30-second duration or grant from an app timer. Use the SDK's earned-reward event rather than the close/impression callback. [Flutter rewarded integration](https://developers.google.com/admob/flutter/rewarded).

Start the pilot with at most three rewarded grants per rolling 24 hours. Keep the earlier maximum of three total full-screen ad impressions across formats and a five-minute gap; do not stack a lesson interstitial immediately after a rewarded video. These are adjustable product hypotheses. Disable automatic lesson interstitials in an initial rewarded-only cohort so we can assess that experience separately. Pro users see neither format.

Apply the original plan's consent, independent audience, and privacy controls unchanged. Ad-unavailable, offline, declined-consent, minor/unknown-audience and daily-cap states must retain free recovery. Making the entire app dependent on fill rate would also make ordinary service availability depend on an advertising auction.

Google describes rewarded ads as potentially high-yield because of engaged, completing viewers. Its promotional examples are not a current Czech market benchmark or a promise of incremental revenue for Czechify. Longer viewing does not mean payment at a fixed rate per second. [Google's rewarded-ad overview](https://admob.google.com/home/resources/rewarded-ads-win-for-everyone/).

For illustration only: at **300 CZK eCPM**, one displayed rewarded ad produces **0.30 CZK** on average. Two a day for 20 active days produce **12 CZK/month per viewer**. At **600 CZK eCPM**, that becomes **24 CZK**. These are assumptions, not measured rates. Reaching 400 CZK would still require about **1,334 or 667 impressions per month**, respectively. Advertising ARPU remains distinct from the 400 CZK subscription price.

## Tier structure and price validation

| Proposed plan | Monthly consumer price | Benefit |
|---|---:|---|
| Free | 0 CZK | Core learning with measured ad placements; five-heart mode and free recovery where enabled; retain existing-user exceptions |
| Pro | 250 CZK | Ad-free core course and no heart interruptions; no open-ended AI chat |
| Pro + AI | 400 CZK total | Everything in Pro plus a clearly stated AI-chat allowance |

The tier structure is credible: Busuu, for example, places AI Conversations in Premium Plus. This validates a packaging pattern, **not Czechify's proposed local price or demand**. [Busuu plan comparison](https://www.busuu.com/en/premium-plans).

250 CZK is a hypothesis worth testing for Czech-specific course value, progression, and exam preparation. It needs more perceived value than ad removal alone. 400 CZK should buy a useful tutoring experience: Czech practice, corrections, explanations, and continuity. Describe only capabilities actually verified in the release. Do not promise exam success or sell ordinary course corrections again as an unexpected AI surcharge.

Use one active tier and Play's subscription replacement flow. Proposed product IDs: `czechify_pro` and `czechify_pro_ai`, each with a monthly base plan. Different benefits belong in separate products; base plans vary billing terms for the same benefits. Upgrade/downgrade handling must reconcile the old token, prorated/deferred timing and actual new charge. Show Play's checkout terms rather than promising every mid-cycle upgrade costs exactly 150 CZK immediately. Downgrade should normally take effect at the paid-period boundary. [Play subscription changes](https://developer.android.com/google/play/billing/subscriptions).

Two independent subscriptions would require managing two renewals, refund paths, and what happens when course access expires while AI remains paid. Google also documents subscriptions with add-ons, but a mutually exclusive tier launch avoids adding that integration complexity. Revisit add-ons if learners later want AI independently.

Validate with actual paid conversion, first renewal, refund rate, D7 learning retention and support feedback. Avoid dividing 500 downloads into many price experiments: start with one disclosed price per offer and accumulate evidence. Ten Pro subscribers yield 2,500 CZK/month in gross billings; ten Pro + AI subscribers yield 4,000 CZK. These are arithmetic scenarios, not forecasts or take-home earnings. Do not count the same subscriber in both groups.

## AI allowance and implementation consequences

The source backend uses Scaleway with default model `deepseek-v4-flash-0731`, configurable server-side. It currently defaults to **20 non-summary AI requests/day** and **60 summary requests/day**, with environment overrides. Non-summary requests include conversation, grammar checking, and writing evaluation; this is not a dedicated paid-chat quota. Production settings were not inspected.

Entitlements should be explicit: `ad_free`, `unlimited_hearts`, and `ai_chat`. The AI function must check the server-owned paid entitlement before sending a chat or associated summary request upstream. Gate by operation, not the whole proxy: preserve grammar/writing feedback needed by the core course, and retain separately budgeted speech behavior. Hiding the chat button alone does not prevent unpaid API use. A change to existing free chat access also needs an advance notice and transition rule; initial suggestion is a disclosed 30-day transition for existing users, subject to the final product decision.

Starting allowance hypothesis: **20 successful tutor replies/day**, with bounded context/output size, separate background-summary budget, and clear reset time. Show this limit before purchase. Do not call it unlimited. Price the actual token usage of complete conversations, including replayed context, summaries, retries, and speech if included; do not estimate costs from message count alone. Backend cost logs should contain counts/model/cost metadata, not learner text.

The 150 CZK tier increment leaves **127.50 CZK after only a 15% Play fee**, before VAT/tax treatment, refunds and operating expenses; it is not the AI spending allowance. Use actual Play proceeds to establish the budget. A preliminary target is AI variable cost below 25% of net incremental receipts, with per-user and project-wide ceilings. Measure typical and heavy-use accounts before increasing quotas. Existing package/model names are not evidence of current contracted token rates. [Play fee schedule](https://support.google.com/googleplay/android-developer/answer/112622?hl=en-GB).

## Additional engineering work

1. **Reward grant reliability:** add a dedicated rewarded unit and provider. Persist an account-bound, unique reward claim before showing; apply an earned heart exactly once in a Drift transaction with a grant ledger. Recheck regeneration first and preserve partial timer progress; simply calling today's `refillHeart()` would restart its timer. Update the paused lesson's hearts and clear its game-over state without discarding the current attempt, answer evidence or draft. Keep cap five; handle a heart filling concurrently so a promised reward is not lost, for example by storing one deferred earned-heart credit.
2. **Server verification:** reconcile rewarded claims with signed AdMob SSV callbacks, validate expected unit/reward and deduplicate transaction IDs. Use an opaque one-time claim token, never email or Play age data, as callback custom data. Client earned events may grant immediately for this low-value reward; verified callbacks recover missed grants without awarding twice. SSV does not make an otherwise client-writable, offline heart balance tamper-proof. [AdMob SSV](https://developers.google.com/admob/flutter/ssv).
3. **Paid tiers:** extend server entitlement verification, cached offline rules, UI, restore and upgrade/downgrade tests. Enforce `ai_chat` server-side; preserve course feedback under `Pro`. Paid chat fails safely on unresolved entitlement while local learning stays usable.
4. **Migration and testing:** test existing hearts-off users, empty review queues, reward followed by account switch, duplicate/delayed callbacks, app termination, completed video without immediate network, regeneration during video, subscription activation during reward, no-fill, and exactly-once resumption. Cover shared quotas so ordinary course feedback cannot exhaust a separately purchased chat allowance.

Budget an additional **8–12 engineering days** for rewarded recovery/verification plus tiered AI access and their tests, over the initial plan. This estimate needs refinement after deciding legacy hearts and chat benefits; a course paywall is excluded by the user's confirmed direction. Continue using the original 500-acquisition milestone for paid rollout, subject to verified billing readiness. No purchase or reward functionality is enabled by these documents.
