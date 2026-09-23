-- Existing-user migration (engineering spec §5, "Existing users").
--
-- One fixed UTC cutoff T0 per run. Every account created before T0 gets a
-- migration grace window ending at T0 + 30 days, whatever happens afterwards:
-- a reinstall or a new device finds the same window. Units the account had
-- reached by the snapshot are granted permanently. Offline-only learners get
-- one claim within 30 days of T0; a claim that adds many units waits for
-- support.
--
-- Reached means a snapshot lesson row that is completed or was attempted.
-- The next unit of a phase is added only when every lesson of every earlier
-- unit in that phase is complete, as the app's progression requires.
-- Placement is ignored, and nothing marks a lesson complete.
begin;

-- Which bundled lesson belongs to which unit. From
-- tool/generate_course_lessons.py; CI checks it against the assets.
create table monetization_private.course_lessons (
  lesson_id integer primary key,
  unit_id integer not null references private.placement_unit_order(unit_id)
);
alter table monetization_private.course_lessons enable row level security;
revoke all on monetization_private.course_lessons from public, anon, authenticated, service_role;
insert into monetization_private.course_lessons(lesson_id, unit_id) values
  (100, 1),
  (101, 1),
  (102, 1),
  (103, 1),
  (201, 2),
  (202, 2),
  (203, 2),
  (204, 2),
  (301, 3),
  (302, 3),
  (303, 3),
  (304, 3),
  (401, 4),
  (402, 4),
  (403, 4),
  (404, 4),
  (501, 5),
  (502, 5),
  (503, 5),
  (504, 5),
  (601, 6),
  (602, 6),
  (603, 6),
  (604, 6),
  (701, 7),
  (702, 7),
  (703, 7),
  (704, 7),
  (801, 8),
  (802, 8),
  (803, 8),
  (804, 8),
  (901, 9),
  (902, 9),
  (903, 9),
  (904, 9),
  (1001, 10),
  (1002, 10),
  (1003, 10),
  (1004, 10),
  (1101, 11),
  (1102, 11),
  (1103, 11),
  (1104, 11),
  (1201, 12),
  (1202, 12),
  (1203, 12),
  (1204, 12),
  (1301, 13),
  (1302, 13),
  (1303, 13),
  (1304, 13),
  (1401, 14),
  (1402, 14),
  (1403, 14),
  (1404, 14),
  (1501, 15),
  (1502, 15),
  (1503, 15),
  (1504, 15),
  (1601, 16),
  (1602, 16),
  (1603, 16),
  (1604, 16),
  (1701, 17),
  (1702, 17),
  (1703, 17),
  (1704, 17),
  (1801, 18),
  (1802, 18),
  (1803, 18),
  (1804, 18),
  (1901, 19),
  (1902, 19),
  (1903, 19),
  (1904, 19),
  (2001, 20),
  (2002, 20),
  (2003, 20),
  (2004, 20),
  (2101, 21),
  (2102, 21),
  (2103, 21),
  (2104, 21),
  (2201, 22),
  (2202, 22),
  (2203, 22),
  (2204, 22),
  (2301, 23),
  (2302, 23),
  (2303, 23),
  (2304, 23),
  (2401, 24),
  (2402, 24),
  (2403, 24),
  (2404, 24),
  (2501, 25),
  (2502, 25),
  (2503, 25),
  (2504, 25),
  (2601, 26),
  (2602, 26),
  (2603, 26),
  (2604, 26),
  (2701, 27),
  (2702, 27),
  (2703, 27),
  (2704, 27),
  (2801, 28),
  (2802, 28),
  (2803, 28),
  (2804, 28),
  (2901, 29),
  (2902, 29),
  (2903, 29),
  (2904, 29),
  (3001, 30),
  (3002, 30),
  (3003, 30),
  (3004, 30),
  (3101, 31),
  (3102, 31),
  (3103, 31),
  (3104, 31);

create table monetization_private.legacy_migration_runs (
  migration_id text primary key check (migration_id ~ '^[a-z0-9-]{3,64}$'),
  cutoff_at timestamptz not null,
  grace_ends_at timestamptz not null,
  claim_window_ends_at timestamptz not null,
  manifest_revision integer not null check (manifest_revision > 0),
  snapshot_taken_at timestamptz,
  dry_run_summary jsonb,
  applied_at timestamptz,
  applied_by text check (applied_by is null or length(applied_by) between 1 and 200),
  check (grace_ends_at = cutoff_at + interval '30 days'),
  check (claim_window_ends_at = cutoff_at + interval '30 days')
);

