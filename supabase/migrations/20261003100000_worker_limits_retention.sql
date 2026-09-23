-- PR 11: three more fixes from the Sep 23 review.
--
-- 1. Purchase checks are rate limited per account. Each one may call the
--    Play Developer API, whose daily quota the whole app shares, and each
--    new token was kept for good: one account sending made-up tokens could
--    exhaust the quota and grow the table without limit.
-- 2. The dead-job alert counts jobs that died in the last day, not every
--    dead job still kept (30 days), so one failure no longer keeps it on
--    for a month. Tokens that never became a purchase are deleted.
-- 3. A deleted account's purchase is deleted even when its last known state
--    was active. Nothing re-checks it after the owner is gone, so its state
--    stayed "active" and the old rule (delete once expired) never fired.
begin;

-- 1. One row per purchase check; kept a day.
create table monetization_private.purchase_verify_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  attempted_at timestamptz not null default now()
);
create index purchase_verify_attempts_rate on monetization_private.purchase_verify_attempts(user_id, attempted_at);
alter table monetization_private.purchase_verify_attempts enable row level security;
revoke all on monetization_private.purchase_verify_attempts from public, anon, authenticated, service_role;

-- Records a check and says whether it is within p_limit an hour. A refused
-- check is not recorded, so waiting always frees the account again.
create function public.allow_purchase_verification(p_user uuid, p_limit integer)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null or p_limit is null or p_limit < 1 then
    raise exception 'An account and a limit are required' using errcode = '22023';
  end if;
  if (select count(*) from monetization_private.purchase_verify_attempts
      where user_id = p_user and attempted_at > now() - interval '1 hour') >= p_limit then
    return false;
  end if;
  insert into monetization_private.purchase_verify_attempts(user_id) values (p_user);
  return true;
end $$;

-- 2. As in 20260922110000, with dead jobs counted over the last day.
create or replace function public.billing_health()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'unacknowledged_over_1h', (select count(*) from monetization_private.store_purchases p
      where p.acknowledgement_state = 'pending'
        and p.state in ('active','in_grace_period','canceled') and p.valid_until > now()
        and p.last_verified_at < now() - interval '1 hour'),
    'dead_jobs', (select count(*) from monetization_private.billing_jobs
      where state = 'dead' and updated_at > now() - interval '1 day'),
    'oldest_due_seconds', (select coalesce(extract(epoch from now() - min(not_before))::integer, 0)
      from monetization_private.billing_jobs where state in ('ready','retry') and not_before <= now()),
    'unmatched_notifications_24h', (select count(*) from monetization_private.billing_notification_inbox
      where outcome = 'unmatched' and received_at > now() - interval '1 day'));
$$;

