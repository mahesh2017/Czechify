-- Make filed reports actually reach the backend.
--
-- `tutor_reply_reports` was added as a synced entity but not built like one.
-- Every push goes through one generic writer, `SupabaseSyncBackend.send`,
-- which stamps `device_id` and `updated_at` onto the record and upserts it.
-- This table declared neither column and granted only select/insert, so:
--
--   * PostgREST rejected the record for the unknown columns, and
--   * even with the columns, `on conflict do update` needs UPDATE privilege.
--
-- Both failures land in the outbox's retry path, which is silent by design.
-- The learner was told their report had been received while every attempt to
-- deliver it failed and eventually dead-lettered — worse than the `mailto:`
-- handoff it replaced, which at least failed visibly. The report reaching a
-- human is the whole point of the Play generative-AI requirement.
--
-- Triage state stays ours. UPDATE is granted at table level (column grants
-- would break the moment the pushed payload gains a field, reintroducing
-- exactly this silent failure), and a trigger pins the columns the client has
-- no business changing: a report is a record of something that happened.
--
-- Rollback:
--   drop trigger tutor_reply_reports_preserve_triage on public.tutor_reply_reports;
--   drop function private.preserve_tutor_report_triage();
--   drop policy tutor_reply_reports_owner_update on public.tutor_reply_reports;
--   revoke update on table public.tutor_reply_reports from authenticated;
--   alter table public.tutor_reply_reports drop column updated_at, drop column device_id;

begin;

alter table public.tutor_reply_reports
  add column device_id  text        not null default '',
  add column updated_at timestamptz not null default now();

-- Reporting the same reply twice from two devices is the only conflict this
-- table can have, and both rows say the same thing. The re-push must still be
-- *allowed*, or it retries forever.
grant update on table public.tutor_reply_reports to authenticated;

create policy tutor_reply_reports_owner_update
on public.tutor_reply_reports
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- What a learner may not rewrite by re-filing: the triage state we set, when
-- we first received it, and the moment they said it happened. Everything else
-- in a re-push is the same report by construction (the row is keyed on a
-- client-generated report id), so letting it through is harmless.
create or replace function private.preserve_tutor_report_triage()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.status      := old.status;
  new.created_at  := old.created_at;
  new.reported_at := old.reported_at;
  return new;
end;
$$;

revoke all on function private.preserve_tutor_report_triage()
  from public, anon, authenticated;

create trigger tutor_reply_reports_preserve_triage
  before update on public.tutor_reply_reports
  for each row
  execute function private.preserve_tutor_report_triage();

commit;
