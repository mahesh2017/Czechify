# Activation runbook (PR 8)

This takes the monetization work from "built and switched off" to a monitored launch. Steps marked **You** need your accounts: Supabase, Google Play Console, Google Cloud and real devices. None of them has been done by the implementation. Everything else is already in the code.

The release plan's order holds throughout:
1. staging, then the device and Play test matrix;
2. publish the privacy wording and support text;
3. take the existing-user snapshot at the cutoff;
4. internal testers, then a closed cohort, then 10%, 50% and everyone.

Stay at least 48 hours at each external stage, and don't treat silence as success: every stage needs observed purchases, restores and referral rewards. Rollback never reverts migrations or deletes entitlements.

## 0. What controls what

| Control | Where | Starts |
|---|---|---|
| Who gets each feature | `set_rollout(feature, percent, allowlist, operator, reason)`. Features: `play_checkout`, `course_paywall`, `referral_claims`, `paid_chat`. Buckets are stable per account and shared by all features, so widening never drops anyone. A paywall or paid chat can never reach further than checkout. | all 0% |
| Products sold at all | `set_billing_product_enabled('czechify_core' \| 'czechify_ai', true/false)` | off |
| Referral campaign | `set_referral_campaign(...)`: window, enabled, processing paused | off, paused |
| AI enforcement | Proxy secrets `AI_PAID_CHAT_REQUIRED` and `AI_COURSE_ACCESS_REQUIRED`. Each applies only to accounts in the matching cohort (`paid_chat`, `course_paywall`). | off |
| Emergency AI stop | `AI_PROVIDER_REQUESTS_ENABLED=false`, and the daily ceiling `AI_DAILY_SPEND_CEILING_MICROS` | on, ceiling 20 |
| Staging-only previews | `MONETIZATION_*_PREVIEW` dart-defines, which **work only in debug and profile builds**. Release builds, internal track included, follow `set_rollout`, so put testers on its allowlist. | — |

Every `set_rollout` call is recorded in `monetization_private.rollout_changes` with its operator and reason.

## 1. Staging backend — **You**

1. Create a separate Supabase project for staging, in the EU (Frankfurt or Paris, matching production).
2. `supabase link --project-ref <staging>` then `supabase db push`. Check that the migration list ends at `20260930100000_staged_rollout`.
3. Deploy the functions: `supabase functions deploy monetization-api deepseek-proxy play-billing-notifications monetization-worker account-data`.
4. Set secrets as listed in [BACKEND_SETUP.md](BACKEND_SETUP.md):
   - snapshot signing key;
   - billing keys;
   - Play service account;
   - push audience and account;
   - worker secret;
   - `AI_REPLAY_KEY`;
   - Play Integrity digests and service account;
   - `LEGACY_CLAIM_REVIEW_UNITS`;
   - `MONETIZATION_ALERT_WEBHOOK_URL`: an https webhook such as Slack, Discord or a paging service. Each crossed alert is sent at most once an hour while it stays crossed.
