-- The refund functions still do not refund anything.
--
-- `20260803120000` corrected the table names they were written against, which
-- was a real bug, but both bodies kept this guard:
--
--   if current_user <> 'service_role' then
--     raise exception 'not authorized' using errcode = '42501';
--   end if;
--
-- In a `security definer` function `current_user` is the function owner, not
-- the caller, so the guard rejects every call — including the only caller
-- there is. This is the third appearance of the same defect: fixed for
-- consume_ai_quota in 20260719182220, for consume_service_daily_quota in
-- 20260724150803, and reintroduced here when the refund functions were
-- written from the older template.
--
-- The effect in production is precisely what 20260803120000 set out to stop.
-- The Edge Functions call a refund after any upstream failure and only
-- `console.error` the result, so every learner who hit a DeepSeek timeout or a
-- Whisper error has still been losing a unit of their daily allowance, and
-- nothing anywhere said so.
--
-- Authorization is enforced by the EXECUTE grants below — service_role only,
-- revoked from everyone else — which is how the two consume_* functions have
-- been protected since their own fixes. Argument validation stays: it checks
-- the input, not the caller.
--
-- Rollback: restore the bodies from 20260803120000. They are inert either way,
-- which is the whole problem.

begin;

create or replace function public.refund_ai_daily_quota(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null then
    raise exception 'invalid refund arguments' using errcode = '22023';
  end if;

  -- Only ever decrements an existing row; never creates one, and never goes
  -- below zero, so a duplicate refund cannot mint allowance.
  update public.ai_daily_usage
  set request_count = greatest(request_count - 1, 0),
      updated_at = now()
  where user_id = p_user_id
    and usage_date = (timezone('utc', now()))::date;
end;
$$;

create or replace function public.refund_service_daily_quota(
  p_service text,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_service is null
     or p_service !~ '^[a-z0-9_-]{1,32}$'
     or p_user_id is null then
    raise exception 'invalid service quota arguments' using errcode = '22023';
  end if;

  update public.ai_service_daily_usage
  set request_count = greatest(request_count - 1, 0),
      updated_at = now()
  where service = p_service
    and user_id = p_user_id
    and usage_date = (timezone('utc', now()))::date;
end;
$$;

revoke all on function public.refund_ai_daily_quota(uuid)
  from public, anon, authenticated;
revoke all on function public.refund_service_daily_quota(text, uuid)
  from public, anon, authenticated;
grant execute on function public.refund_ai_daily_quota(uuid) to service_role;
grant execute on function public.refund_service_daily_quota(text, uuid)
  to service_role;

commit;
