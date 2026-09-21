-- Audit repair: claim requests before charging quota and reserve summary progress.
begin;
alter table monetization_private.ai_request_reservations
  add column summary_turns integer check (summary_turns >= 0);
-- Conservatively fence summaries that were already dispatched by older code.
update monetization_private.ai_request_reservations r set summary_turns = s.turns
  from monetization_private.ai_chat_sessions s
  where r.user_id = s.user_id and r.session_id = s.session_id
    and r.operation = 'conversation_summary';

create or replace function public.reserve_ai_request(p_user uuid, p_request uuid, p_operation text,
  p_digest text, p_session uuid, p_conversation_limit integer, p_summary_limit integer,
  p_min_new_turns integer, p_lease_seconds integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  today date := (timezone('utc', now()))::date;
  existing monetization_private.ai_request_reservations;
  summary boolean := p_operation = 'conversation_summary';
  counted integer;
  summary_turn integer;
begin
  if p_operation not in ('conversation','conversation_summary') or p_request is null
      or p_session is null or p_digest is null or p_digest !~ '^[0-9a-f]{64}$'
      or p_lease_seconds < 1 then
    raise exception 'Invalid reservation' using errcode = '22023';
  end if;

  -- Serialize claims even when no reservation row exists yet. Per-user
  -- locking also serializes summary eligibility across different request IDs.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('ai-reserve:' || p_user::text, 0));

  select * into existing from monetization_private.ai_request_reservations
    where user_id = p_user and request_id = p_request for update;
  if found then
    if existing.payload_digest <> p_digest or existing.operation <> p_operation
        or existing.session_id <> p_session then
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
    select s.turns into summary_turn from monetization_private.ai_chat_sessions s
      where s.user_id = p_user and s.session_id = p_session
        and s.turns - greatest(s.turns_at_last_summary, coalesce((
          select max(r.summary_turns) from monetization_private.ai_request_reservations r
          where r.user_id = p_user and r.session_id = p_session
            and r.operation = 'conversation_summary'
            and r.state in ('in_flight', 'result_unavailable', 'completed')
        ), 0)) >= greatest(p_min_new_turns, 1);
    if not found then
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
      payload_digest, session_id, quota_day, state, lease_expires_at, summary_turns)
    values (p_user, p_request, p_operation, p_digest, p_session, today, 'in_flight',
      now() + make_interval(secs => p_lease_seconds), summary_turn)
  on conflict (user_id, request_id) do update
    set state = 'in_flight', quota_day = excluded.quota_day,
      summary_turns = excluded.summary_turns,
      lease_expires_at = excluded.lease_expires_at, updated_at = now();

  return jsonb_build_object('outcome', 'reserved',
    'remaining', case when summary then null else p_conversation_limit - counted end);
end $$;

-- The provider answered and the reply is usable. Stores the sealed reply for
-- replay, adds the cost to project spend, and advances the chat session.
create or replace function public.complete_ai_request(p_user uuid, p_request uuid, p_input_tokens integer,
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
    update monetization_private.ai_chat_sessions set turns_at_last_summary = greatest(turns_at_last_summary, coalesce(r.summary_turns, turns)), updated_at = now()
      where user_id = p_user and session_id = r.session_id;
  end if;
  return true;
end $$;


commit;
