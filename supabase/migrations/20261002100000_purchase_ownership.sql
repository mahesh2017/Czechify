-- PR 10: three fixes from the Sep 23 review.
--
-- 1. A purchase the app never sent in is found from Google's notification.
--    Play refunds a subscription nobody acknowledges within three days, and
--    until now only the app could register a purchase: a payment that
--    completed later, a failed check or a closed screen left it to expire.
--    The notification carries the token; the worker asks Play which account
--    started the purchase (the obfuscated ID only this server hands out) and
--    registers it for that account.
-- 2. Google Play, not whoever sends a token first, decides whose purchase
--    is. A purchase never yet confirmed for its holder moves to the account
--    Play names, and support cases about it close.
-- 3. Lesson receipts and review decisions lock both accounts of an
--    invitation in ascending ID order, as claim processing already does.
--    They locked the inviter first, so two people who invited each other
--    could still deadlock.
begin;

-- 3. Both accounts of the claim, lowest ID first, whichever side each is on.
create function private.lock_referral_accounts(p_claim uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare locked uuid;
begin
  for locked in select a.user_id from public.monetization_accounts a
      join monetization_private.referral_claims c on a.user_id in (c.referrer_id, c.referee_id)
      where c.id = p_claim order by a.user_id loop
    perform 1 from public.monetization_accounts where user_id = locked for update;
  end loop;
end $$;

-- As in 20260923100000; only the first lock changed.
create or replace function public.accept_verified_referral_receipt(p_actor uuid,p_claim uuid,p_receipt jsonb,p_digest text,p_integrity text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cl monetization_private.referral_claims; c monetization_private.referral_campaigns;
  m monetization_private.referral_manifest_lessons; old monetization_private.referral_receipts;
  beneficiary uuid; attempt uuid; lesson integer; started timestamptz; completed timestamptz;
  coverage jsonb; ids integer[]; receipt_id uuid; evidence text; item jsonb; exercise integer; interaction text;
begin
  if p_integrity is null or p_integrity not in ('verified','needs_review') then
    return jsonb_build_object('code','integrity_rejected');
  end if;
  if p_digest is null or p_digest !~ '^[0-9a-f]{64}$' or p_receipt is null or jsonb_typeof(p_receipt)<>'object'
    or octet_length(p_receipt::text)>65536 then return jsonb_build_object('code','invalid_receipt'); end if;
  if not (p_receipt ?& array['schema_version','claim_id','campaign_id','content_revision','lesson_id','attempt_id','started_at_client','completed_at_client','initial_coverage'])
    or exists(select 1 from jsonb_object_keys(p_receipt) k where k not in
      ('schema_version','claim_id','campaign_id','content_revision','lesson_id','attempt_id','started_at_client','completed_at_client','initial_coverage'))
    or p_receipt->'schema_version' is distinct from '1'::jsonb or p_receipt->>'claim_id' is distinct from p_claim::text
    or jsonb_typeof(p_receipt->'initial_coverage') is distinct from 'array'
    or jsonb_typeof(p_receipt->'lesson_id') is distinct from 'number'
    or jsonb_typeof(p_receipt->'attempt_id') is distinct from 'string'
    or jsonb_typeof(p_receipt->'started_at_client') is distinct from 'string'
    or jsonb_typeof(p_receipt->'completed_at_client') is distinct from 'string' then return jsonb_build_object('code','invalid_receipt'); end if;
  begin
    attempt := (p_receipt->>'attempt_id')::uuid; lesson := (p_receipt->>'lesson_id')::integer;
    started := (p_receipt->>'started_at_client')::timestamptz; completed := (p_receipt->>'completed_at_client')::timestamptz;
  exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then
    return jsonb_build_object('code','invalid_receipt');
  end;
  if attempt is null or lesson is null or started is null or completed is null or not isfinite(started) or not isfinite(completed)
    or started>completed then return jsonb_build_object('code','invalid_receipt'); end if;
  select referrer_id into beneficiary from monetization_private.referral_claims where id=p_claim and referee_id=p_actor;
  if beneficiary is null then return jsonb_build_object('code','referral_unavailable'); end if;
  perform private.lock_referral_accounts(p_claim);
  select * into cl from monetization_private.referral_claims where id=p_claim for update;
  if cl.referee_id is distinct from p_actor or cl.referrer_id is null then return jsonb_build_object('code','referral_unavailable'); end if;
  select * into old from monetization_private.referral_receipts where referee_id=p_actor and attempt_id=attempt;
  if found then
    if old.claim_id<>p_claim or old.receipt_digest<>p_digest or old.payload_hash<>encode(extensions.digest(p_receipt::text,'sha256'),'hex') then
      return jsonb_build_object('code','idempotency_conflict'); end if;
    return jsonb_build_object('receipt_id',old.id,'status',old.evidence_state);
  end if;
  select * into c from monetization_private.referral_campaigns where id=cl.campaign_id;
  if p_receipt->>'campaign_id' is distinct from cl.campaign_id or p_receipt->'content_revision' is distinct from to_jsonb(c.content_revision) then
    return jsonb_build_object('code','content_update_required');
  end if;
  -- Disabling new claims does not stop existing receipts. Campaign expiry does.
  if c.ends_at is null or now()>=c.ends_at then return jsonb_build_object('code','campaign_unavailable'); end if;
  if (select count(*) from monetization_private.referral_receipts where referee_id=p_actor and received_at>now()-interval '1 hour')>=120 then
    return jsonb_build_object('code','rate_limited'); end if;
  select * into m from monetization_private.referral_manifest_lessons where campaign_id=cl.campaign_id and lesson_id=lesson;
  if not found then return jsonb_build_object('code','invalid_receipt'); end if;
  coverage := p_receipt->'initial_coverage'; ids := array[]::integer[]; evidence := 'accepted';
  if jsonb_array_length(coverage)<>cardinality(m.exercise_ids) then return jsonb_build_object('code','invalid_receipt'); end if;
  for item in select value from jsonb_array_elements(coverage) loop
    if jsonb_typeof(item) is distinct from 'object' then return jsonb_build_object('code','invalid_receipt'); end if;
    if not (item ?& array['exercise_id','interaction'])
      or (select count(*) from jsonb_object_keys(item))<>2 or jsonb_typeof(item->'exercise_id')<>'number' then
      return jsonb_build_object('code','invalid_receipt');
    end if;
    begin exercise := (item->>'exercise_id')::integer;
    exception when invalid_text_representation or numeric_value_out_of_range then return jsonb_build_object('code','invalid_receipt'); end;
    interaction := item->>'interaction';
    if exercise is null or not (exercise=any(m.exercise_ids)) or exercise=any(ids) or interaction is null then
      return jsonb_build_object('code','invalid_receipt'); end if;
    if interaction='skipped' then evidence := 'nonqualifying';
    elsif exercise=any(m.teaching_ids) then
      if interaction<>'teaching_acknowledged' then return jsonb_build_object('code','invalid_receipt'); end if;
    elsif interaction not in ('answered_correctly','answered_incorrectly') then return jsonb_build_object('code','invalid_receipt'); end if;
    ids := array_append(ids,exercise);
  end loop;
  if started<cl.created_at or completed>now()+interval '5 minutes' then
    update monetization_private.referral_claims set risk_state='needs_review' where id=cl.id and risk_state<>'rejected';
    insert into monetization_private.referral_review_cases(claim_id,reason) values(cl.id,'timing_anomaly')
      on conflict (claim_id) do update set reason=excluded.reason,resolved_at=null,resolution=null,operator_reason=null;
  elsif p_integrity='needs_review' then
    update monetization_private.referral_claims set risk_state='needs_review' where id=cl.id and risk_state<>'rejected';
    insert into monetization_private.referral_review_cases(claim_id,reason) values(cl.id,'integrity_review')
      on conflict (claim_id) do update set reason=excluded.reason,resolved_at=null,resolution=null,operator_reason=null;
  else
    update monetization_private.referral_claims set risk_state='clear' where id=cl.id and risk_state='pending';
  end if;
  insert into monetization_private.referral_receipts(claim_id,referee_id,attempt_id,lesson_id,content_revision,receipt_digest,payload_hash,
    initial_coverage,started_at_client,completed_at_client,evidence_state,integrity_state)
    values(cl.id,p_actor,attempt,lesson,c.content_revision,p_digest,encode(extensions.digest(p_receipt::text,'sha256'),'hex'),coverage,started,completed,evidence,p_integrity)
    returning id into receipt_id;
  if evidence='accepted' then
    insert into monetization_private.referral_lesson_qualifications(claim_id,lesson_id,receipt_id) values(cl.id,lesson,receipt_id)
      on conflict do nothing;
  end if;
  perform public.process_referral_claim(cl.id);
  return jsonb_build_object('receipt_id',receipt_id,'status',evidence);
end $$;

-- As in 20260923100000; only the first lock changed.
create or replace function public.resolve_referral_review(p_claim uuid,p_resolution text,p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_resolution is null or p_resolution not in ('clear','rejected') or p_reason is null or length(trim(p_reason)) not between 1 and 200 then
    raise exception 'Invalid review decision' using errcode='22023'; end if;
  perform private.lock_referral_accounts(p_claim);
  perform 1 from monetization_private.referral_claims where id=p_claim for update;
  update monetization_private.referral_review_cases set resolved_at=now(),resolution=p_resolution,operator_reason=p_reason
    where claim_id=p_claim and resolved_at is null;
  if not found then return jsonb_build_object('code','review_unavailable'); end if;
  update monetization_private.referral_claims set risk_state=p_resolution where id=p_claim;
  return public.process_referral_claim(p_claim);
end $$;

-- 2. As in 20260929100000. A token another account holds but that Play has
-- never confirmed for it is sent to Play again: Play's answer decides.
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
    if purchase.last_verified_at is null and purchase.recovered_at is null then
      perform private.queue_billing_refresh(purchase.id, 'verify');
    end if;
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

-- As in 20260929100000, with one change: a purchase not yet confirmed for
-- anyone belongs to the account Play names. The result also says whose it
-- is, so the request that ran the check never reports another account's
-- purchase as its own.
create or replace function public.apply_play_verification(p_job uuid, p_fence bigint, p_owner text, p_result jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare job monetization_private.billing_jobs; purchase monetization_private.store_purchases;
  product monetization_private.billing_products; bound text; linked uuid; rev bigint;
  new_state text := p_result->>'state'; valid timestamptz := (p_result->>'valid_until')::timestamptz;
  verified timestamptz := (p_result->>'verified_at')::timestamptz; ack_job uuid; grants boolean;
  reported text := p_result->>'obfuscated_account_id'; named uuid; previous uuid;
begin
  if not private.billing_lease_is_current(p_job, p_fence, p_owner) then
    return jsonb_build_object('status','stale_lease');
  end if;
  select * into job from monetization_private.billing_jobs where id = p_job for update;
  select * into purchase from monetization_private.store_purchases where id = job.purchase_id for update;
  select * into product from monetization_private.billing_products
    where platform = purchase.platform and product_id = purchase.product_id;
  if p_result->>'product_id' is distinct from purchase.product_id
     or p_result->>'base_plan_id' is distinct from product.base_plan_id then
    update monetization_private.billing_jobs set state = 'dead', last_error_code = 'product_mismatch',
      lease_owner = null, lease_expires_at = null, updated_at = now() where id = p_job;
    insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
      values (purchase.id, purchase.user_id, 'product_mismatch');
    return jsonb_build_object('status','product_mismatch');
  end if;
  -- The obfuscated ID is only ever handed to its own account, at checkout.
  -- Until Play has confirmed the purchase for someone, the account it names
  -- is the buyer, whoever sent the token in first.
  if reported is not null and purchase.last_verified_at is null and purchase.recovered_at is null then
    select b.user_id into named from monetization_private.billing_account_bindings b
      where b.obfuscated_account_id = reported;
    if named is not null and named is distinct from purchase.user_id then
      previous := purchase.user_id;
      update monetization_private.store_purchases set user_id = named, last_error_code = null
        where id = purchase.id;
      purchase.user_id := named;
      update monetization_private.purchase_recovery_cases set status = 'superseded', decided_at = now(),
        decided_by = 'google_play', decision_reason = 'Google Play named the account that made the purchase'
        where purchase_id = purchase.id and status = 'open';
      insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
        values (purchase.id, named, 'ownership_confirmed_by_play');
      if previous is not null then
        insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
          values (purchase.id, previous, 'ownership_moved_by_play');
      end if;
    end if;
  end if;
  if purchase.user_id is null then
    update monetization_private.billing_jobs set state = 'done', last_error_code = 'owner_deleted',
      lease_owner = null, lease_expires_at = null, updated_at = now() where id = p_job;
    return jsonb_build_object('status','account_binding_mismatch');
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
  return jsonb_build_object('status','provisioned','revision',rev,'access',grants,'ack_job_id',ack_job,
    'owner_id',purchase.user_id);
end;
$$;

-- 1. Purchases Google told us about before the app did. The token is kept
-- encrypted only until the worker has asked Play whose it is.
create table monetization_private.play_purchase_discoveries (
  token_digest text primary key check (token_digest ~ '^[0-9a-f]{64}$'),
  encrypted_token text check (encrypted_token is null or length(encrypted_token) between 1 and 32768),
  product_id text not null check (length(product_id) between 1 and 100),
  received_at timestamptz not null default now(),
  attempts integer not null default 0,
  not_before timestamptz not null default now(),
  resolved_at timestamptz,
  -- registered: now a purchase of the account Play named. no_owner: Play
  -- names no Czechify account (bought elsewhere, or the account is gone).
  -- failed: Play would not answer.
  outcome text check (outcome in ('registered','no_owner','failed')),
  check ((resolved_at is null) = (outcome is null)),
  check (resolved_at is not null or encrypted_token is not null)
);
create index play_purchase_discoveries_due on monetization_private.play_purchase_discoveries(not_before)
  where resolved_at is null;
alter table monetization_private.play_purchase_discoveries enable row level security;
revoke all on monetization_private.play_purchase_discoveries from public, anon, authenticated, service_role;

-- From the notification endpoint, for a subscription token. Returns known
-- (already a purchase), ignored (not a product sold here), queued or
-- duplicate.
create function public.queue_play_discovery(p_token_digest text, p_encrypted_token text, p_product text)
returns text language plpgsql security definer set search_path = '' as $$
begin
  if p_token_digest is null or p_token_digest !~ '^[0-9a-f]{64}$' or p_encrypted_token is null
     or length(p_encrypted_token) not between 1 and 32768 or p_product is null then
    raise exception 'A token digest, encrypted token and product are required' using errcode = '22023';
  end if;
  if exists (select 1 from monetization_private.store_purchases where token_digest = p_token_digest) then
    return 'known';
  end if;
  if not exists (select 1 from monetization_private.billing_products
      where platform = 'android' and product_id = p_product) then
    return 'ignored';
  end if;
  insert into monetization_private.play_purchase_discoveries(token_digest, encrypted_token, product_id)
    values (p_token_digest, p_encrypted_token, p_product)
  on conflict (token_digest) do nothing;
  return case when found then 'queued' else 'duplicate' end;
end $$;

create function public.due_play_discoveries(p_limit integer)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('token_digest', d.token_digest,
      'encrypted_token', d.encrypted_token, 'product_id', d.product_id, 'attempts', d.attempts)
      order by d.received_at), '[]'::jsonb)
  from (select * from monetization_private.play_purchase_discoveries
    where resolved_at is null and not_before <= now()
    order by received_at limit greatest(0, least(p_limit, 100))) d;
$$;

-- Registers the purchase for the account whose obfuscated ID Play reported,
-- and returns the registration (with its verification job). The token is
-- dropped from this table either way.
create function public.resolve_play_discovery(p_token_digest text, p_obfuscated_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare d monetization_private.play_purchase_discoveries; owner uuid; result jsonb;
begin
  select * into d from monetization_private.play_purchase_discoveries
    where token_digest = p_token_digest for update;
  if not found or d.resolved_at is not null then
    return jsonb_build_object('status','already_resolved');
  end if;
  select user_id into owner from monetization_private.billing_account_bindings
    where obfuscated_account_id = p_obfuscated_id;
  if owner is null then
    update monetization_private.play_purchase_discoveries set resolved_at = now(), outcome = 'no_owner',
      encrypted_token = null where token_digest = p_token_digest;
    return jsonb_build_object('status','no_owner');
  end if;
  result := public.register_purchase_verification(owner, d.token_digest, d.encrypted_token, d.product_id, null);
  update monetization_private.play_purchase_discoveries set resolved_at = now(), outcome = 'registered',
    encrypted_token = null where token_digest = p_token_digest;
  insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
    values ((result->>'purchase_id')::uuid, owner, 'discovered_from_notification');
  return result;
end $$;

-- Backs a discovery off, or gives up on it.
create function public.fail_play_discovery(p_token_digest text, p_retry_seconds integer, p_final boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update monetization_private.play_purchase_discoveries set attempts = attempts + 1,
    not_before = now() + make_interval(secs => greatest(0, least(coalesce(p_retry_seconds, 60), 3600))),
    resolved_at = case when p_final then now() end,
    outcome = case when p_final then 'failed' end,
    encrypted_token = case when p_final then null else encrypted_token end
    where token_digest = p_token_digest and resolved_at is null;
  return found;
end $$;

-- As in 20260929100000, plus discoveries: 30 days after they arrived.
create or replace function public.cleanup_privacy_records()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare purchases integer; receipts integer; snapshot integer; inbox integer; intents integer;
  jobs integer; billing_audit integer; grant_audit integer; cases integer; discoveries integer;
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

  delete from monetization_private.play_purchase_discoveries where received_at < now() - interval '30 days';
  get diagnostics discoveries = row_count;

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
    'legacy_snapshot_rows', snapshot, 'recovery_cases', cases, 'play_discoveries', discoveries,
    'notifications', inbox, 'purchase_intents', intents, 'billing_jobs', jobs,
    'billing_audit', billing_audit, 'grant_audit', grant_audit);
end $$;

revoke all on function private.lock_referral_accounts(uuid) from public, anon, authenticated, service_role;
revoke all on function public.queue_play_discovery(text, text, text), public.due_play_discoveries(integer),
  public.resolve_play_discovery(text, text), public.fail_play_discovery(text, integer, boolean)
  from public, anon, authenticated;
grant execute on function public.queue_play_discovery(text, text, text), public.due_play_discoveries(integer),
  public.resolve_play_discovery(text, text), public.fail_play_discovery(text, integer, boolean)
  to service_role;

commit;
