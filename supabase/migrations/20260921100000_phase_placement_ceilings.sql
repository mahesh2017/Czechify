begin;

-- Published revision 25 placement order; match assets/curriculum/*_units.json.
-- This reference is not a paid entitlement or a client-writable progress table.
create table private.placement_unit_order (
  unit_id integer primary key,
  phase text not null check (phase in ('a1','a2')),
  order_index integer not null,
  unique (phase, order_index)
);
insert into private.placement_unit_order
select id, case when id = any(array[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,28,30])
  then 'a1' else 'a2' end, id from generate_series(1,31) id;
revoke all on private.placement_unit_order from public, anon, authenticated;

alter table public.placement_profiles add column phase_ceilings jsonb;

create function private.normalize_phase_ceilings(p_value jsonb, p_legacy integer)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb := '{}'::jsonb; entry record;
begin
  if p_value is null then
    select coalesce(jsonb_object_agg(phase, unit_id), '{}'::jsonb) into result
    from (select distinct on (phase) phase, unit_id
      from private.placement_unit_order
      where order_index <= (select order_index from private.placement_unit_order where unit_id = p_legacy)
      order by phase, order_index desc) units;
    return result;
  end if;
  if jsonb_typeof(p_value) <> 'object' then
    raise exception 'Invalid phase ceilings' using errcode = '22023';
  end if;
  for entry in select * from jsonb_each(p_value) loop
    if not exists (select 1 from private.placement_unit_order u
      where u.phase = entry.key and to_jsonb(u.unit_id) = entry.value) then
      raise exception 'Invalid phase unit' using errcode = '22023';
    end if;
  end loop;
  return p_value;
end;
$$;
create function private.merge_phase_ceilings(p_left jsonb, p_right jsonb)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(phase, unit_id), '{}'::jsonb)
  from (select distinct on (u.phase) u.phase, u.unit_id
    from private.placement_unit_order u
    where to_jsonb(u.unit_id) in (p_left -> u.phase, p_right -> u.phase)
    order by u.phase, u.order_index desc) merged;
$$;

update public.placement_profiles
set phase_ceilings = private.normalize_phase_ceilings(null, provisional_unit);

create or replace function private.preserve_placement_milestones()
returns trigger language plpgsql security definer set search_path = '' as $$
declare incoming jsonb;
begin
  incoming := private.normalize_phase_ceilings(new.phase_ceilings, new.provisional_unit);
  if tg_op = 'UPDATE' then
    -- An older client updating just the scalar still retains its old open span.
    if new.phase_ceilings = old.phase_ceilings and
       new.provisional_unit is distinct from old.provisional_unit then
      incoming := private.merge_phase_ceilings(incoming,
        private.normalize_phase_ceilings(null, new.provisional_unit));
    end if;
    new.phase_ceilings := private.merge_phase_ceilings(
      private.normalize_phase_ceilings(old.phase_ceilings, old.provisional_unit), incoming);
    -- Compatibility only: modern access uses phase_ceilings, never this max.
    new.provisional_unit := greatest(old.provisional_unit, new.provisional_unit);
    new.learner_override_unit := greatest(old.learner_override_unit, new.learner_override_unit);
    if new.sample_size < old.sample_size then new.estimates := old.estimates; end if;
    new.sample_size := greatest(old.sample_size, new.sample_size);
  else
    new.phase_ceilings := incoming;
  end if;
  return new;
end;
$$;
drop trigger if exists preserve_placement_milestones on public.placement_profiles;
create trigger preserve_placement_milestones before insert or update on public.placement_profiles
for each row execute function private.preserve_placement_milestones();
revoke all on function private.normalize_phase_ceilings(jsonb,integer),
  private.merge_phase_ceilings(jsonb,jsonb), private.preserve_placement_milestones()
  from public, anon, authenticated;
commit;
