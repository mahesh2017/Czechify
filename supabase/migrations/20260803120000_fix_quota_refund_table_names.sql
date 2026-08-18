-- Repair the quota refund functions, which have never worked.
--
-- Both were written against tables and columns that do not exist:
--
--   refund_ai_daily_quota      -> public.ai_daily_quota (requests_used, quota_date)
--   refund_service_daily_quota -> public.service_daily_quota (requests_used, quota_date)
--
-- The real tables, created by 20260719182206 and 20260724150419 and used by the
-- matching consume_* functions, are:
--
--   public.ai_daily_usage         (user_id, usage_date, request_count)
--   public.ai_service_daily_usage (service, user_id, usage_date, request_count)
--
-- PL/pgSQL resolves table references on first execution, not at CREATE time, so
-- both functions were accepted and then raised `relation does not exist` on
-- every call. The Edge Functions log that error and continue, which is correct
-- behaviour for a refund failure but meant the fault was invisible: every
-- learner who hit a DeepSeek timeout or a Whisper error lost a unit of their
-- daily allowance anyway, for the whole life of the feature.
--
-- The date expression matches consume_*: an explicit UTC date rather than
-- CURRENT_DATE, so a refund lands on the same row the consumption created
-- regardless of the server's timezone.
--
-- Rollback: restore the bodies from 20260731180000 (they are inert either way).

begin;

create or replace function public.refund_ai_daily_quota(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_user <> 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
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
  if current_user <> 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if p_service is null or p_service !~ '^[a-z0-9_-]{1,32}$' then
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

comment on function public.refund_ai_daily_quota(uuid) is
  'Decrements the AI daily usage counter by 1 when an upstream call fails, so a learner does not lose allowance to a server-side fault.';
comment on function public.refund_service_daily_quota(text, uuid) is
  'Decrements a per-service daily usage counter by 1 when an upstream call fails.';

revoke all on function public.refund_ai_daily_quota(uuid)
  from public, anon, authenticated;
revoke all on function public.refund_service_daily_quota(text, uuid)
  from public, anon, authenticated;
grant execute on function public.refund_ai_daily_quota(uuid) to service_role;
grant execute on function public.refund_service_daily_quota(text, uuid)
  to service_role;

commit;