5. Schedule `monetization-worker` every minute (the SQL is in BACKEND_SETUP §8). After a few minutes, check that `select monetization_operations_report();` is fresh and that a test alert reaches the webhook.
6. Generate staging Ed25519 keys; never reuse the test vector. Build the staging app with `MONETIZATION_SNAPSHOT_PUBLIC_KEYS`, `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER` and the staging `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

## 2. Google Play and Google Cloud — **You**

1. Play Console → Monetize → Subscriptions:
   - `czechify_core` and `czechify_ai`, each with a `monthly` base plan and prices;
   - the descriptions must state the AI plan's daily limit and that lessons belong to Core.
2. License testers: add the testers' Google accounts. Their purchases are free and renew quickly.
3. Real-time developer notifications: a Pub/Sub topic plus an authenticated push subscription to `play-billing-notifications` (BACKEND_SETUP §8).
4. Play Developer API: link the Cloud project and give the service account financial data and order management rights.
5. Play Integrity: link the Cloud project and copy the app-signing certificate SHA-256 into `PLAY_INTEGRITY_CERT_DIGESTS`.
6. Upload the staging build to the **internal testing** track. Play Integrity and billing only behave for real when the app is installed from Play.

## 3. Test matrix on staging — **You**, with me reading results

Put the testers on the allowlist:

```sql
select set_rollout('play_checkout', 0, array['<tester uuid>', ...]::uuid[], '<you>', 'staging testers');
select set_rollout('course_paywall', 0, array['<tester uuid>', ...]::uuid[], '<you>', 'staging testers');
select set_rollout('referral_claims', 0, array['<tester uuid>', ...]::uuid[], '<you>', 'staging testers');
select set_rollout('paid_chat', 0, array['<tester uuid>', ...]::uuid[], '<you>', 'staging testers');
select set_billing_product_enabled('czechify_core', true), set_billing_product_enabled('czechify_ai', true);
```

Then run each row on at least one real Android phone, preferably one old and one new:

| # | Scenario | Expected |
|---|---|---|
| 1 | Fresh anonymous install; finish units 1–2 | Units 3+ show the paid boundary. Upgrade needs a linked account. |
| 2 | Link Google, then buy Core | Verified within about 30 s, then lessons open. Acknowledged in Play (check the order). |
| 3 | Buy AI chat on a Core-only account | Chat opens and the stated daily limit applies; Core alone never opens chat. |
| 4 | Uninstall, reinstall, sign in, restore | Access returns without buying again. |
| 5 | Cancel in Play | Access continues until the paid-through date, then stops. |
| 6 | Payment decline, account hold, recovery | Hold removes access; recovery restores it. |
| 7 | Refund or revoke from Play Console | Access ends at the next refresh. |
| 8 | Airplane mode for 8 days on Core | Access for 7 days offline, then asks to reconnect. Free and permanent units always stay. |
| 9 | Delete account with an active subscription | Warned that Play keeps charging. After deletion, restore on a new account opens a recovery case with a reference; support approves (SUPPORT_AND_OPERATIONS.md) and access returns after the Play check. |
| 10 | Invite a friend (Integrity switch on); the friend finishes units 1–2 | The inviter gets 2 permanent units. The friend's rows show progress only. |
| 11 | Same, with the Integrity switch off | A review case appears; after approval, the rewards arrive. |
| 12 | Switch Google accounts mid-lesson and mid-purchase | Nothing carries over between accounts; the purchase stays with the account that started it. |
| 13 | Export data; delete account | The export has the subscription and referral records, with no tokens and no other learner. |
| 14 | Account created before the staging T0 (run §5 on staging) | The explanation card and grace are shown, the kept units are listed, and the one offline claim works. |
| 15 | AI spend ceiling set low | Chat says it's temporarily unavailable and the `ai_spend_ceiling_tripped` log line appears. A second trip within 7 days raises the `ai_ceiling_tripped` alert. |

Go/no-go gate:
- every row passes;
- `monetization_operations_report()` shows no `pause` alert;
- the release commit's CI passed, including `supabase test db` and the concurrency checks;
- the privacy wording is published (§4).

## 4. Privacy, listing and support text — **You**

1. Publish `docs/site/privacy.html` (version 2026-09-22.1) to the website. The in-app policy in this release carries the same version and wording.
2. Play Console → Data safety: apply the table in [PRIVACY_AND_DATA_SAFETY.md](PRIVACY_AND_DATA_SAFETY.md) (purchase history; Play Integrity device information, optional).
3. Store listing: mention the subscriptions and that units 1–2 are free. Play shows prices itself.
4. Confirm with your accountant how long Google's payout and tax reports are kept (5 years for accounting records, 10 for VAT documents).

## 5. Existing-user migration at T0 — **You**, in production

1. Pick T0: the moment the first external cohort gets the paywall. Record the migration ID, for example `t0-2026-11-01`.
2. Ship the app release first, with everything at 0%, and let it reach most users.
3. At or after T0: `select legacy_migration_prepare('<id>', '<T0>', 25);`. Review the dry run (counts and sample accounts).
4. `select legacy_migration_apply('<id>', '<you>');`. Then work any claims waiting for support (SUPPORT_AND_OPERATIONS.md) within 48 hours.

## 6. Staged activation in production — **You**

| Stage | Commands | Hold |
|---|---|---|
| Internal testers | `set_rollout` for each feature with the testers' allowlist; enable products; campaign window set, processing unpaused | until the §3 rows pass on production |
| Closed cohort | Add the closed-cohort accounts to the allowlists | 48 h, with observed purchase, restore and reward |
| 10% | `set_rollout(<feature>, 10, <allowlist>, ...)`, checkout first, then paywall, referrals and paid chat | 48 h or longer if traffic is low |
| 50% | same with 50 | 48 h |
| All | same with 100 | — |

Set `AI_PAID_CHAT_REQUIRED` and `AI_COURSE_ACCESS_REQUIRED` to `true` when paid chat and the paywall first reach anyone. They still apply only to accounts in those cohorts. Old app versions in a cohort are asked to update rather than served free.

## 7. Pause and rollback

On a `pause` alert or any immediate trigger (a duplicate or wrong-account grant, cross-account data, access lost before its paid-through date):

```sql
-- Stop new exposure: the paywall and paid chat first, then checkout.
select set_rollout('course_paywall', 0, '{}', '<you>', 'incident <id>');
select set_rollout('paid_chat', 0, '{}', '<you>', 'incident <id>');
select set_rollout('play_checkout', 0, '{}', '<you>', 'incident <id>');
-- Referral rewards only, if they are the problem:
-- Keep the campaign and its window; pause processing only.
select set_referral_campaign(id, true, true, starts_at, claim_closes_at, ends_at)
  from monetization_private.referral_campaigns where id = 'a1-referral-v1';
```

Keep verification, acknowledgement and restore running; never delete entitlements or revert migrations. Reconcile affected accounts with `support_account_summary`, then widen again stage by stage.
