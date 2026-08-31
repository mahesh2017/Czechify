-- Treat onboarding_version as the learner-profile schema version.
--
-- A device upgrading from an older Czechify build can legitimately have a
-- later wall clock while knowing only the legacy name/level fields. Ordinary
-- timestamp LWW would let that row erase a newer device's goal, focus, exam
-- horizon, commitment, and tutor choices. Higher schema versions therefore
-- dominate wall-clock order; equal versions retain the normal deterministic
-- updated_at + device_id rule.

begin;

create or replace function private.keep_newest_learner_profile_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.onboarding_version < old.onboarding_version then
    return old;
  end if;

  if new.onboarding_version > old.onboarding_version then
    -- Let the existing generic revision trigger publish this accepted change
    -- even when the newer-schema device's clock is behind.
    new.updated_at := greatest(
      new.updated_at,
      old.updated_at + interval '1 microsecond'
    );
    return new;
  end if;

  if new.updated_at < old.updated_at
     or (new.updated_at = old.updated_at and new.device_id <= old.device_id)
  then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.keep_newest_learner_profile_row()
  from public, anon, authenticated;

drop trigger if exists keep_newest_sync_row on public.learner_profiles;
create trigger keep_newest_sync_row
before update on public.learner_profiles
for each row execute function private.keep_newest_learner_profile_row();

commit;
