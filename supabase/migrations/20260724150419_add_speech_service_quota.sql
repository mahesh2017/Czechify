-- Timestamp matches the migration version already applied to production.
begin;

-- Per-service daily usage counters (speech/Whisper first). Mirrors
-- public.ai_daily_usage but keyed by service so speech transcription quota
-- cannot starve the chat tutor quota (or vice versa).
create table public.ai_service_daily_usage (
  service       text        not null,
  user_id       uuid        not null references auth.users(id) on delete cascade,
  usage_date    date        not null default (timezone('utc', now()))::date,
  request_count integer     not null default 0 check (request_count >= 0),
  updated_at    timestamptz not null default now(),
  primary key (service, user_id, usage_date),
  constraint ai_service_daily_usage_service_valid
    check (service ~ '^[a-z0-9_-]{1,32}$')
);

alter table public.ai_service_daily_usage enable row level security;
revoke all on table public.ai_service_daily_usage from public, anon, authenticated;
grant select, insert, update, delete
  on table public.ai_service_daily_usage to service_role;

comment on table public.ai_service_daily_usage is
  'Service-scoped daily AI usage counters. Service-role only; no client policies by design.';

create or replace function public.consume_service_daily_quota(
  p_service text,
  p_user_id uuid,
  p_daily_limit integer
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_count integer;
begin
  if current_user <> 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if p_service is null
     or p_service !~ '^[a-z0-9_-]{1,32}$'
     or p_user_id is null then
    raise exception 'invalid service quota arguments' using errcode = '22023';
  end if;
  if p_daily_limit < 1 then
    return false;
  end if;

  insert into public.ai_service_daily_usage (
    service, user_id, usage_date, request_count
  )
  values (p_service, p_user_id, (timezone('utc', now()))::date, 1)
  on conflict (service, user_id, usage_date) do update
    set request_count = public.ai_service_daily_usage.request_count + 1,
        updated_at = now()
    where public.ai_service_daily_usage.request_count < p_daily_limit
  returning request_count into new_count;

  return new_count is not null and new_count <= p_daily_limit;
end;
$$;

revoke all on function public.consume_service_daily_quota(text, uuid, integer)
  from public, anon, authenticated;
grant execute on function public.consume_service_daily_quota(text, uuid, integer)
  to service_role;

comment on function public.consume_service_daily_quota(text, uuid, integer) is
  'Atomically consumes one unit of a per-service daily AI quota for a user.';

-- Generalized fixed-window burst limiter. Same storage and semantics as
-- public.consume_ai_burst_quota, but the service name scopes both the shared
-- project window and the per-user window, so each proxy gets independent
-- burst budgets.
create or replace function public.consume_service_burst_quota(
  p_service text,
  p_user_id uuid,
  p_user_limit integer default 5,
  p_project_limit integer default 60
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window timestamptz := date_trunc('minute', now());
  v_user_hash text;
  v_project_hash text;
begin
  if p_service is null
     or p_service !~ '^[a-z0-9_-]{1,32}$'
     or p_user_id is null
     or p_user_limit not between 1 and 100
     or p_project_limit not between 1 and 5000 then
    raise exception 'invalid AI burst quota arguments'
      using errcode = '22023';
  end if;

  v_user_hash := encode(
    extensions.digest(p_service || ':' || p_user_id::text, 'sha256'),
    'hex'
  );
  v_project_hash := encode(extensions.digest(p_service, 'sha256'), 'hex');

  insert into private.ai_burst_usage (
    scope, subject_hash, window_start, request_count
  ) values
    ('project', v_project_hash, v_window, 0),
    ('user', v_user_hash, v_window, 0)
  on conflict do nothing;

  -- Stable lock order prevents deadlocks when many users contend on the
  -- shared project row while retaining independent per-user counters.
  perform 1
  from private.ai_burst_usage
  where window_start = v_window
    and (
      (scope = 'project' and subject_hash = v_project_hash)
      or (scope = 'user' and subject_hash = v_user_hash)
    )
  order by scope, subject_hash
  for update;

  if exists (
    select 1
    from private.ai_burst_usage
    where window_start = v_window
      and (
        (scope = 'project' and subject_hash = v_project_hash
          and request_count >= p_project_limit)
        or (scope = 'user' and subject_hash = v_user_hash
          and request_count >= p_user_limit)
      )
  ) then
    return false;
  end if;

  update private.ai_burst_usage
  set request_count = request_count + 1,
      updated_at = now()
  where window_start = v_window
    and (
      (scope = 'project' and subject_hash = v_project_hash)
      or (scope = 'user' and subject_hash = v_user_hash)
    );

  delete from private.ai_burst_usage
  where window_start < now() - interval '2 days';

  return true;
end;
$$;

revoke all on function public.consume_service_burst_quota(text, uuid, integer, integer)
  from public, anon, authenticated;
grant execute on function public.consume_service_burst_quota(text, uuid, integer, integer)
  to service_role;

comment on function public.consume_service_burst_quota(text, uuid, integer, integer) is
  'Atomically enforces per-user and per-service project-wide fixed-window AI burst limits.';

commit;
