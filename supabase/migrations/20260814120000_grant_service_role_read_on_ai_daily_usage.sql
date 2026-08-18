-- The AI allowance the chat screen shows was never going to appear.
--
-- `deepseek-proxy` consumes quota through `consume_ai_quota`, which is
-- SECURITY DEFINER and therefore runs as the owner — that part worked. But to
-- tell the learner how many turns remain it then reads the counter directly:
--
--   admin.from("ai_daily_usage").select("request_count")
--
-- PostgREST runs that as `service_role`, and `service_role` was never granted
-- anything on this table. `20260719182206_create_ai_daily_quota.sql` revoked
-- from anon and authenticated and stopped there. So the read returned
-- `permission denied`, `remaining_today()` swallowed the error and returned
-- null, and the client simply never displayed an allowance. A feature that
-- fails by showing nothing is indistinguishable from one that is switched off,
-- which is why this survived until pgTAP exercised the real table as the real
-- role.
--
-- The sibling table added later, `ai_service_daily_usage`, got this right in
-- `20260724150419_add_speech_service_quota.sql`, which is why the pronunciation
-- allowance works and the tutor allowance does not.
--
-- SELECT only, deliberately. Every write to this table goes through a
-- SECURITY DEFINER function that does not need the grant, so widening it to
-- match the sibling's select/insert/update/delete would hand the API role
-- write access to a billing counter for no reason.

begin;

grant select on table public.ai_daily_usage to service_role;

comment on table public.ai_daily_usage is
  'Daily AI tutor usage counter. Written only through SECURITY DEFINER quota '
  'functions; service_role holds SELECT so the proxy can report the remaining '
  'allowance to the client.';

commit;
