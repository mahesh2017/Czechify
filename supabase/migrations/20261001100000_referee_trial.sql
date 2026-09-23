-- The invited friend's side of an invitation: two weeks of Czechify Core,
-- free, once they finish the two free units.
--
-- Until now only the person who invited them was rewarded, so a friend had
-- no reason of their own to enter a code. The trial costs no cash, arrives
-- when they have just run out of free course, and is worth nothing to
-- someone farming accounts — unlike a permanent unit, which would double
-- what self-dealing pays.
begin;

alter table public.course_access_windows drop constraint course_access_windows_kind_check;
alter table public.course_access_windows
  add constraint course_access_windows_kind_check check (kind in ('migration_grace','referral_trial'));

-- One trial per account, ever: a second invitation, a new code or a repeat
-- of the same claim never extends it. Returns the end of the trial, or null
-- when the account already had one.
create function private.grant_referral_trial(p_user uuid, p_claim uuid, p_days integer)
returns timestamptz language plpgsql security definer set search_path = '' as $$
declare ends timestamptz; rev bigint;
begin
  if p_user is null or p_days is null or p_days not between 1 and 90 then
    raise exception 'A learner and a trial length are required' using errcode = '22023';
  end if;
  if exists (select 1 from public.course_access_windows w
      where w.user_id = p_user and w.kind = 'referral_trial') then
    return null;
  end if;
  ends := now() + make_interval(days => p_days);
  insert into public.monetization_accounts(user_id) values (p_user) on conflict do nothing;
  insert into public.course_access_windows(user_id, kind, starts_at, ends_at, source_key)
    values (p_user, 'referral_trial', now(), ends, p_claim::text)
  on conflict (user_id, kind, source_key) do nothing;
  if not found then return null; end if;
  update public.monetization_accounts set revision = revision + 1, updated_at = now()
    where user_id = p_user returning revision into rev;
  insert into monetization_private.entitlement_audit(user_id, action, source_key, reason)
    values (p_user, 'referral_trial', p_claim::text, 'invited friend finished the free units');
  insert into monetization_private.monetization_outbox(user_id, revision, event_type)
    values (p_user, rev, 'course_access_changed');
  return ends;
end $$;

-- As in 20260923100000, with two changes:
--
-- * both accounts are locked, in a fixed order. Two invitations can now put
--   the same pair of accounts on opposite sides (A invited B, B invited A),
--   and locking each claim's own beneficiary first would deadlock.
-- * when the second milestone is decided, the friend gets their trial. It
--   does not depend on the inviter still having a unit left to earn.
create or replace function public.process_referral_claim(p_claim uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cl monetization_private.referral_claims; c monetization_private.referral_campaigns;
  beneficiary uuid; next_unit integer; grant_value uuid; status_value text; locked uuid;
begin
  select * into cl from monetization_private.referral_claims where id = p_claim;
  if not found or cl.referrer_id is null or cl.referee_id is null then
    return jsonb_build_object('code','referral_unavailable');
  end if;
  beneficiary := cl.referrer_id;
  -- Ascending account ID, always, whichever side of this claim they are on.
  for locked in select user_id from public.monetization_accounts
      where user_id in (cl.referrer_id, cl.referee_id) order by user_id loop
    perform 1 from public.monetization_accounts where user_id = locked for update;
  end loop;
  if not exists (select 1 from public.monetization_accounts where user_id = beneficiary) then
    return jsonb_build_object('code','referral_unavailable');
  end if;
  select * into cl from monetization_private.referral_claims where id = p_claim for update;
  if cl.referrer_id is null or cl.referee_id is null then return jsonb_build_object('code','referral_unavailable'); end if;
  select * into c from monetization_private.referral_campaigns where id=cl.campaign_id;
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
    -- The friend's own reward: the inviter's cap does not reach them.
    if ordinal_value = 2 and status_value in ('granted','cap_reached') then
      perform private.grant_referral_trial(cl.referee_id, cl.id, 14);
    end if;
  end loop;
  return jsonb_build_object('claim_id',cl.id,'milestones',coalesce((select jsonb_agg(jsonb_build_object(
    'ordinal',m.ordinal,'status',m.status) order by m.ordinal) from monetization_private.referral_milestones m where m.claim_id=cl.id),'[]'::jsonb),
    'referee_trial_until',(select max(w.ends_at) from public.course_access_windows w
      where w.user_id=cl.referee_id and w.kind='referral_trial'));
end $$;

-- As in 20260921110000, with the two kinds of free access reported apart:
-- the existing-user grace, and the invited friend's trial. Course access
-- follows either one.
create or replace function public.get_monetization_snapshot(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'schema_version',1, 'user_id', p_user, 'revision', coalesce(a.revision,0),
    'issued_at', now(), 'verified_at', now(), 'policy_version','course-access-v1',
    'campaign_id','a1-referral-v1', 'manifest_revision',25,
    'features', (select jsonb_object_agg(f.feature, jsonb_build_object(
      'state', case when b.valid_until is null then 'inactive' else 'active' end,
      'valid_until',b.valid_until,'offline_valid_until',b.offline_valid_until))
      from (values ('core'),('ai_chat')) f(feature)
      left join lateral (select max(e.valid_until) valid_until,
        max(least(e.valid_until, e.verified_at + interval '7 days')) offline_valid_until
        from monetization_private.feature_entitlements e where e.user_id = p_user
        and e.feature = f.feature and e.state in ('active','in_grace_period','canceled')
        and e.valid_until > now()) b on true),
    'permanent_unit_grants', (select coalesce(jsonb_agg(jsonb_build_object(
      'grant_id',g.id,'unit_id',g.unit_id,'source',g.source) order by g.unit_id,g.id),'[]'::jsonb)
      from public.course_unit_grants g where g.user_id = p_user and g.revoked_at is null),
    'migration_grace_until',(select max(w.ends_at) from public.course_access_windows w
      where w.user_id = p_user and w.kind = 'migration_grace' and w.starts_at <= now() and w.ends_at > now()),
    'referral_trial_until',(select max(w.ends_at) from public.course_access_windows w
      where w.user_id = p_user and w.kind = 'referral_trial' and w.starts_at <= now() and w.ends_at > now()),
    'staff_course_until',case when c.unlock_all and c.expires_at > now() then c.expires_at else null end,
    'staff_course_unlimited',coalesce(c.unlock_all and c.expires_at is null,false))
  from auth.users u left join public.monetization_accounts a on a.user_id = u.id
    left join public.curriculum_entitlements c on c.user_id = u.id where u.id = p_user;
$$;

-- As in 20260923110000, plus the trial on the account's own claim, so the
-- invite screen can say when it ends.
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
    'trial_days', 14,
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

revoke all on function private.grant_referral_trial(uuid, uuid, integer)
  from public, anon, authenticated, service_role;

commit;
