-- Paid AI chat: entitlement, idempotent reservations, replay and a project
-- spend ceiling (engineering spec §6).
--
-- A chat turn or summary reserves its daily allowance in the same transaction
-- that records the request. A retry with the same request ID and payload never
-- reserves twice and never reaches the provider twice: it gets the stored
-- reply, is told the first attempt is still running, or — when that attempt's
-- outcome is unknown — gets result_unavailable. Chat allowances are counted
-- here, apart from the course-feedback counters in public.ai_daily_usage.
begin;

create table monetization_private.ai_chat_sessions (
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null,
  turns integer not null default 0 check (turns >= 0),
  turns_at_last_summary integer not null default 0 check (turns_at_last_summary >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, session_id)
);

create table monetization_private.ai_daily_allowance (
  user_id uuid not null references auth.users(id) on delete cascade,
  quota_day date not null,
  conversation_count integer not null default 0 check (conversation_count >= 0),
  summary_count integer not null default 0 check (summary_count >= 0),
  primary key (user_id, quota_day)
);

create table monetization_private.ai_request_reservations (
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  operation text not null check (operation in ('conversation','conversation_summary')),
  payload_digest text not null check (payload_digest ~ '^[0-9a-f]{64}$'),
  session_id uuid not null,
  quota_day date not null,
  -- in_flight: reserved, provider call may be running.
  -- completed: reply stored for replay (until replay_expires_at).
  -- result_unavailable: outcome unknown; charged, never redispatched.
  -- released: definitely failed; allowance returned, may be retried.
  state text not null check (state in ('in_flight','completed','result_unavailable','released')),
  lease_expires_at timestamptz not null,
  input_tokens integer,
  output_tokens integer,
  cost_micros bigint,
  replay_sealed text,
  replay_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, request_id)
);
create index ai_request_reservations_created on monetization_private.ai_request_reservations(created_at);

create table monetization_private.ai_project_spend (
  spend_day date primary key,
  cost_micros bigint not null default 0 check (cost_micros >= 0),
  ceiling_tripped_at timestamptz
);

alter table monetization_private.ai_chat_sessions enable row level security;
alter table monetization_private.ai_daily_allowance enable row level security;
alter table monetization_private.ai_request_reservations enable row level security;
alter table monetization_private.ai_project_spend enable row level security;
revoke all on monetization_private.ai_chat_sessions, monetization_private.ai_daily_allowance,
  monetization_private.ai_request_reservations, monetization_private.ai_project_spend
  from public, anon, authenticated, service_role;

-- Live AI access: a verified ai_chat purchase only. Staff course overrides
-- and referral grants are deliberately not consulted.
create function public.has_ai_chat_access(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from monetization_private.feature_entitlements e
    where e.user_id = p_user and e.feature = 'ai_chat'
      and e.state in ('active','in_grace_period','canceled') and e.valid_until > now());
$$;