-- The progress each pre-cutoff account had synced, copied once and never
-- changed: later edits to lesson_progress cannot move the migration.
create table monetization_private.legacy_migration_snapshot (
  migration_id text not null references monetization_private.legacy_migration_runs(migration_id),
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id integer not null references monetization_private.course_lessons(lesson_id),
  is_completed boolean not null,
  attempted boolean not null,
  primary key (migration_id, user_id, lesson_id)
);

create table monetization_private.legacy_migration_claims (
  migration_id text not null references monetization_private.legacy_migration_runs(migration_id),
  user_id uuid not null references auth.users(id) on delete cascade,
  source text not null check (source in ('server_snapshot','offline_claim')),
  input_fingerprint text not null check (input_fingerprint ~ '^[0-9a-f]{64}$'),
  resolved_unit_ids integer[] not null,
  status text not null check (status in ('planned','applied','needs_review','rejected')),
  received_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by text,
  primary key (migration_id, user_id, source)
);

alter table monetization_private.legacy_migration_runs enable row level security;
alter table monetization_private.legacy_migration_snapshot enable row level security;
alter table monetization_private.legacy_migration_claims enable row level security;
revoke all on monetization_private.legacy_migration_runs, monetization_private.legacy_migration_snapshot,
  monetization_private.legacy_migration_claims from public, anon, authenticated, service_role;

-- Units reached by completed and attempted lessons, plus each phase's next
-- unit when every lesson before it in that phase is complete.
create function private.legacy_reached_units(p_completed integer[], p_attempted integer[])
returns integer[] language sql stable security definer set search_path = '' as $$
  with touched as (
    select distinct l.unit_id from monetization_private.course_lessons l
    where l.lesson_id = any(coalesce(p_completed, '{}') || coalesce(p_attempted, '{}'))
  ),
  next_units as (
    select distinct on (o.phase) o.phase, o.unit_id, o.order_index
    from private.placement_unit_order o
    where o.phase in (select p.phase from private.placement_unit_order p join touched t on t.unit_id = p.unit_id)
      and o.unit_id not in (select unit_id from touched)
    order by o.phase, o.order_index
  ),
  earned_next as (
    select n.unit_id from next_units n
    where not exists (
      select 1 from monetization_private.course_lessons l
      join private.placement_unit_order o on o.unit_id = l.unit_id
      where o.phase = n.phase and o.order_index < n.order_index
        and not (l.lesson_id = any(coalesce(p_completed, '{}'))))
  )
  select coalesce(array_agg(unit_id order by unit_id), '{}')
  from (select unit_id from touched union select unit_id from earned_next) u;
$$;

