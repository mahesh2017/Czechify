-- Completion must survive stale offline writes and the v8 history backfill.
begin;

create or replace function private.merge_transfer_assignment()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  old_stage integer := case old.status
    when 'completed' then 2 when 'expired' then 1 else 0 end;
  new_stage integer := case new.status
    when 'completed' then 2 when 'expired' then 1 else 0 end;
begin
  -- A terminal state retains its evidence. Equal terminal states also keep
  -- the first accepted completion, regardless of client clocks.
  if old_stage > 0 and old_stage >= new_stage then
    return old;
  end if;
  if new_stage > old_stage then
    return new;
  end if;
  -- Only pending-to-pending changes use the existing LWW rule.
  if new.updated_at < old.updated_at
     or (new.updated_at = old.updated_at and new.device_id <= old.device_id)
  then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.merge_transfer_assignment()
  from public, anon, authenticated;
drop trigger delayed_transfer_assignments_keep_newest
  on public.delayed_transfer_assignments;
-- The name sorts before the revision trigger: every accepted/retained row
-- still gets its server-owned pull revision afterwards.
create trigger delayed_transfer_assignments_keep_newest
  before update on public.delayed_transfer_assignments
  for each row execute function private.merge_transfer_assignment();

commit;