-- Whether today's estimated provider spend has reached p_ceiling_micros. The
-- first request to find it reached records the trip once, as an incident.
create function public.ai_spend_ceiling_reached(p_ceiling_micros bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare today date := (timezone('utc', now()))::date; spent bigint; tripped timestamptz;
begin
  select cost_micros, ceiling_tripped_at into spent, tripped
    from monetization_private.ai_project_spend where spend_day = today;
  if coalesce(spent, 0) < p_ceiling_micros then
    return jsonb_build_object('reached', false);
  end if;
  if tripped is null then
    update monetization_private.ai_project_spend set ceiling_tripped_at = now()
      where spend_day = today and ceiling_tripped_at is null;
    return jsonb_build_object('reached', true, 'newly_tripped', found);
  end if;
  return jsonb_build_object('reached', true, 'newly_tripped', false);
end $$;

-- Adds an estimated provider cost to today's project spend. Every provider
-- call reports here, whatever its outcome for the learner.
create function public.record_ai_spend(p_cost_micros bigint)
returns void language sql security definer set search_path = '' as $$
  insert into monetization_private.ai_project_spend(spend_day, cost_micros)
    values ((timezone('utc', now()))::date, greatest(0, coalesce(p_cost_micros, 0)))
  on conflict (spend_day) do update
    set cost_micros = monetization_private.ai_project_spend.cost_micros + excluded.cost_micros;
$$;

-- Reserve one chat turn or summary. Outcomes:
--   reserved            new request; call the provider, then complete/release.
--   replay              same request already answered; replay_sealed attached.
--   in_flight           same request still running; retry later.
--   result_unavailable  same request's outcome is unknown; not redispatched.
--   conflict            same request ID, different payload.
--   quota_exceeded      daily allowance used; resets_at attached.
--   summary_not_due     unknown session or too few new turns since the last summary.
create function public.reserve_ai_request(p_user uuid, p_request uuid, p_operation text,
  p_digest text, p_session uuid, p_conversation_limit integer, p_summary_limit integer,
  p_min_new_turns integer, p_lease_seconds integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  today date := (timezone('utc', now()))::date;
  existing monetization_private.ai_request_reservations;
  summary boolean := p_operation = 'conversation_summary';
  counted integer;
begin
  if p_operation not in ('conversation','conversation_summary') or p_request is null
      or p_session is null or p_digest is null or p_digest !~ '^[0-9a-f]{64}$'
      or p_lease_seconds < 1 then
    raise exception 'Invalid reservation' using errcode = '22023';
  end if;

  select * into existing from monetization_private.ai_request_reservations
    where user_id = p_user and request_id = p_request for update;
  if found then
    if existing.payload_digest <> p_digest or existing.operation <> p_operation then
      return jsonb_build_object('outcome', 'conflict');
    end if;
    if existing.state = 'completed' then
      if existing.replay_sealed is not null and existing.replay_expires_at > now() then
        return jsonb_build_object('outcome', 'replay', 'replay_sealed', existing.replay_sealed);
      end if;
      return jsonb_build_object('outcome', 'result_unavailable');
    end if;
    if existing.state = 'result_unavailable' then
      return jsonb_build_object('outcome', 'result_unavailable');
    end if;
    if existing.state = 'in_flight' then
      if existing.lease_expires_at > now() then
        return jsonb_build_object('outcome', 'in_flight');
      end if;
      -- The first attempt outlived its lease without reporting. Its provider
      -- call may have been billed; never start a second one.
      update monetization_private.ai_request_reservations
        set state = 'result_unavailable', updated_at = now()
        where user_id = p_user and request_id = p_request;
      return jsonb_build_object('outcome', 'result_unavailable');
    end if;
    -- released: the earlier attempt definitely failed and was refunded, so
    -- this one reserves afresh below.
  end if;

  if summary then
    if not exists (select 1 from monetization_private.ai_chat_sessions s
        where s.user_id = p_user and s.session_id = p_session
          and s.turns - s.turns_at_last_summary >= greatest(p_min_new_turns, 1)) then
      return jsonb_build_object('outcome', 'summary_not_due');
    end if;
  end if;

  -- The conditional update is the atomic check: a row at the limit matches
  -- nothing, so two concurrent requests cannot both pass it.
  if summary then
    insert into monetization_private.ai_daily_allowance(user_id, quota_day, summary_count)
      values (p_user, today, 1)
    on conflict (user_id, quota_day) do update
      set summary_count = monetization_private.ai_daily_allowance.summary_count + 1
      where monetization_private.ai_daily_allowance.summary_count < p_summary_limit
    returning summary_count into counted;
  else
    insert into monetization_private.ai_daily_allowance(user_id, quota_day, conversation_count)
      values (p_user, today, 1)
    on conflict (user_id, quota_day) do update
      set conversation_count = monetization_private.ai_daily_allowance.conversation_count + 1
      where monetization_private.ai_daily_allowance.conversation_count < p_conversation_limit
    returning conversation_count into counted;
  end if;
  if counted is null or counted > (case when summary then p_summary_limit else p_conversation_limit end) then
    if counted is not null then
      raise exception 'Allowance overrun' using errcode = '23514';
    end if;
    return jsonb_build_object('outcome', 'quota_exceeded',
      'resets_at', (today + 1)::timestamp at time zone 'UTC');
  end if;

  insert into monetization_private.ai_request_reservations(user_id, request_id, operation,
      payload_digest, session_id, quota_day, state, lease_expires_at)
    values (p_user, p_request, p_operation, p_digest, p_session, today, 'in_flight',
      now() + make_interval(secs => p_lease_seconds))
  on conflict (user_id, request_id) do update
    set state = 'in_flight', quota_day = excluded.quota_day,
      lease_expires_at = excluded.lease_expires_at, updated_at = now();

  return jsonb_build_object('outcome', 'reserved',
    'remaining', case when summary then null else p_conversation_limit - counted end);
end $$;

-- The provider answered and the reply is usable. Stores the sealed reply for
-- replay, adds the cost to project spend, and advances the chat session.
create function public.complete_ai_request(p_user uuid, p_request uuid, p_input_tokens integer,
  p_output_tokens integer, p_cost_micros bigint, p_replay_sealed text, p_replay_seconds integer)
returns boolean language plpgsql security definer set search_path = '' as $$
declare r monetization_private.ai_request_reservations;
begin
  update monetization_private.ai_request_reservations
    set state = 'completed', input_tokens = p_input_tokens, output_tokens = p_output_tokens,
      cost_micros = p_cost_micros, replay_sealed = p_replay_sealed,
      replay_expires_at = now() + make_interval(secs => p_replay_seconds), updated_at = now()
    where user_id = p_user and request_id = p_request and state = 'in_flight'
    returning * into r;
  if not found then return false; end if;
  perform public.record_ai_spend(p_cost_micros);
  if r.operation = 'conversation' then
    insert into monetization_private.ai_chat_sessions(user_id, session_id, turns)
      values (p_user, r.session_id, 1)
    on conflict (user_id, session_id) do update
      set turns = monetization_private.ai_chat_sessions.turns + 1, updated_at = now();
  else
    update monetization_private.ai_chat_sessions set turns_at_last_summary = turns, updated_at = now()
      where user_id = p_user and session_id = r.session_id;
  end if;
  return true;
end $$;

-- The request definitely failed for the learner: the allowance goes back to
-- the day it was taken from, and any cost the provider still charged is
-- recorded. The same request ID may be retried.
create function public.release_ai_request(p_user uuid, p_request uuid, p_cost_micros bigint)
returns boolean language plpgsql security definer set search_path = '' as $$
declare r monetization_private.ai_request_reservations;
begin
  update monetization_private.ai_request_reservations
    set state = 'released', cost_micros = p_cost_micros, updated_at = now()
    where user_id = p_user and request_id = p_request and state = 'in_flight'
    returning * into r;
  if not found then return false; end if;
  if coalesce(p_cost_micros, 0) > 0 then perform public.record_ai_spend(p_cost_micros); end if;
  update monetization_private.ai_daily_allowance
    set conversation_count = greatest(0, conversation_count - case when r.operation = 'conversation' then 1 else 0 end),
      summary_count = greatest(0, summary_count - case when r.operation = 'conversation_summary' then 1 else 0 end)
    where user_id = p_user and quota_day = r.quota_day;
  return true;
end $$;

-- The provider's outcome is unknown (timeout, dropped connection). The
-- allowance stays spent and the request is never sent again.
create function public.abandon_ai_request(p_user uuid, p_request uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update monetization_private.ai_request_reservations
    set state = 'result_unavailable', updated_at = now()
    where user_id = p_user and request_id = p_request and state = 'in_flight';
  return found;
end $$;

-- Conversation turns left today, for the chat screen.
create function public.get_ai_allowance(p_user uuid, p_conversation_limit integer)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'remaining', greatest(0, p_conversation_limit - coalesce((select a.conversation_count
      from monetization_private.ai_daily_allowance a
      where a.user_id = p_user and a.quota_day = (timezone('utc', now()))::date), 0)),
    'daily_limit', p_conversation_limit,
    'resets_at', ((timezone('utc', now()))::date + 1)::timestamp at time zone 'UTC');
$$;

-- Retention: replay content 24 hours, content-free tombstones seven days,
-- allowance and spend rows 30 days, idle sessions 30 days.
create function public.cleanup_ai_request_records()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cleared integer; removed integer;
begin
  update monetization_private.ai_request_reservations set replay_sealed = null
    where replay_sealed is not null and replay_expires_at <= now();
  get diagnostics cleared = row_count;
  delete from monetization_private.ai_request_reservations where created_at < now() - interval '7 days';
  get diagnostics removed = row_count;
  delete from monetization_private.ai_daily_allowance where quota_day < (timezone('utc', now()))::date - 30;
  delete from monetization_private.ai_project_spend where spend_day < (timezone('utc', now()))::date - 30;
  delete from monetization_private.ai_chat_sessions where updated_at < now() - interval '30 days';
  return jsonb_build_object('replay_cleared', cleared, 'tombstones_removed', removed);
end $$;

revoke all on function public.has_ai_chat_access(uuid), public.ai_spend_ceiling_reached(bigint),
  public.record_ai_spend(bigint),
  public.reserve_ai_request(uuid, uuid, text, text, uuid, integer, integer, integer, integer),
  public.complete_ai_request(uuid, uuid, integer, integer, bigint, text, integer),
  public.release_ai_request(uuid, uuid, bigint), public.abandon_ai_request(uuid, uuid),
  public.get_ai_allowance(uuid, integer), public.cleanup_ai_request_records()
  from public, anon, authenticated;
grant execute on function public.has_ai_chat_access(uuid), public.ai_spend_ceiling_reached(bigint),
  public.record_ai_spend(bigint),
  public.reserve_ai_request(uuid, uuid, text, text, uuid, integer, integer, integer, integer),
  public.complete_ai_request(uuid, uuid, integer, integer, bigint, text, integer),
  public.release_ai_request(uuid, uuid, bigint), public.abandon_ai_request(uuid, uuid),
  public.get_ai_allowance(uuid, integer), public.cleanup_ai_request_records()
  to service_role;
commit;