-- Creates the run on first call and takes the snapshot once, at or after the
-- cutoff; then (re)plans the not yet applied server claims from that fixed
-- snapshot and records the dry-run summary. Safe to call repeatedly.
create function public.legacy_migration_prepare(p_migration text, p_cutoff timestamptz,
  p_manifest_revision integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare run monetization_private.legacy_migration_runs; summary jsonb;
begin
  if p_cutoff is null or p_cutoff > now() then
    raise exception 'The snapshot is taken at or after the cutoff' using errcode = '22023';
  end if;
  insert into monetization_private.legacy_migration_runs(migration_id, cutoff_at, grace_ends_at,
      claim_window_ends_at, manifest_revision)
    values (p_migration, p_cutoff, p_cutoff + interval '30 days', p_cutoff + interval '30 days',
      p_manifest_revision)
  on conflict (migration_id) do nothing;
  select * into run from monetization_private.legacy_migration_runs
    where migration_id = p_migration for update;
  if run.cutoff_at <> p_cutoff or run.manifest_revision <> p_manifest_revision then
    raise exception 'A migration run''s cutoff and manifest never change' using errcode = '22023';
  end if;
  if run.applied_at is not null then
    return run.dry_run_summary || jsonb_build_object('applied_at', run.applied_at);
  end if;

  if run.snapshot_taken_at is null then
    insert into monetization_private.legacy_migration_snapshot(migration_id, user_id, lesson_id,
        is_completed, attempted)
      select p_migration, p.user_id, p.lesson_id, p.is_completed, p.last_attempted is not null
      from public.lesson_progress p
      join auth.users u on u.id = p.user_id
      join monetization_private.course_lessons l on l.lesson_id = p.lesson_id
      where u.created_at < p_cutoff and (p.is_completed or p.last_attempted is not null);
    update monetization_private.legacy_migration_runs set snapshot_taken_at = now()
      where migration_id = p_migration;
  end if;

  delete from monetization_private.legacy_migration_claims
    where migration_id = p_migration and source = 'server_snapshot' and status = 'planned';
  insert into monetization_private.legacy_migration_claims(migration_id, user_id, source,
      input_fingerprint, resolved_unit_ids, status)
    select p_migration, s.user_id, 'server_snapshot',
      encode(extensions.digest(string_agg(s.lesson_id || ':' || s.is_completed || ':' || s.attempted,
        ',' order by s.lesson_id), 'sha256'), 'hex'),
      private.legacy_reached_units(
        array_agg(s.lesson_id) filter (where s.is_completed),
        array_agg(s.lesson_id) filter (where s.attempted)),
      'planned'
    from monetization_private.legacy_migration_snapshot s
    where s.migration_id = p_migration
    group by s.user_id
  on conflict (migration_id, user_id, source) do nothing;

  select jsonb_build_object(
    'migration_id', p_migration,
    'cutoff_at', p_cutoff,
    'grace_ends_at', p_cutoff + interval '30 days',
    'eligible_accounts', (select count(*) from auth.users u where u.created_at < p_cutoff),
    'accounts_with_units', (select count(*) from monetization_private.legacy_migration_claims c
      where c.migration_id = p_migration and c.source = 'server_snapshot'
        and cardinality(c.resolved_unit_ids) > 0),
    'unit_grants', (select coalesce(sum(cardinality(c.resolved_unit_ids)), 0)
      from monetization_private.legacy_migration_claims c
      where c.migration_id = p_migration and c.source = 'server_snapshot'),
    'grants_by_unit', (select coalesce(jsonb_object_agg(unit_id, n), '{}'::jsonb) from (
      select unnest(c.resolved_unit_ids) unit_id, count(*) n
      from monetization_private.legacy_migration_claims c
      where c.migration_id = p_migration and c.source = 'server_snapshot'
      group by 1) g),
    'sample', (select coalesce(jsonb_agg(jsonb_build_object('user_id', c.user_id,
        'unit_ids', c.resolved_unit_ids)), '[]'::jsonb)
      from (select * from monetization_private.legacy_migration_claims c
        where c.migration_id = p_migration and c.source = 'server_snapshot'
        order by cardinality(c.resolved_unit_ids) desc, c.user_id limit 5) c))
  into summary;
  update monetization_private.legacy_migration_runs set dry_run_summary = summary
    where migration_id = p_migration;
  return summary;
end $$;

-- A legacy unit grant through the audited grant path; re-granting is a no-op.
create function private.grant_legacy_units(p_user uuid, p_migration text, p_units integer[])
returns void language plpgsql security definer set search_path = '' as $$
declare unit integer;
begin
  foreach unit in array coalesce(p_units, '{}') loop
    perform public.set_course_unit_grant(p_user, unit, 'legacy', p_migration || ':' || unit,
      null, false, 'legacy migration');
  end loop;
end $$;

-- Applies a prepared run once: the grace window for every pre-cutoff account
-- and the planned unit grants. Rerunning changes nothing.
create function public.legacy_migration_apply(p_migration text, p_operator text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare run monetization_private.legacy_migration_runs; claim record; account record;
  windows integer := 0; accounts integer := 0; rev bigint;
begin
  if p_operator is null or length(trim(p_operator)) not between 1 and 200 then
    raise exception 'An operator is required' using errcode = '22023';
  end if;
  select * into run from monetization_private.legacy_migration_runs
    where migration_id = p_migration for update;
  if not found or run.snapshot_taken_at is null then
    raise exception 'Prepare the run first' using errcode = '22023';
  end if;
  if run.applied_at is not null then
    return jsonb_build_object('migration_id', p_migration, 'already_applied_at', run.applied_at);
  end if;

  for account in select u.id from auth.users u where u.created_at < run.cutoff_at loop
    insert into public.monetization_accounts(user_id) values (account.id) on conflict do nothing;
    insert into public.course_access_windows(user_id, kind, starts_at, ends_at, source_key)
      values (account.id, 'migration_grace', run.cutoff_at, run.grace_ends_at, p_migration)
    on conflict (user_id, kind, source_key) do nothing;
    if found then
      windows := windows + 1;
      update public.monetization_accounts set revision = revision + 1, updated_at = now()
        where user_id = account.id returning revision into rev;
      insert into monetization_private.monetization_outbox(user_id, revision, event_type)
        values (account.id, rev, 'course_access_changed');
    end if;
  end loop;

  for claim in select * from monetization_private.legacy_migration_claims
      where migration_id = p_migration and source = 'server_snapshot' and status = 'planned'
      for update loop
    perform private.grant_legacy_units(claim.user_id, p_migration, claim.resolved_unit_ids);
    update monetization_private.legacy_migration_claims
      set status = 'applied', decided_at = now(), decided_by = p_operator
      where migration_id = p_migration and user_id = claim.user_id and source = claim.source;
    accounts := accounts + 1;
  end loop;

  update monetization_private.legacy_migration_runs set applied_at = now(), applied_by = p_operator
    where migration_id = p_migration;
  return jsonb_build_object('migration_id', p_migration, 'grace_windows', windows,
    'accounts_granted', accounts);
end $$;

-- One offline claim per pre-cutoff account, within 30 days of the cutoff,
-- from the app's own record of lessons. Units already granted are not
-- counted again. More than p_review_threshold new units waits for support.
create function public.submit_legacy_claim(p_user uuid, p_migration text, p_completed integer[],
  p_attempted integer[], p_review_threshold integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare run monetization_private.legacy_migration_runs; existing monetization_private.legacy_migration_claims;
  fingerprint text; units integer[]; owned integer[]; fresh integer[]; state text;
begin
  select * into run from monetization_private.legacy_migration_runs where migration_id = p_migration;
  if not found or run.applied_at is null then
    return jsonb_build_object('code', 'migration_not_ready');
  end if;
  if now() >= run.claim_window_ends_at then
    return jsonb_build_object('code', 'claim_window_closed');
  end if;
  if not exists (select 1 from auth.users u where u.id = p_user and u.created_at < run.cutoff_at) then
    return jsonb_build_object('code', 'not_eligible');
  end if;
  perform 1 from public.monetization_accounts where user_id = p_user for update;

  fingerprint := encode(extensions.digest(
    array_to_string(array(select distinct x from unnest(coalesce(p_completed, '{}')) x order by 1), ',')
    || '|' || array_to_string(array(select distinct x from unnest(coalesce(p_attempted, '{}')) x order by 1), ','),
    'sha256'), 'hex');
  select * into existing from monetization_private.legacy_migration_claims
    where migration_id = p_migration and user_id = p_user and source = 'offline_claim';
  if found then
    if existing.input_fingerprint <> fingerprint then
      return jsonb_build_object('code', 'already_claimed', 'status', existing.status);
    end if;
    return jsonb_build_object('status', existing.status, 'unit_ids', existing.resolved_unit_ids);
  end if;

  units := private.legacy_reached_units(p_completed, p_attempted);
  select coalesce(array_agg(g.unit_id), '{}') into owned from public.course_unit_grants g
    where g.user_id = p_user and g.source = 'legacy' and g.revoked_at is null;
  fresh := array(select u from unnest(units) u where not (u = any(owned)) order by u);
  state := case
    when cardinality(units) = 0 then 'rejected'
    when cardinality(fresh) > greatest(p_review_threshold, 0) then 'needs_review'
    else 'applied' end;
  if state = 'applied' then
    perform private.grant_legacy_units(p_user, p_migration, fresh);
  end if;
  insert into monetization_private.legacy_migration_claims(migration_id, user_id, source,
      input_fingerprint, resolved_unit_ids, status, decided_at, decided_by)
    values (p_migration, p_user, 'offline_claim', fingerprint, fresh, state,
      case when state = 'needs_review' then null else now() end,
      case when state = 'needs_review' then null else 'automatic' end);
  return jsonb_build_object('status', state, 'unit_ids', fresh);
end $$;

-- Support's decision on a claim waiting for review.
create function public.resolve_legacy_claim(p_migration text, p_user uuid, p_approve boolean,
  p_operator text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare claim monetization_private.legacy_migration_claims;
begin
  if p_approve is null or p_operator is null or length(trim(p_operator)) not between 1 and 200 then
    raise exception 'A decision and an operator are required' using errcode = '22023';
  end if;
  select * into claim from monetization_private.legacy_migration_claims
    where migration_id = p_migration and user_id = p_user and source = 'offline_claim' for update;
  if not found or claim.status <> 'needs_review' then
    raise exception 'No claim is waiting for review' using errcode = '22023';
  end if;
  if p_approve then
    perform private.grant_legacy_units(p_user, p_migration, claim.resolved_unit_ids);
  end if;
  update monetization_private.legacy_migration_claims
    set status = case when p_approve then 'applied' else 'rejected' end,
      decided_at = now(), decided_by = p_operator
    where migration_id = p_migration and user_id = p_user and source = 'offline_claim';
  return jsonb_build_object('status', case when p_approve then 'applied' else 'rejected' end,
    'unit_ids', claim.resolved_unit_ids);
end $$;

revoke all on function private.legacy_reached_units(integer[], integer[]),
  private.grant_legacy_units(uuid, text, integer[]) from public, anon, authenticated, service_role;
revoke all on function public.legacy_migration_prepare(text, timestamptz, integer),
  public.legacy_migration_apply(text, text),
  public.submit_legacy_claim(uuid, text, integer[], integer[], integer),
  public.resolve_legacy_claim(text, uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.legacy_migration_prepare(text, timestamptz, integer),
  public.legacy_migration_apply(text, text),
  public.submit_legacy_claim(uuid, text, integer[], integer[], integer),
  public.resolve_legacy_claim(text, uuid, boolean, text) to service_role;
commit;
