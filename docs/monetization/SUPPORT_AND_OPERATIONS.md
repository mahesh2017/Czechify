# Support recovery and operations (PR 7c)

Everything here runs with the service role, in the Supabase SQL editor or through `monetization-worker`. Clients can't reach any of it.

## Purchase recovery

A purchase never follows its token to another account on its own. A **recovery case** opens automatically when a linked account restores a Play purchase that:
- belongs to a deleted account (`ownerless`);
- belongs to another Czechify account (`other_account`);
- or was bought under another account's Play binding (`play_binding`).

Google Play settles most of these without you. Until a purchase has been confirmed for someone, the account whose obfuscated ID Play reports is its buyer: the purchase moves there and any open case about it closes with `decided_by = google_play`. That covers a second account on the same phone restoring first. Cases that reach you are the rest: a purchase already confirmed for another account, a deleted owner, or a binding that is no Czechify account's.

The app shows the learner the case ID as their reference, next to an "Email support" button that puts the reference in the subject line. Restoring again returns the same open case.

### Deciding a case

1. **Look it up.**
   ```sql
   select support_recovery_case('<case id>');
   ```
   The result shows:
   - the requester: account, email, linked or not;
   - the current owner, or `null` if that account was deleted, with their email and last sign-in;
   - the purchase: product, state, validity, when it was registered and last verified.

   It never shows a token.
2. **Confirm it's the same buyer.** Ask for the Google Play order number (it starts with `GPA.`) and find it in Play Console under Order management. The order's product and date must match the case, and the requester's restore already proves that their Google account holds the purchase.
   - **`ownerless`:** a matching order is enough.
   - **`other_account`:** the current owner loses the purchase if you approve. Approve only if the requester also proves control of that account (for example, they write from its email or sign in to it), or if both accounts plainly belong to the same person, such as an old anonymous account from a lost phone. Otherwise reject, and tell the requester to sign in to the owning account.
   - **`play_binding`:** the purchase was bought while signed in to another Czechify account. Treat it like `other_account`, using `support_account_summary` for both accounts.
3. **Decide, with your name and a reason.** Both are required and audited.
   ```sql
   select resolve_purchase_recovery('<case id>', true, 'you@czechify', 'Play order GPA.1234-... matches, bought 3 Nov');
   select resolve_purchase_recovery('<case id>', false, 'you@czechify', 'order not found');
   ```
   Approving does four things:
   - moves the purchase to the requester and ends the previous owner's access from it;
   - closes any other open cases for it;
   - queues a Play verification;
   - means access follows only if Google Play reports the purchase as active. The binding Play reports at that verification is recorded, and later renewals must match it.
4. **Reply to the learner.** Ask them to reopen Subscriptions, or wait for the next background refresh.

Open cases expire after 90 days, and decided cases are deleted 90 days after the decision. A learner can always restore again to reopen a case.

### Looking at one account

```sql
select support_account_summary('<user id>');
```

Returns the account's signed snapshot, its purchases (no tokens), its recovery cases, its invitation status, its existing-user migration status, and its last 20 billing events.

Other support decisions have their own runbooks:
- referral reviews: `resolve_referral_review`, in [REFERRAL_BACKEND.md](REFERRAL_BACKEND.md);
- legacy claims: `resolve_legacy_claim`, in [BACKEND_SETUP.md](BACKEND_SETUP.md#existing-user-migration-pr-7a).

## Operations report

```sql
select monetization_operations_report();
```

`monetization-worker` runs it on every pass. It returns the report under `operations` and logs one `monetization_alert` line per crossed threshold, which a log drain or alerting rule can pick up. The report's metrics:

| Metric | Meaning |
|---|---|
| `verify_p95_seconds`, `verifications_30m` | Purchase verification time, from registration to result, over the last 30 minutes. |
| `unacknowledged_over_1h` | Active purchases not acknowledged to Google Play after an hour. Play refunds unacknowledged purchases after three days. |
| `acknowledged_without_access` | Acknowledged to Google, but the learner has no access recorded. |
| `dead_billing_jobs`, `oldest_due_billing_job_seconds` | Jobs that gave up, and the backlog. |
| `unmatched_notifications_24h` | Play notifications for tokens no account registered. |
| `referral_queue_age_seconds`, `referral_rewards_24h` | Oldest invitation milestone waiting to be processed; rewards granted in the last day. |
| `referral_reviews_open`, `legacy_claims_open`, `recovery_cases_open` (each with its oldest age) | Support queues. |
| `ai_spend_today_micros`, `ai_ceiling_trips_7d`, `ai_results_unavailable_24h` | AI cost, spend-ceiling trips and uncertain provider outcomes. |

### Alerts and what to do

| Alert | Level | Threshold | Action |
|---|---|---|---|
| `acknowledged_without_access` | **pause** | any | Immediate pause trigger from the release plan. Turn off checkout for the cohort, keep verification, acknowledgement and restore running, then reconcile each purchase with `support_account_summary`. |
| `verification_slow` | investigate | p95 over 30 s | Check the Play Developer API quota and errors in the worker logs. |
| `acknowledgement_overdue` | investigate | any purchase unacknowledged after 1 h | Check the acknowledge jobs. Play refunds after three days. |
| `billing_jobs_dead` | investigate | any | Read `last_error_code` and requeue after fixing the cause. |
| `referral_queue_slow` | investigate | oldest over 15 min | Check whether processing is paused and whether the worker is running. |
| `ai_ceiling_tripped` | investigate | more than 1 trip in 7 days | Compare observed token use with the budget before raising the ceiling. |
| `support_queue_waiting` | support | any case over 48 h | Work the oldest referral review, legacy claim or recovery case. |

With little traffic, look at every failure rather than trusting percentages. The rollback steps are in [IMPLEMENTATION_AND_TESTS.md](IMPLEMENTATION_AND_TESTS.md): pause, never delete entitlements, reconcile.

### Dashboard queries

For a saved SQL-editor dashboard:

```sql
-- Headline numbers and current alerts
select key, value from jsonb_each(monetization_operations_report()) order by key;

-- Purchases by state
select product_id, state, count(*) from monetization_private.store_purchases
where user_id is not null group by 1, 2 order by 1, 2;

-- Referral rewards per day (last 30 days)
select date_trunc('day', created_at)::date day, outcome, count(*)
from monetization_private.referral_reward_events
where created_at > now() - interval '30 days' group by 1, 2 order by 1;

-- AI spend per day against the ceiling
select spend_day, cost_micros / 1e6 as amount_in_billing_currency, ceiling_tripped_at
from monetization_private.ai_project_spend order by spend_day desc limit 30;
```
