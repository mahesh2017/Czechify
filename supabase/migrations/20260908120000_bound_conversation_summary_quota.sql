-- Give conversation summaries their own bounded daily allowance.
--
-- `conversation_summary` was exempt from the daily cap entirely, for a good
-- reason: it is machinery the client issues to compress history the learner
-- never asked to lose, so charging their conversation turns for it would mean
-- a long conversation quietly costs double.
--
-- But exempt from the daily cap left only the per-minute burst limit standing
-- between any authenticated caller — an anonymous account included — and the
-- paid model, indefinitely. A per-minute ceiling is not a spending ceiling.
--
-- So: a second counter, not a shared one. Summaries stay off the learner's
-- conversation allowance and are still bounded per day.

alter table public.ai_daily_usage
  add column if not exists summary_count integer not null default 0;

comment on column public.ai_daily_usage.summary_count is
  'Conversation-summary requests today. Counted separately from request_count '
  'so compression does not consume the learner''s conversation turns, while '
  'still being bounded.';

create or replace function public.consume_ai_summary_quota(
  p_user_id uuid,
  p_daily_limit integer
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  new_count integer;
begin
  if p_daily_limit < 1 then
    return false;
  end if;

  -- Mirrors consume_ai_quota: the conditional update is what makes this
  -- atomic. A row already at the limit fails the where clause, returns no
  -- row, and the caller is refused — two concurrent requests cannot both
  -- read "under the limit" and both increment.
  insert into public.ai_daily_usage (user_id, usage_date, summary_count)
  values (p_user_id, (timezone('utc', now()))::date, 1)
  on conflict (user_id, usage_date) do update
    set summary_count = public.ai_daily_usage.summary_count + 1,
        updated_at = now()
    where public.ai_daily_usage.summary_count < p_daily_limit
  returning summary_count into new_count;

  return new_count is not null and new_count <= p_daily_limit;
end;
$$;

-- Only the edge function's service role may spend quota. Callers must not be
-- able to reach this directly.
revoke all on function public.consume_ai_summary_quota(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.consume_ai_summary_quota(uuid, integer)
  to service_role;

create or replace function public.refund_ai_summary_quota(
  p_user_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Never below zero: a refund for a request that was never counted must not
  -- hand out allowance that was never spent.
  update public.ai_daily_usage
    set summary_count = greatest(0, summary_count - 1),
        updated_at = now()
  where user_id = p_user_id
    and usage_date = (timezone('utc', now()))::date;
end;
$$;

revoke all on function public.refund_ai_summary_quota(uuid)
  from public, anon, authenticated;
grant execute on function public.refund_ai_summary_quota(uuid)
  to service_role;
