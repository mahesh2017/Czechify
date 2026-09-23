-- PR 12: the remaining fixes from the Sep 23 review.
--
-- * Two people can no longer invite each other: both would earn the
--   inviter's units and the friend's trial from one pair of new accounts.
-- * The friend's trial no longer depends on the inviter. It was granted
--   only alongside the inviter's second reward, so an inviter who deleted
--   their account, or was not linked, took the friend's trial with them.
--   A friend whose inviter was deleted can also still send lesson results.
-- * The trial length is a campaign setting, read by both claim processing
--   and the status the app shows, instead of 14 written in two places.
-- * The app is told which products are on sale, so it offers only those.
begin;

alter table monetization_private.referral_campaigns
  add column referee_trial_days integer not null default 14 check (referee_trial_days between 1 and 90);

-- As in 20260923100000, refusing a code whose owner the caller invited.
create or replace function public.claim_referral(p_actor uuid,p_campaign text,p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c monetization_private.referral_campaigns; owner uuid; existing monetization_private.referral_claims;
  claim_id uuid; joined_at timestamptz;
begin
  select created_at into joined_at from auth.users where id=p_actor;
  if not found then return jsonb_build_object('code','authentication_required'); end if;
  insert into public.monetization_accounts(user_id) values(p_actor) on conflict do nothing;
  perform 1 from public.monetization_accounts where user_id=p_actor for update;
  select * into c from monetization_private.referral_campaigns where id=p_campaign;
  -- Replays return the original claim even if enrollment has since closed.
  select * into existing from monetization_private.referral_claims where campaign_id=p_campaign and referee_id=p_actor;
  if found then
    select owner_id into owner from monetization_private.referral_codes where code=upper(trim(p_code)) and campaign_id=p_campaign;
    if owner=existing.referrer_id then return jsonb_build_object('claim_id',existing.id,'status','claimed'); end if;
    return jsonb_build_object('code','referral_already_claimed');
  end if;
  if c.id is null or not c.enabled or now()<c.starts_at or now()>=c.claim_closes_at then
    return jsonb_build_object('code','campaign_unavailable');
  end if;
  if (select count(*) from monetization_private.referral_claim_attempts where actor_id=p_actor and attempted_at>now()-interval '1 hour')>=10 then
    return jsonb_build_object('code','rate_limited');
  end if;
  insert into monetization_private.referral_claim_attempts(actor_id) values(p_actor);
  select owner_id into owner from monetization_private.referral_codes where code=upper(trim(p_code))
    and campaign_id=p_campaign and revoked_at is null;
  if owner is null or not private.referral_linked(owner) then return jsonb_build_object('code','referral_ineligible'); end if;
  -- Two people who invite each other would each earn the inviter's units and
  -- the friend's trial from the same pair of new accounts.
  if exists(select 1 from monetization_private.referral_claims x where x.campaign_id=p_campaign
      and x.referrer_id=p_actor and x.referee_id=owner) then
    return jsonb_build_object('code','referral_ineligible');
  end if;
  if joined_at is null or joined_at<=now()-interval '7 days' or private.referral_same_identity(owner,p_actor) then
    return jsonb_build_object('code','referral_ineligible');
  end if;
  if not exists(select 1 from monetization_private.referral_manifest_lessons m where m.campaign_id=p_campaign and m.unit_id=1
    and not exists(select 1 from public.lesson_progress p where p.user_id=p_actor and p.lesson_id=m.lesson_id and p.is_completed)) then
    return jsonb_build_object('code','referral_ineligible');
  end if;
  insert into monetization_private.referral_claims(campaign_id,referrer_id,referee_id,attribution_source)
    values(p_campaign,owner,p_actor,'manual') returning id into claim_id;
  return jsonb_build_object('claim_id',claim_id,'status','claimed','required_units',jsonb_build_array(1,2));
end $$;

-- As in 20260923110000, without requiring the inviter's account: a friend
-- whose inviter was deleted still earns their trial.
create or replace function public.issue_referral_challenge(p_actor uuid, p_claim uuid, p_receipt_digest text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare nonce text; expires timestamptz := now() + interval '10 minutes';
begin
  if p_receipt_digest is null or p_receipt_digest !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('code','invalid_request');
  end if;
  if not exists (select 1 from monetization_private.referral_claims
      where id = p_claim and referee_id = p_actor) then
    return jsonb_build_object('code','referral_unavailable');
  end if;
  if (select count(*) from monetization_private.integrity_challenges
      where actor_id = p_actor and created_at > now() - interval '1 hour') >= 120 then
    return jsonb_build_object('code','rate_limited');
  end if;
  nonce := encode(extensions.gen_random_bytes(32), 'hex');
  insert into monetization_private.integrity_challenges(nonce_digest, actor_id, claim_id, receipt_digest, expires_at)
    values (encode(extensions.digest(nonce, 'sha256'), 'hex'), p_actor, p_claim, p_receipt_digest, expires);
  return jsonb_build_object('nonce', nonce, 'expires_at', expires);
end $$;

-- As in 20261002100000, without requiring the inviter's account.
create or replace function public.accept_verified_referral_receipt(p_actor uuid,p_claim uuid,p_receipt jsonb,p_digest text,p_integrity text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cl monetization_private.referral_claims; c monetization_private.referral_campaigns;
  m monetization_private.referral_manifest_lessons; old monetization_private.referral_receipts;
  attempt uuid; lesson integer; started timestamptz; completed timestamptz;
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
  if not exists(select 1 from monetization_private.referral_claims where id=p_claim and referee_id=p_actor) then
    return jsonb_build_object('code','referral_unavailable'); end if;
  perform private.lock_referral_accounts(p_claim);
  select * into cl from monetization_private.referral_claims where id=p_claim for update;
  if cl.referee_id is distinct from p_actor then return jsonb_build_object('code','referral_unavailable'); end if;
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

-- Whether this claim's friend should get their trial now. Shared by claim
-- processing and the worker's query, so the worker never picks a claim that
-- processing would leave unchanged.
create function private.referral_trial_due(p_claim uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from monetization_private.referral_claims cl
    join monetization_private.referral_campaigns c on c.id = cl.campaign_id
    where cl.id = p_claim and cl.referee_id is not null
      and cl.risk_state = 'clear' and not c.processing_paused
      and private.referral_linked(cl.referee_id)
      and (cl.referrer_id is null or not private.referral_same_identity(cl.referrer_id, cl.referee_id))
      and not exists (select 1 from public.course_access_windows w
        where w.user_id = cl.referee_id and w.kind = 'referral_trial')
      and not exists (select 1 from monetization_private.referral_manifest_lessons m
        where m.campaign_id = cl.campaign_id and m.unit_id <= 2
          and not exists (select 1 from monetization_private.referral_lesson_qualifications q
            where q.claim_id = cl.id and q.lesson_id = m.lesson_id)));
$$;

-- As in 20261001100000, with the friend's trial decided on its own: both
-- free units, a cleared claim, a linked friend and running processing. The
-- inviter's rewards follow only while the inviter's account exists.
create or replace function public.process_referral_claim(p_claim uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cl monetization_private.referral_claims; c monetization_private.referral_campaigns;
  beneficiary uuid; next_unit integer; grant_value uuid; status_value text;
begin
  select * into cl from monetization_private.referral_claims where id = p_claim;
  if not found or cl.referee_id is null then
    return jsonb_build_object('code','referral_unavailable');
  end if;
  perform private.lock_referral_accounts(p_claim);
  select * into cl from monetization_private.referral_claims where id = p_claim for update;
  if cl.referee_id is null then return jsonb_build_object('code','referral_unavailable'); end if;
  beneficiary := cl.referrer_id;
  select * into c from monetization_private.referral_campaigns where id=cl.campaign_id;
  if beneficiary is not null and exists (select 1 from public.monetization_accounts where user_id = beneficiary) then
    for ordinal_value in 1..2 loop
      -- Ordinal two requires both units, regardless of receipt arrival order.
      if exists(select 1 from monetization_private.referral_manifest_lessons m
        where m.campaign_id=cl.campaign_id and m.unit_id<=ordinal_value
        and not exists(select 1 from monetization_private.referral_lesson_qualifications q
          where q.claim_id=cl.id and q.lesson_id=m.lesson_id)) then continue; end if;
      if exists(select 1 from monetization_private.referral_reward_events where claim_id=cl.id and ordinal=ordinal_value) then continue; end if;
      status_value := case
        when cl.risk_state='rejected' then 'rejected'
        when cl.risk_state='needs_review' or private.referral_same_identity(cl.referrer_id,cl.referee_id) then 'needs_review'
        when not private.referral_linked(cl.referrer_id) or not private.referral_linked(cl.referee_id) then 'waiting_identity'
        when c.processing_paused or cl.risk_state<>'clear' then 'verification_pending'
        else 'granted' end;
      insert into monetization_private.referral_milestones(claim_id,ordinal,status) values(cl.id,ordinal_value,status_value)
        on conflict (claim_id,ordinal) do update set status=excluded.status;
      if status_value in ('waiting_identity','verification_pending','needs_review') then continue; end if;
      next_unit := null; grant_value := null;
      if status_value='granted' then
        select r.unit_id into next_unit from unnest(c.reward_unit_order) with ordinality r(unit_id,position)
          where not exists(select 1 from public.course_unit_grants g where g.user_id=beneficiary
            and g.unit_id=r.unit_id and g.revoked_at is null) order by r.position limit 1;
        if next_unit is null then status_value := 'cap_reached';
        else
          grant_value := public.set_course_unit_grant(beneficiary,next_unit,'referral',cl.id::text||':'||ordinal_value,
            cl.campaign_id,false,'qualified_referral_milestone');
        end if;
      end if;
      insert into monetization_private.referral_reward_events(claim_id,ordinal,beneficiary_id,grant_id,unit_id,outcome)
        values(cl.id,ordinal_value,beneficiary,grant_value,next_unit,status_value);
      update monetization_private.referral_milestones set status=status_value where claim_id=cl.id and ordinal=ordinal_value;
    end loop;
  end if;
  -- The friend's own reward. The inviter's cap, link or deletion does not
  -- reach it; the friend's review, rejection or missing link does.
  if private.referral_trial_due(cl.id) then
    perform private.grant_referral_trial(cl.referee_id, cl.id, c.referee_trial_days);
  end if;
  return jsonb_build_object('claim_id',cl.id,'milestones',coalesce((select jsonb_agg(jsonb_build_object(
    'ordinal',m.ordinal,'status',m.status) order by m.ordinal) from monetization_private.referral_milestones m where m.claim_id=cl.id),'[]'::jsonb),
    'referee_trial_until',(select max(w.ends_at) from public.course_access_windows w
      where w.user_id=cl.referee_id and w.kind='referral_trial'));
end $$;

-- As in 20260923110000, plus claims whose friend is owed a trial (the
-- friend linked later, or processing was paused, whoever the inviter is).
create or replace function public.referral_claims_to_process(p_limit integer)
returns setof uuid language sql stable security definer set search_path = '' as $$
  select id from (
    select c.id from monetization_private.referral_claims c
    join monetization_private.referral_milestones m on m.claim_id = c.id
    join monetization_private.referral_campaigns k on k.id = c.campaign_id
    where c.referrer_id is not null and c.referee_id is not null and (
      (m.status = 'waiting_identity' and private.referral_linked(c.referrer_id) and private.referral_linked(c.referee_id))
      or (m.status = 'verification_pending' and c.risk_state = 'clear' and not k.processing_paused))
    union
    select c.id from monetization_private.referral_claims c where private.referral_trial_due(c.id)
  ) due
  limit greatest(0, least(p_limit, 200));
$$;

-- Products on sale now, for the app's configuration.
create function public.enabled_billing_products()
returns text[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(product_id order by product_id), '{}')
  from monetization_private.billing_products where platform = 'android' and enabled;
$$;

-- As in 20261001100000, with the trial length read from the campaign.
create or replace function public.get_referral_status(p_actor uuid, p_after integer, p_limit integer)
returns jsonb language sql stable security definer set search_path = '' as $$
  with campaign as (
    select * from monetization_private.referral_campaigns where id = 'a1-referral-v1'
  ), owned as (
    select unit_id from public.course_unit_grants where user_id = p_actor and revoked_at is null
  ), friends as (
    select c.id, row_number() over (order by c.created_at, c.id) as friend
    from monetization_private.referral_claims c where c.referrer_id = p_actor
  ), page as (
    select * from friends where friend > greatest(coalesce(p_after, 0), 0)
    order by friend limit greatest(1, least(coalesce(p_limit, 20), 100))
  ), mine as (
    select c.* from monetization_private.referral_claims c, campaign
    where c.referee_id = p_actor and c.campaign_id = campaign.id
  )
  select jsonb_build_object(
    'referral_code', (select code from monetization_private.referral_codes k, campaign
      where k.owner_id = p_actor and k.campaign_id = campaign.id and k.revoked_at is null),
    'units_earned', (select count(*) from public.course_unit_grants g, campaign
      where g.user_id = p_actor and g.source = 'referral' and g.campaign_id = campaign.id and g.revoked_at is null),
    'units_available', (select cardinality(reward_unit_order) from campaign),
    'next_reward_unit', (select r.unit_id from campaign, unnest(campaign.reward_unit_order) with ordinality r(unit_id, position)
      where r.unit_id not in (select unit_id from owned) order by r.position limit 1),
    'trial_days', (select referee_trial_days from campaign),
    'own_claim', (select jsonb_build_object('claim_id', m.id,
        'lessons_completed', (select count(*) from monetization_private.referral_lesson_qualifications q where q.claim_id = m.id),
        'lessons_required', (select count(*) from monetization_private.referral_manifest_lessons l where l.campaign_id = m.campaign_id),
        'trial_until', (select max(w.ends_at) from public.course_access_windows w
          where w.user_id = p_actor and w.kind = 'referral_trial' and w.ends_at > now()),
        'milestones', private.referral_milestone_view(m.id, true))
      from mine m),
    'friends', coalesce((select jsonb_agg(jsonb_build_object('friend', p.friend,
        'milestones', private.referral_milestone_view(p.id, false)) order by p.friend) from page p), '[]'::jsonb),
    'next_cursor', (select case when (select count(*) from friends) > max(p.friend) then max(p.friend) end from page p));
$$;


revoke all on function private.referral_trial_due(uuid) from public, anon, authenticated, service_role;
revoke all on function public.enabled_billing_products() from public, anon, authenticated;
grant execute on function public.enabled_billing_products() to service_role;

commit;
