-- Phase 7c: support recovery of purchases, and the operations report.
--
-- A purchase never follows a token to another account on its own. When a
-- linked account restores a Play purchase that belongs to someone else (a
-- deleted account, another Czechify account, or a Play account binding that
-- is not this account's), a recovery case opens. Only a named operator with
-- a reason can move the purchase, and Google Play is then asked again: it
-- stays the authority on whether the purchase gives access.
begin;

alter table monetization_private.store_purchases
  -- Set by a support recovery: the next Play verification records the
  -- account binding Play reports, and later ones must match it.
  add column recovered_at timestamptz,
  add column accepted_obfuscated_id text;

create table monetization_private.purchase_recovery_cases (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references monetization_private.store_purchases(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  -- ownerless: the owner deleted their account. other_account: another
  -- Czechify account owns it. play_binding: Play reports another account's
  -- binding for a purchase this account registered.
  reason text not null check (reason in ('ownerless','other_account','play_binding')),
  previous_owner_id uuid references auth.users(id) on delete set null,
  status text not null default 'open' check (status in ('open','approved','rejected','superseded')),
  opened_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by text check (decided_by is null or length(decided_by) between 1 and 200),
  decision_reason text check (decision_reason is null or length(decision_reason) between 1 and 500),
  check ((status = 'open') = (decided_at is null))
);
create unique index purchase_recovery_open_once on monetization_private.purchase_recovery_cases(purchase_id, requester_id)
  where status = 'open';
create index purchase_recovery_open on monetization_private.purchase_recovery_cases(opened_at) where status = 'open';
alter table monetization_private.purchase_recovery_cases enable row level security;
revoke all on monetization_private.purchase_recovery_cases from public, anon, authenticated, service_role;

-- Opens (or returns the open) case for this purchase and requester.
create function private.open_purchase_recovery(p_purchase uuid, p_requester uuid, p_reason text,
  p_previous_owner uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare case_id uuid;
begin
  if p_requester is null then return null; end if;
  select id into case_id from monetization_private.purchase_recovery_cases
    where purchase_id = p_purchase and requester_id = p_requester and status = 'open';
  if case_id is not null then return case_id; end if;
  insert into monetization_private.purchase_recovery_cases(purchase_id, requester_id, reason, previous_owner_id)
    values (p_purchase, p_requester, p_reason, p_previous_owner)
    on conflict do nothing returning id into case_id;
  if case_id is null then
    select id into case_id from monetization_private.purchase_recovery_cases
      where purchase_id = p_purchase and requester_id = p_requester and status = 'open';
  end if;
  insert into monetization_private.billing_audit_events(purchase_id, user_id, event, detail)
    values (p_purchase, p_requester, 'recovery_case_opened', p_reason);
  return case_id;
end $$;

-- As in 20260922100000, and a foreign token now opens a recovery case for
-- the caller instead of ending there.
create or replace function public.register_purchase_verification(p_user uuid, p_token_digest text,
  p_encrypted_token text, p_product text, p_intent uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare purchase monetization_private.store_purchases; product monetization_private.billing_products;
  job_id uuid; case_id uuid;
begin
  select * into product from monetization_private.billing_products
    where platform = 'android' and product_id = p_product;
  if not found then return jsonb_build_object('status','product_unavailable'); end if;
  if p_intent is not null then
    update monetization_private.purchase_intents set consumed_at = coalesce(consumed_at, now())
      where id = p_intent and user_id = p_user and product_id = p_product;
    if not found then return jsonb_build_object('status','product_unavailable'); end if;
  end if;
  insert into monetization_private.store_purchases(platform, token_digest, encrypted_token, user_id,
    product_id, base_plan_id, lineage_id)
    values ('android', p_token_digest, p_encrypted_token, p_user, p_product, product.base_plan_id,
      gen_random_uuid())
    on conflict (token_digest) do nothing;
  select * into purchase from monetization_private.store_purchases
    where token_digest = p_token_digest for update;
  if purchase.product_id <> p_product then
    insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
      values (purchase.id, p_user, 'foreign_token_submitted');
    return jsonb_build_object('status','account_binding_mismatch');
  end if;
  if purchase.user_id is distinct from p_user then
    insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
      values (purchase.id, p_user, 'foreign_token_submitted');
    case_id := private.open_purchase_recovery(purchase.id, p_user,
      case when purchase.user_id is null then 'ownerless' else 'other_account' end, purchase.user_id);
    return jsonb_build_object('status','account_binding_mismatch','recovery_case_id',case_id);
  end if;
  insert into monetization_private.billing_jobs(purchase_id, operation)
    values (purchase.id, 'verify') on conflict do nothing;
  select id into job_id from monetization_private.billing_jobs
    where purchase_id = purchase.id and operation = 'verify' and state in ('ready','running','retry');
  return jsonb_build_object('status','queued','purchase_id',purchase.id,'job_id',job_id);
end;
$$;

-- As in 20260922100000, with two changes to the account binding check:
-- after a support recovery the first verification records the binding Play
-- reports, and later ones accept that binding; a mismatch opens a case.
create or replace function public.apply_play_verification(p_job uuid, p_fence bigint, p_owner text, p_result jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare job monetization_private.billing_jobs; purchase monetization_private.store_purchases;
  product monetization_private.billing_products; bound text; linked uuid; rev bigint;
  new_state text := p_result->>'state'; valid timestamptz := (p_result->>'valid_until')::timestamptz;
  verified timestamptz := (p_result->>'verified_at')::timestamptz; ack_job uuid; grants boolean;
  reported text := p_result->>'obfuscated_account_id';
begin
  if not private.billing_lease_is_current(p_job, p_fence, p_owner) then
    return jsonb_build_object('status','stale_lease');
  end if;
  select * into job from monetization_private.billing_jobs where id = p_job for update;
  select * into purchase from monetization_private.store_purchases where id = job.purchase_id for update;
  select * into product from monetization_private.billing_products
    where platform = purchase.platform and product_id = purchase.product_id;
  if purchase.user_id is null then
    update monetization_private.billing_jobs set state = 'done', last_error_code = 'owner_deleted',
      lease_owner = null, lease_expires_at = null, updated_at = now() where id = p_job;
    return jsonb_build_object('status','account_binding_mismatch');
  end if;
  if p_result->>'product_id' is distinct from purchase.product_id
     or p_result->>'base_plan_id' is distinct from product.base_plan_id then
    update monetization_private.billing_jobs set state = 'dead', last_error_code = 'product_mismatch',
      lease_owner = null, lease_expires_at = null, updated_at = now() where id = p_job;
    insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
      values (purchase.id, purchase.user_id, 'product_mismatch');
    return jsonb_build_object('status','product_mismatch');
  end if;
  select obfuscated_account_id into bound from monetization_private.billing_account_bindings
    where user_id = purchase.user_id;
  if purchase.recovered_at is not null and purchase.accepted_obfuscated_id is null and reported is not null then
    -- The operator moved this purchase; record the binding Play reports.
    update monetization_private.store_purchases set accepted_obfuscated_id = reported where id = purchase.id;
    purchase.accepted_obfuscated_id := reported;
  end if;
  if reported is null or (reported is distinct from bound and reported is distinct from purchase.accepted_obfuscated_id) then
    update monetization_private.store_purchases set last_error_code = 'account_binding_mismatch'
      where id = purchase.id;
    update monetization_private.billing_jobs set state = 'done', last_error_code = 'account_binding_mismatch',
      lease_owner = null, lease_expires_at = null, updated_at = now() where id = p_job;
    insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
      values (purchase.id, purchase.user_id, 'account_binding_mismatch');
    return jsonb_build_object('status','account_binding_mismatch',
      'recovery_case_id', private.open_purchase_recovery(purchase.id, purchase.user_id, 'play_binding', null));
  end if;
  if p_result->>'linked_token_digest' is not null then
    select lineage_id into linked from monetization_private.store_purchases
      where token_digest = p_result->>'linked_token_digest' and user_id = purchase.user_id;
  end if;
  update monetization_private.store_purchases set state = new_state, raw_state = p_result->>'raw_state',
    valid_until = valid, auto_renewing = (p_result->>'auto_renewing')::boolean,
    linked_token_digest = p_result->>'linked_token_digest', lineage_id = coalesce(linked, lineage_id),
    acknowledgement_state = case when (p_result->>'acknowledged')::boolean then 'acknowledged'
      else acknowledgement_state end,
    last_verified_at = verified, response_fingerprint = p_result->>'response_fingerprint',
    last_error_code = null
    where id = purchase.id;
  rev := public.apply_verified_feature(purchase.user_id, product.feature, 'play:' || purchase.id::text,
    new_state, valid, verified);
  grants := new_state in ('active','in_grace_period','canceled') and valid > now();
  -- Acknowledge only after provisioning commits in this same transaction.
  if grants and not (p_result->>'acknowledged')::boolean then
    insert into monetization_private.billing_jobs(purchase_id, operation)
      values (purchase.id, 'acknowledge') on conflict do nothing;
    select id into ack_job from monetization_private.billing_jobs
      where purchase_id = purchase.id and operation = 'acknowledge' and state in ('ready','running','retry');
  end if;
  update monetization_private.billing_jobs set state = 'done', last_error_code = null,
    lease_owner = null, lease_expires_at = null, updated_at = now() where id = p_job;
  insert into monetization_private.billing_audit_events(purchase_id, user_id, event, detail)
    values (purchase.id, purchase.user_id, 'verified', new_state);
  return jsonb_build_object('status','provisioned','revision',rev,'access',grants,'ack_job_id',ack_job);
end;
$$;

-- Support's decision. Approving moves the purchase to the requester, ends
-- the previous owner's access from it, and asks Google Play again: access
-- follows only if Play reports the purchase as active.
create function public.resolve_purchase_recovery(p_case uuid, p_approve boolean, p_operator text,
  p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare rc monetization_private.purchase_recovery_cases; purchase monetization_private.store_purchases;
  product monetization_private.billing_products; job_id uuid;
begin
  if p_approve is null or p_operator is null or length(trim(p_operator)) not between 1 and 200
     or p_reason is null or length(trim(p_reason)) not between 1 and 500 then
    raise exception 'A decision, an operator and a reason are required' using errcode = '22023';
  end if;
  select * into rc from monetization_private.purchase_recovery_cases where id = p_case for update;
  if not found or rc.status <> 'open' then
    raise exception 'No open recovery case' using errcode = '22023';
  end if;
  select * into purchase from monetization_private.store_purchases where id = rc.purchase_id for update;
  if not p_approve then
    update monetization_private.purchase_recovery_cases set status = 'rejected', decided_at = now(),
      decided_by = p_operator, decision_reason = p_reason where id = p_case;
    insert into monetization_private.billing_audit_events(purchase_id, user_id, event, detail)
      values (purchase.id, rc.requester_id, 'recovery_rejected', p_operator);
    return jsonb_build_object('status','rejected');
  end if;

  select * into product from monetization_private.billing_products
    where platform = purchase.platform and product_id = purchase.product_id;
  -- The previous owner keeps nothing from this purchase.
  if purchase.user_id is not null and purchase.user_id <> rc.requester_id then
    perform public.apply_verified_feature(purchase.user_id, product.feature, 'play:' || purchase.id::text,
      'revoked', now(), clock_timestamp());
    insert into monetization_private.entitlement_audit(user_id, action, source_key, reason)
      values (purchase.user_id, 'purchase_moved_away', 'play:' || purchase.id::text, p_operator || ': ' || p_reason);
  end if;
  update monetization_private.store_purchases set user_id = rc.requester_id, recovered_at = clock_timestamp(),
    accepted_obfuscated_id = null, last_error_code = null
    where id = purchase.id;
  insert into public.monetization_accounts(user_id) values (rc.requester_id) on conflict do nothing;
  insert into monetization_private.entitlement_audit(user_id, action, source_key, reason)
    values (rc.requester_id, 'purchase_recovered', 'play:' || purchase.id::text, p_operator || ': ' || p_reason);
  update monetization_private.purchase_recovery_cases set status = 'approved', decided_at = now(),
    decided_by = p_operator, decision_reason = p_reason where id = p_case;
  update monetization_private.purchase_recovery_cases set status = 'superseded', decided_at = now(),
    decided_by = p_operator, decision_reason = 'another case was approved'
    where purchase_id = purchase.id and status = 'open';
  insert into monetization_private.billing_audit_events(purchase_id, user_id, event, detail)
    values (purchase.id, rc.requester_id, 'ownership_recovered', p_operator);
  job_id := private.queue_billing_refresh(purchase.id, 'verify');
  return jsonb_build_object('status','approved','purchase_id',purchase.id,'verify_job_id',job_id);
end $$;

-- What support needs to decide a case, without tokens or learning data.
create function public.support_recovery_case(p_case uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'case_id', rc.id, 'status', rc.status, 'reason', rc.reason, 'opened_at', rc.opened_at,
    'decided_at', rc.decided_at, 'decided_by', rc.decided_by, 'decision_reason', rc.decision_reason,
    'requester', jsonb_build_object('user_id', rc.requester_id, 'created_at', r.created_at,
      'linked', not coalesce(r.is_anonymous, true), 'email', r.email),
    'current_owner', case when p.user_id is null then null else jsonb_build_object('user_id', p.user_id,
      'created_at', o.created_at, 'linked', not coalesce(o.is_anonymous, true), 'email', o.email,
      'last_sign_in_at', o.last_sign_in_at) end,
    'purchase', jsonb_build_object('purchase_id', p.id, 'product_id', p.product_id, 'base_plan_id', p.base_plan_id,
      'state', p.state, 'valid_until', p.valid_until, 'auto_renewing', p.auto_renewing,
      'registered_at', p.created_at, 'last_verified_at', p.last_verified_at, 'recovered_at', p.recovered_at),
    'other_open_cases', (select count(*) from monetization_private.purchase_recovery_cases x
      where x.purchase_id = p.id and x.status = 'open' and x.id <> rc.id))
  from monetization_private.purchase_recovery_cases rc
  join monetization_private.store_purchases p on p.id = rc.purchase_id
  join auth.users r on r.id = rc.requester_id
  left join auth.users o on o.id = p.user_id
  where rc.id = p_case;
$$;

-- One account's commercial state for support: access, purchases, invitations,
-- the existing-user migration and open cases. No tokens or learning content.
create function public.support_account_summary(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'user_id', u.id, 'created_at', u.created_at, 'linked', not coalesce(u.is_anonymous, true),
    'snapshot', public.get_monetization_snapshot(u.id),
    'purchases', (select coalesce(jsonb_agg(jsonb_build_object('purchase_id', p.id, 'product_id', p.product_id,
        'state', p.state, 'valid_until', p.valid_until, 'auto_renewing', p.auto_renewing,
        'acknowledgement', p.acknowledgement_state, 'last_verified_at', p.last_verified_at,
        'last_error_code', p.last_error_code, 'recovered_at', p.recovered_at) order by p.created_at), '[]'::jsonb)
      from monetization_private.store_purchases p where p.user_id = u.id),
    'recovery_cases', (select coalesce(jsonb_agg(jsonb_build_object('case_id', rc.id, 'status', rc.status,
        'reason', rc.reason, 'opened_at', rc.opened_at) order by rc.opened_at), '[]'::jsonb)
      from monetization_private.purchase_recovery_cases rc where rc.requester_id = u.id),
    'referral', public.get_referral_status(u.id, 0, 100),
    'legacy', public.legacy_claim_status(u.id),
    'recent_billing_events', (select coalesce(jsonb_agg(jsonb_build_object('event', e.event, 'detail', e.detail,
        'at', e.created_at) order by e.created_at desc), '[]'::jsonb)
      from (select * from monetization_private.billing_audit_events e where e.user_id = u.id
        order by e.created_at desc limit 20) e))
  from auth.users u where u.id = p_user;
$$;

-- The numbers operators watch, and which of the release plan's thresholds
-- are crossed right now. The worker logs each alert.
create function public.monetization_operations_report()
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
      ('billing_jobs_dead', 'investigate', m.dead_billing_jobs > 0),
      ('referral_queue_slow', 'investigate', m.referral_queue_age_seconds > 900),
      ('ai_ceiling_tripped', 'investigate', m.ai_ceiling_trips_7d > 1),
      ('support_queue_waiting', 'support', greatest(m.oldest_referral_review_seconds, m.oldest_legacy_claim_seconds,
        m.oldest_recovery_case_seconds) > 172800)) t(a, level, crossed)
    where crossed))
  from m;
$$;

-- As in 20260928110000, plus recovery cases: decided ones go 90 days after
-- the decision, and open ones expire after 90 days (the learner can restore
-- again to reopen).
create or replace function public.cleanup_privacy_records()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare purchases integer; receipts integer; snapshot integer; inbox integer; intents integer;
  jobs integer; billing_audit integer; grant_audit integer; cases integer;
begin
  delete from monetization_private.store_purchases p
    where p.user_id is null
      and ((p.state in ('expired','revoked') and coalesce(p.last_verified_at, p.created_at) < now() - interval '30 days')
        or ((p.state is null or p.state = 'pending') and p.created_at < now() - interval '30 days'));
  get diagnostics purchases = row_count;

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

  delete from monetization_private.billing_notification_inbox where received_at < now() - interval '30 days';
  get diagnostics inbox = row_count;
  delete from monetization_private.purchase_intents where expires_at < now() - interval '30 days';
  get diagnostics intents = row_count;
  delete from monetization_private.billing_jobs
    where state in ('done','dead') and updated_at < now() - interval '30 days';
  get diagnostics jobs = row_count;
  delete from monetization_private.billing_audit_events
    where user_id is null and purchase_id is null and created_at < now() - interval '30 days';
  get diagnostics billing_audit = row_count;
  delete from monetization_private.entitlement_audit
    where user_id is null and created_at < now() - interval '30 days';
  get diagnostics grant_audit = row_count;

  return jsonb_build_object('ownerless_purchases', purchases, 'referral_receipts', receipts,
    'legacy_snapshot_rows', snapshot, 'recovery_cases', cases, 'notifications', inbox,
    'purchase_intents', intents, 'billing_jobs', jobs, 'billing_audit', billing_audit, 'grant_audit', grant_audit);
end $$;

revoke all on function private.open_purchase_recovery(uuid, uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.resolve_purchase_recovery(uuid, boolean, text, text),
  public.support_recovery_case(uuid), public.support_account_summary(uuid),
  public.monetization_operations_report() from public, anon, authenticated;
grant execute on function public.resolve_purchase_recovery(uuid, boolean, text, text),
  public.support_recovery_case(uuid), public.support_account_summary(uuid),
  public.monetization_operations_report() to service_role;

commit;
