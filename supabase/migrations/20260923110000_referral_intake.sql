-- Referral intake around the 4a foundation: single-use Integrity challenges,
-- atomic challenge consumption with receipt persistence, replay lookup,
-- privacy-safe status, worker selection and retention.
begin;

create table monetization_private.integrity_challenges (
  nonce_digest text primary key check (nonce_digest ~ '^[0-9a-f]{64}$'),
  actor_id uuid not null references auth.users(id) on delete cascade,
  claim_id uuid not null references monetization_private.referral_claims(id) on delete cascade,
  receipt_digest text not null check (receipt_digest ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  receipt_id uuid,
  check (expires_at > created_at)
);
create index integrity_challenges_rate on monetization_private.integrity_challenges(actor_id, created_at);
create index integrity_challenges_expiry on monetization_private.integrity_challenges(expires_at);
alter table monetization_private.integrity_challenges enable row level security;
revoke all on monetization_private.integrity_challenges from public, anon, authenticated, service_role;

-- A nonce for one claim and one semantic receipt, valid ten minutes. Only its
-- digest is stored. The caller must be the claim's referee.
create function public.issue_referral_challenge(p_actor uuid, p_claim uuid, p_receipt_digest text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare nonce text; expires timestamptz := now() + interval '10 minutes';
begin
  if p_receipt_digest is null or p_receipt_digest !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('code','invalid_request');
  end if;
  if not exists (select 1 from monetization_private.referral_claims
      where id = p_claim and referee_id = p_actor and referrer_id is not null) then
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

-- A committed receipt for this attempt, returned before any challenge is
-- required again. Null when none exists.
create function public.find_referral_receipt(p_actor uuid, p_claim uuid, p_attempt uuid, p_digest text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when r.claim_id = p_claim and r.receipt_digest = p_digest
      then jsonb_build_object('receipt_id', r.id, 'status', r.evidence_state)
      else jsonb_build_object('code', 'idempotency_conflict') end
  from monetization_private.referral_receipts r
  where r.referee_id = p_actor and r.attempt_id = p_attempt;
$$;

-- The only entry to accept_verified_referral_receipt from the API. The
-- challenge is checked and consumed in the same transaction that stores the
-- receipt, so a nonce can never back two submissions. p_integrity comes from
-- server-side token verification, never from the client.
create function public.submit_referral_receipt(p_actor uuid, p_claim uuid, p_nonce text,
  p_receipt jsonb, p_digest text, p_integrity text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare challenge monetization_private.integrity_challenges; result jsonb;
begin
  if p_nonce is null or p_nonce !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('code','challenge_invalid');
  end if;
  select * into challenge from monetization_private.integrity_challenges
    where nonce_digest = encode(extensions.digest(p_nonce, 'sha256'), 'hex') for update;
  if not found or challenge.actor_id <> p_actor or challenge.claim_id <> p_claim
     or challenge.receipt_digest is distinct from p_digest or challenge.consumed_at is not null
     or challenge.expires_at <= now() then
    return jsonb_build_object('code','challenge_invalid');
  end if;
  result := public.accept_verified_referral_receipt(p_actor, p_claim, p_receipt, p_digest, p_integrity);
  -- Single use whatever the outcome; a retry needs a fresh challenge.
  update monetization_private.integrity_challenges set consumed_at = now(),
    receipt_id = (result->>'receipt_id')::uuid where nonce_digest = challenge.nonce_digest;
  return result;
end $$;

-- Milestone statuses as the API names them. A friend's review or rejection
-- reads as pending to the referrer.
create function private.referral_milestone_view(p_claim uuid, p_own boolean)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_agg(jsonb_build_object('ordinal', o, 'status', case
      when s.status is null then 'waiting_for_learning'
      when s.status = 'waiting_identity' then 'waiting_for_account_link'
      when s.status = 'granted' then 'reward_granted'
      when s.status = 'cap_reached' then 'cap_reached'
      when s.status in ('needs_review','rejected') and p_own then s.status
      else 'verification_pending' end) order by o)
  from generate_series(1, 2) o
  left join monetization_private.referral_milestones s on s.claim_id = p_claim and s.ordinal = o;
$$;

-- What the account may see: its own code and earned units, its own claim as
-- an invitee (including review, so it can contact support), and numbered
-- friends. A friend's review or rejection is shown as pending: another
-- learner's risk signals are never exposed.
create function public.get_referral_status(p_actor uuid, p_after integer, p_limit integer)
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
    'own_claim', (select jsonb_build_object('claim_id', m.id,
        'lessons_completed', (select count(*) from monetization_private.referral_lesson_qualifications q where q.claim_id = m.id),
        'lessons_required', (select count(*) from monetization_private.referral_manifest_lessons l where l.campaign_id = m.campaign_id),
        'milestones', private.referral_milestone_view(m.id, true))
      from mine m),
    'friends', coalesce((select jsonb_agg(jsonb_build_object('friend', p.friend,
        'milestones', private.referral_milestone_view(p.id, false)) order by p.friend) from page p), '[]'::jsonb),
    'next_cursor', (select case when (select count(*) from friends) > max(p.friend) then max(p.friend) end from page p));
$$;

-- Claims the worker can move forward now: identity-held ones whose accounts
-- are both linked, and cleared ones held only by paused processing.
create function public.referral_claims_to_process(p_limit integer)
returns setof uuid language sql stable security definer set search_path = '' as $$
  select distinct c.id from monetization_private.referral_claims c
  join monetization_private.referral_milestones m on m.claim_id = c.id
  join monetization_private.referral_campaigns k on k.id = c.campaign_id
  where c.referrer_id is not null and c.referee_id is not null and (
    (m.status = 'waiting_identity' and private.referral_linked(c.referrer_id) and private.referral_linked(c.referee_id))
    or (m.status = 'verification_pending' and c.risk_state = 'clear' and not k.processing_paused))
  limit greatest(0, least(p_limit, 200));
$$;

-- Retention: failed-claim counters after a day, challenges a day after expiry.
create function public.cleanup_referral_records()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare attempts integer; challenges integer;
begin
  delete from monetization_private.referral_claim_attempts where attempted_at < now() - interval '1 day';
  get diagnostics attempts = row_count;
  delete from monetization_private.integrity_challenges where expires_at < now() - interval '1 day';
  get diagnostics challenges = row_count;
  return jsonb_build_object('claim_attempts', attempts, 'challenges', challenges);
end $$;

-- Operator control for staging and rollout. Changes only the switches and the
-- window; the pinned manifest and reward order stay immutable. The existing
-- table checks refuse an enabled campaign without a complete window.
create function public.set_referral_campaign(p_campaign text, p_enabled boolean, p_processing_paused boolean,
  p_starts_at timestamptz, p_claim_closes_at timestamptz, p_ends_at timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_enabled is null or p_processing_paused is null then
    raise exception 'Switches are required' using errcode = '22023';
  end if;
  update monetization_private.referral_campaigns set enabled = p_enabled,
    processing_paused = p_processing_paused, starts_at = p_starts_at,
    claim_closes_at = p_claim_closes_at, ends_at = p_ends_at
    where id = p_campaign;
  if not found then raise exception 'Unknown campaign' using errcode = '22023'; end if;
  return jsonb_build_object('campaign_id', p_campaign, 'enabled', p_enabled,
    'processing_paused', p_processing_paused);
end $$;

revoke all on function private.referral_milestone_view(uuid, boolean) from public, anon, authenticated, service_role;
revoke all on function public.set_referral_campaign(text, boolean, boolean, timestamptz, timestamptz, timestamptz)
  from public, anon, authenticated;
grant execute on function public.set_referral_campaign(text, boolean, boolean, timestamptz, timestamptz, timestamptz)
  to service_role;
revoke all on function public.issue_referral_challenge(uuid, uuid, text), public.find_referral_receipt(uuid, uuid, uuid, text),
  public.submit_referral_receipt(uuid, uuid, text, jsonb, text, text), public.get_referral_status(uuid, integer, integer),
  public.referral_claims_to_process(integer), public.cleanup_referral_records()
  from public, anon, authenticated;
grant execute on function public.issue_referral_challenge(uuid, uuid, text), public.find_referral_receipt(uuid, uuid, uuid, text),
  public.submit_referral_receipt(uuid, uuid, text, jsonb, text, text), public.get_referral_status(uuid, integer, integer),
  public.referral_claims_to_process(integer), public.cleanup_referral_records()
  to service_role;
commit;
