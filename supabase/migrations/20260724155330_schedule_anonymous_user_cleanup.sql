-- Timestamp matches the migration version already applied to production.
-- Anonymous-user hygiene: purge never-linked anonymous accounts that have
-- been idle for 90+ days, so orphaned sync rows don't accumulate forever.
--
-- Safe for real users: the app is offline-first, so a returning user's local
-- data re-syncs under a fresh anonymous session. Linked accounts
-- (is_anonymous = false) and recently-active anonymous accounts are never
-- touched. Deleting the auth user cascades to that user's sync rows via the
-- ON DELETE CASCADE user_id foreign keys.

create extension if not exists pg_cron;

create or replace function public.purge_stale_anonymous_users()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  with purged as (
    delete from auth.users u
    where u.is_anonymous = true
      and coalesce(u.last_sign_in_at, u.created_at) < now() - interval '90 days'
    returning u.id
  )
  select count(*) into deleted_count from purged;
  return deleted_count;
end;
$$;

comment on function public.purge_stale_anonymous_users() is
  'Deletes never-linked anonymous auth users idle 90+ days (cascades to their '
  'sync rows). Invoked daily by pg_cron; runnable manually for backfill.';

-- SECURITY DEFINER runs as the (postgres) owner, so no client role needs
-- EXECUTE. Revoke the default public grant so only the cron job (owner) can
-- trigger the purge.
revoke all on function public.purge_stale_anonymous_users()
  from public, anon, authenticated;

-- Idempotent: scheduling by name replaces any existing job of that name.
select cron.schedule(
  'purge-stale-anonymous-users',
  '17 3 * * *', -- daily at 03:17 UTC, off the top-of-hour load
  $$select public.purge_stale_anonymous_users();$$
);
