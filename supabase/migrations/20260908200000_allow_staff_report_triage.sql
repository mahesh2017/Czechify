-- Learners may retry reports; only staff may set triage state.
begin;

create or replace function private.preserve_tutor_report_triage()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- Use the database role, not a caller-supplied field. This function must
  -- remain SECURITY INVOKER so current_user identifies the writer.
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.status := 'new';
    new.created_at := now();
  else
    new.status := old.status;
    new.created_at := old.created_at;
    new.reported_at := old.reported_at;
  end if;
  return new;
end;
$$;

revoke all on function private.preserve_tutor_report_triage()
  from public, anon, authenticated;
drop trigger tutor_reply_reports_preserve_triage on public.tutor_reply_reports;
create trigger tutor_reply_reports_preserve_triage
  before insert or update on public.tutor_reply_reports
  for each row execute function private.preserve_tutor_report_triage();
grant select, update on public.tutor_reply_reports to service_role;

commit;
