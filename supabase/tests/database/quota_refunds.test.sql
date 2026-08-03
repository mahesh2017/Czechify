-- The refund functions were written against tables that do not exist
-- (public.ai_daily_quota, public.service_daily_quota) with columns that do not
-- exist (requests_used, quota_date). PL/pgSQL resolves those references on
-- first execution rather than at CREATE time, so both were accepted and then
-- raised `relation does not exist` on every call. The Edge Functions log the
-- error and carry on — correct for a failed refund, but it meant nobody ever
-- got their allowance back and nothing said so.
--
-- These exercise the functions rather than merely asserting they exist, which
-- is the only kind of check that would have caught it.

begin;

drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path = public;
select public.plan(8);

-- Both usage tables have a foreign key to auth.users, so these need a real
-- user row. Some hosted CLI roles cannot write auth fixtures even inside a
-- rollback-only transaction; that environment skips rather than fails, the
-- same guard security_and_sync.test.sql uses.
select has_schema_privilege(current_user, 'auth', 'USAGE') as can_manage_auth \gset
\if :can_manage_auth
insert into auth.users (id)
values ('30000000-0000-0000-0000-000000000001')
on conflict (id) do nothing;

set local role service_role;

-- ── AI daily quota ──

select public.lives_ok(
  $$select public.consume_ai_quota(
      '30000000-0000-0000-0000-000000000001'::uuid, 5)$$,
  'consuming AI quota succeeds'
);

select public.is(
  (select request_count from public.ai_daily_usage
   where user_id = '30000000-0000-0000-0000-000000000001'
     and usage_date = (timezone('utc', now()))::date),
  1,
  'consumption records one request'
);

select public.lives_ok(
  $$select public.refund_ai_daily_quota(
      '30000000-0000-0000-0000-000000000001'::uuid)$$,
  'refunding AI quota does not raise'
);

select public.is(
  (select request_count from public.ai_daily_usage
   where user_id = '30000000-0000-0000-0000-000000000001'
     and usage_date = (timezone('utc', now()))::date),
  0,
  'the refund actually returns the unit'
);

-- A second refund must not mint allowance out of nothing.
select public.lives_ok(
  $$select public.refund_ai_daily_quota(
      '30000000-0000-0000-0000-000000000001'::uuid)$$,
  'a duplicate refund is harmless'
);

select public.is(
  (select request_count from public.ai_daily_usage
   where user_id = '30000000-0000-0000-0000-000000000001'
     and usage_date = (timezone('utc', now()))::date),
  0,
  'a duplicate refund cannot drive the counter below zero'
);

-- ── Per-service (speech) daily quota ──

select public.lives_ok(
  $$select public.consume_service_daily_quota(
      'whisper', '30000000-0000-0000-0000-000000000001'::uuid, 5);
    select public.refund_service_daily_quota(
      'whisper', '30000000-0000-0000-0000-000000000001'::uuid)$$,
  'consuming then refunding speech quota does not raise'
);

select public.is(
  (select request_count from public.ai_service_daily_usage
   where service = 'whisper'
     and user_id = '30000000-0000-0000-0000-000000000001'
     and usage_date = (timezone('utc', now()))::date),
  0,
  'the speech refund actually returns the unit'
);

reset role;
\else
select * from public.skip(
  'hosted CLI role cannot create rollback-only auth fixtures',
  8
);
\endif

select * from public.finish();
rollback;