-- As in 20260929100000, plus dead_billing_jobs_24h, which the alert now uses.
create or replace function public.monetization_operations_report()
returns jsonb language sql stable security definer set search_path = '' as $$
  with m as (
    select
      (select coalesce(percentile_cont(0.95) within group (order by extract(epoch from j.updated_at - j.created_at)), 0)
        from monetization_private.billing_jobs j
        where j.operation = 'verify' and j.state = 'done' and j.updated_at > now() - interval '30 minutes') verify_p95_seconds,
      (select count(*) from monetization_private.billing_jobs j
        where j.operation = 'verify' and j.state = 'done' and j.updated_at > now() - interval '30 minutes') verifications_30m,
      (select count(*) from monetization_private.store_purchases p
        where p.acknowledgement_state = 'pending' and p.state in ('active','in_grace_period','canceled')
          and p.valid_until > now() and p.last_verified_at < now() - interval '1 hour') unacknowledged_over_1h,
      -- Acknowledged to Google but no access recorded: an immediate pause trigger.
      (select count(*) from monetization_private.store_purchases p
        where p.acknowledgement_state = 'acknowledged' and p.user_id is not null
          -- A just-recovered purchase waits for its new owner's verification.
          and (p.recovered_at is null or p.last_verified_at > p.recovered_at)
          and not exists (select 1 from monetization_private.feature_entitlements f
            where f.user_id = p.user_id and f.source_key = 'play:' || p.id::text)) acknowledged_without_access,
      (select count(*) from monetization_private.billing_jobs where state = 'dead') dead_billing_jobs,
      (select count(*) from monetization_private.billing_jobs
        where state = 'dead' and updated_at > now() - interval '1 day') dead_billing_jobs_24h,
      (select coalesce(extract(epoch from now() - min(not_before))::integer, 0)
        from monetization_private.billing_jobs where state in ('ready','retry') and not_before <= now()) oldest_due_billing_job_seconds,
      (select count(*) from monetization_private.billing_notification_inbox
        where outcome = 'unmatched' and received_at > now() - interval '1 day') unmatched_notifications_24h,
      (select coalesce(extract(epoch from now() - min(q.qualified_at))::integer, 0)
        from monetization_private.referral_milestones q
        join monetization_private.referral_claims c on c.id = q.claim_id
        join monetization_private.referral_campaigns k on k.id = c.campaign_id
        where q.status = 'verification_pending' and c.risk_state = 'clear' and not k.processing_paused
          and c.referrer_id is not null and c.referee_id is not null) referral_queue_age_seconds,
      (select count(*) from monetization_private.referral_reward_events
        where outcome = 'granted' and created_at > now() - interval '1 day') referral_rewards_24h,
      (select count(*) from monetization_private.referral_review_cases where resolved_at is null) referral_reviews_open,
      (select coalesce(extract(epoch from now() - min(opened_at))::integer, 0)
        from monetization_private.referral_review_cases where resolved_at is null) oldest_referral_review_seconds,
      (select count(*) from monetization_private.legacy_migration_claims where status = 'needs_review') legacy_claims_open,
      (select coalesce(extract(epoch from now() - min(received_at))::integer, 0)
        from monetization_private.legacy_migration_claims where status = 'needs_review') oldest_legacy_claim_seconds,
      (select count(*) from monetization_private.purchase_recovery_cases where status = 'open') recovery_cases_open,
      (select coalesce(extract(epoch from now() - min(opened_at))::integer, 0)
        from monetization_private.purchase_recovery_cases where status = 'open') oldest_recovery_case_seconds,
      (select coalesce(sum(cost_micros), 0) from monetization_private.ai_project_spend
        where spend_day = (timezone('utc', now()))::date) ai_spend_today_micros,
      (select count(*) from monetization_private.ai_project_spend
        where ceiling_tripped_at is not null and spend_day > (timezone('utc', now()))::date - 7) ai_ceiling_trips_7d,
      (select count(*) from monetization_private.ai_request_reservations
        where state = 'result_unavailable' and created_at > now() - interval '1 day') ai_results_unavailable_24h)
  select to_jsonb(m) || jsonb_build_object('generated_at', now(), 'alerts', (
    select coalesce(jsonb_agg(jsonb_build_object('alert', a, 'level', level)), '[]'::jsonb) from (values
      ('acknowledged_without_access', 'pause', m.acknowledged_without_access > 0),
      ('verification_slow', 'investigate', m.verify_p95_seconds > 30),
      ('acknowledgement_overdue', 'investigate', m.unacknowledged_over_1h > 0),
      ('billing_jobs_dead', 'investigate', m.dead_billing_jobs_24h > 0),
      ('referral_queue_slow', 'investigate', m.referral_queue_age_seconds > 900),
      ('ai_ceiling_tripped', 'investigate', m.ai_ceiling_trips_7d > 1),
      ('support_queue_waiting', 'support', greatest(m.oldest_referral_review_seconds, m.oldest_legacy_claim_seconds,
        m.oldest_recovery_case_seconds) > 172800)) t(a, level, crossed)
    where crossed))
  from m;
$$;

-- 2 and 3. As in 20261002100000, with three changes:
--
-- * a deleted account's purchase goes 120 days after the last paid-through
--   date seen, whatever its last known state. That covers Play's longest
--   grace, hold or pause. After that a restore opens a support case from
--   Play's own record, so recovery still works.
-- * a token that never became a purchase (never confirmed by Play, nothing
--   pending, no open case) goes 30 days after it was sent in.
-- * purchase-check rate rows go after a day.
create or replace function public.cleanup_privacy_records()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare purchases integer; receipts integer; snapshot integer; inbox integer; intents integer;
  jobs integer; billing_audit integer; grant_audit integer; cases integer; discoveries integer;
  unconfirmed integer; attempts integer;
