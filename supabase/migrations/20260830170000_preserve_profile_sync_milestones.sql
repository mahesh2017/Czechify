-- Preserve monotonic learner milestones at the shared source of truth.
--
-- Client merges already refuse to erase onboarding completion or reduce an
-- unlocked placement ceiling. The server must enforce the same rule: a fresh
-- install sees only the current server row and cannot reconstruct a milestone
-- that an older device was allowed to overwrite.

begin;

create or replace function private.preserve_learner_profile_milestones()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.onboarding_version := greatest(
    old.onboarding_version,
    new.onboarding_version
  );
  new.onboarding_last_step := greatest(
    old.onboarding_last_step,
    new.onboarding_last_step
  );
  if old.onboarding_completed_at is not null
     and (
       new.onboarding_completed_at is null
       or new.onboarding_completed_at < old.onboarding_completed_at
     )
  then
    new.onboarding_completed_at := old.onboarding_completed_at;
  end if;
  return new;
end;
$$;

revoke all on function private.preserve_learner_profile_milestones()
  from public, anon, authenticated;

drop trigger if exists preserve_learner_profile_milestones
  on public.learner_profiles;
create trigger preserve_learner_profile_milestones
before update on public.learner_profiles
for each row execute function private.preserve_learner_profile_milestones();

create or replace function private.preserve_placement_milestones()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.provisional_unit := greatest(
    old.provisional_unit,
    new.provisional_unit
  );
  if old.learner_override_unit is not null then
    new.learner_override_unit := greatest(
      old.learner_override_unit,
      coalesce(new.learner_override_unit, old.learner_override_unit)
    );
  end if;
  if new.sample_size < old.sample_size then
    new.estimates := old.estimates;
  end if;
  new.sample_size := greatest(old.sample_size, new.sample_size);
  return new;
end;
$$;

revoke all on function private.preserve_placement_milestones()
  from public, anon, authenticated;

drop trigger if exists preserve_placement_milestones
  on public.placement_profiles;
create trigger preserve_placement_milestones
before update on public.placement_profiles
for each row execute function private.preserve_placement_milestones();

commit;
