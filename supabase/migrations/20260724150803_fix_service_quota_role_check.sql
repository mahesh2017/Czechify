-- Timestamp matches the migration version already applied to production.
-- In a `security definer` function `current_user` is the function owner, not
-- the caller, so the role guard always rejected — the same defect fixed for
-- consume_ai_quota in 20260719182220. Authorization is enforced by EXECUTE
-- grants (service_role only); drop the in-body check.
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