begin
  delete from monetization_private.store_purchases p
    where p.user_id is null
      and ((p.state in ('expired','revoked') and coalesce(p.last_verified_at, p.created_at) < now() - interval '30 days')
        or ((p.state is null or p.state = 'pending') and p.created_at < now() - interval '30 days')
        or (p.state in ('active','in_grace_period','canceled','on_hold','paused')
          and coalesce(p.valid_until, p.created_at) < now() - interval '120 days'));
  get diagnostics purchases = row_count;

  delete from monetization_private.store_purchases p
    where p.user_id is not null and p.state is null and p.last_verified_at is null
      and p.created_at < now() - interval '30 days'
      and not exists (select 1 from monetization_private.billing_jobs j where j.purchase_id = p.id
        and j.state in ('ready','running','retry'))
      and not exists (select 1 from monetization_private.purchase_recovery_cases c where c.purchase_id = p.id
        and c.status = 'open');
  get diagnostics unconfirmed = row_count;

  with decided as (
    select c.id,
      case
        when (select count(*) from monetization_private.referral_reward_events e where e.claim_id = c.id) = 2
          then (select max(e.created_at) from monetization_private.referral_reward_events e where e.claim_id = c.id)
        when c.risk_state = 'rejected'
          then coalesce((select r.resolved_at from monetization_private.referral_review_cases r where r.claim_id = c.id),
            (select max(x.received_at) from monetization_private.referral_receipts x where x.claim_id = c.id))
        when c.referrer_id is null
          then (select max(x.received_at) from monetization_private.referral_receipts x where x.claim_id = c.id)
      end decided_at,
      k.ends_at campaign_ends_at
    from monetization_private.referral_claims c
    join monetization_private.referral_campaigns k on k.id = c.campaign_id)
  delete from monetization_private.referral_receipts x using decided d
    where x.claim_id = d.id
      and (d.decided_at < now() - interval '90 days' or d.campaign_ends_at < now() - interval '90 days');
  get diagnostics receipts = row_count;

  delete from monetization_private.legacy_migration_snapshot s
    using monetization_private.legacy_migration_runs r
    where r.migration_id = s.migration_id and r.claim_window_ends_at < now() - interval '90 days';
  get diagnostics snapshot = row_count;

  delete from monetization_private.purchase_recovery_cases
    where (status <> 'open' and decided_at < now() - interval '90 days')
      or (status = 'open' and opened_at < now() - interval '90 days');
  get diagnostics cases = row_count;

  delete from monetization_private.play_purchase_discoveries where received_at < now() - interval '30 days';
  get diagnostics discoveries = row_count;

  delete from monetization_private.billing_notification_inbox where received_at < now() - interval '30 days';
  get diagnostics inbox = row_count;
  delete from monetization_private.purchase_intents where expires_at < now() - interval '30 days';
  get diagnostics intents = row_count;
  delete from monetization_private.purchase_verify_attempts where attempted_at < now() - interval '1 day';
  get diagnostics attempts = row_count;
  delete from monetization_private.billing_jobs
    where state in ('done','dead') and updated_at < now() - interval '30 days';
  get diagnostics jobs = row_count;
  delete from monetization_private.billing_audit_events
    where user_id is null and purchase_id is null and created_at < now() - interval '30 days';
  get diagnostics billing_audit = row_count;
  delete from monetization_private.entitlement_audit
    where user_id is null and created_at < now() - interval '30 days';
  get diagnostics grant_audit = row_count;

  return jsonb_build_object('ownerless_purchases', purchases, 'unconfirmed_tokens', unconfirmed,
    'referral_receipts', receipts, 'legacy_snapshot_rows', snapshot, 'recovery_cases', cases,
    'play_discoveries', discoveries, 'notifications', inbox, 'purchase_intents', intents,
    'verify_attempts', attempts, 'billing_jobs', jobs, 'billing_audit', billing_audit, 'grant_audit', grant_audit);
end $$;

revoke all on function public.allow_purchase_verification(uuid, integer) from public, anon, authenticated;
grant execute on function public.allow_purchase_verification(uuid, integer) to service_role;

commit;
