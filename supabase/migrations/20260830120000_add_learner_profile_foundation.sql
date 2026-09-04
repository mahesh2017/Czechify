-- Account-scoped learner profile foundation.
--
-- These rows hold only portable intent and learning state. Notification
-- permission, scheduled notification IDs, detected timezone, and downloaded
-- audio remain device-local: an authorization granted on one phone cannot be
-- transferred to another.
--
-- All three tables follow the existing offline-first sync contract:
--   * the authenticated user owns exactly one logical row;
--   * client timestamps + device_id provide deterministic LWW conflict handling;
--   * a server-owned revision is stamped on every accepted write for pull cursors;
--   * RLS prevents one account reading or writing another account's rows.

begin;

create sequence if not exists public.learner_profiles_revision_seq;
create sequence if not exists public.reminder_preferences_revision_seq;
create sequence if not exists public.placement_profiles_revision_seq;

create or replace function private.valid_bounded_string_array(
  p_values jsonb,
  p_max_items integer,
  p_max_item_length integer
) returns boolean
language sql
immutable
security definer
set search_path = ''
as $$
  select case
    when pg_catalog.jsonb_typeof(p_values) <> 'array' then false
    when pg_catalog.jsonb_array_length(p_values) > p_max_items then false
    else not exists (
      select 1
      from pg_catalog.jsonb_array_elements(p_values) as item(value)
      where pg_catalog.jsonb_typeof(value) <> 'string'
         or length(value #>> '{}') not between 1 and p_max_item_length
         or value #>> '{}' <> btrim(value #>> '{}')
    )
  end
$$;

create or replace function private.valid_study_days(p_values jsonb)
returns boolean
language sql
immutable
security definer
set search_path = ''
as $$
  select case
    when pg_catalog.jsonb_typeof(p_values) <> 'array' then false
    when pg_catalog.jsonb_array_length(p_values) not between 1 and 7 then false
    else
      not exists (
        select 1
        from pg_catalog.jsonb_array_elements(p_values) as item(value)
        where pg_catalog.jsonb_typeof(value) <> 'number'
           or case
                when pg_catalog.jsonb_typeof(value) = 'number'
                  then (value #>> '{}')::numeric not between 1 and 7
                       or trunc((value #>> '{}')::numeric) <>
                          (value #>> '{}')::numeric
                else true
              end
      )
      and (
        select count(*) = count(distinct value)
        from pg_catalog.jsonb_array_elements_text(p_values) as item(value)
      )
  end
$$;

create or replace function private.valid_placement_estimates(
  p_estimates jsonb
) returns boolean
language sql
immutable
security definer
set search_path = ''
as $$
  select case
    when pg_catalog.jsonb_typeof(p_estimates) <> 'object' then false
    else not exists (
      select 1
      from pg_catalog.jsonb_each(p_estimates) as estimate(skill, value)
      where skill not in ('reading', 'listening', 'writing', 'speaking')
         or case
              when pg_catalog.jsonb_typeof(value) = 'number'
                then ((value #>> '{}')::numeric not between 0 and 1)
              else true
            end
    )
  end
$$;

-- PostgreSQL checks EXECUTE privilege before evaluating a constraint helper,
-- even when that helper is SECURITY DEFINER. Authenticated writers therefore
-- need EXECUTE, while the missing private-schema USAGE privilege still makes
-- direct client RPC calls impossible.
revoke all on function private.valid_bounded_string_array(jsonb, integer, integer)
  from public, anon;
revoke all on function private.valid_study_days(jsonb)
  from public, anon;
revoke all on function private.valid_placement_estimates(jsonb)
  from public, anon;
grant execute on function private.valid_bounded_string_array(jsonb, integer, integer)
  to authenticated, service_role;
grant execute on function private.valid_study_days(jsonb)
  to authenticated, service_role;
grant execute on function private.valid_placement_estimates(jsonb)
  to authenticated, service_role;

create table if not exists public.learner_profiles (
  user_id                  uuid        not null
                                       references auth.users (id) on delete cascade,
  key                      text        not null default 'primary',
  display_name             text        not null default '',
  self_assessed_cefr       text        not null default 'preA1',
  primary_goal             text,
  secondary_goals          jsonb       not null default '[]'::jsonb,
  exam_track               text,
  target_horizon           text,
  focus_skills             jsonb       not null default '[]'::jsonb,
  daily_commitment_minutes integer     not null default 15,
  study_days_per_week      integer     not null default 7,
  preferred_voice          text        not null default 'female',
  tts_speech_rate          double precision not null default 0.45,
  daily_goal_xp            integer     not null default 300,
  onboarding_version       integer     not null default 1,
  onboarding_last_step     integer     not null default 0,
  onboarding_completed_at  timestamptz,
  device_id                text        not null,
  updated_at               timestamptz not null default now(),
  revision                 bigint      not null default
                                       nextval('public.learner_profiles_revision_seq'),
  primary key (user_id, key),
  constraint learner_profiles_primary_key_valid
    check (key = 'primary'),
  constraint learner_profiles_display_name_valid
    check (display_name = btrim(display_name) and length(display_name) <= 80),
  constraint learner_profiles_cefr_valid
    check (
      self_assessed_cefr = btrim(self_assessed_cefr)
      and length(self_assessed_cefr) between 1 and 64
    ),
  constraint learner_profiles_primary_goal_valid
    check (
      primary_goal is null
      or (
        primary_goal = btrim(primary_goal)
        and length(primary_goal) between 1 and 64
      )
    ),
  constraint learner_profiles_secondary_goals_valid
    check (private.valid_bounded_string_array(secondary_goals, 8, 64)),
  constraint learner_profiles_exam_track_valid
    check (
      exam_track is null
      or (exam_track = btrim(exam_track) and length(exam_track) between 1 and 64)
    ),
  constraint learner_profiles_target_horizon_valid
    check (
      target_horizon is null
      or (
        target_horizon = btrim(target_horizon)
        and length(target_horizon) between 1 and 64
      )
    ),
  constraint learner_profiles_focus_skills_valid
    check (private.valid_bounded_string_array(focus_skills, 16, 64)),
  constraint learner_profiles_commitment_valid
    check (daily_commitment_minutes between 1 and 1440),
  constraint learner_profiles_study_days_valid
    check (study_days_per_week between 1 and 7),
  constraint learner_profiles_preferred_voice_valid
    check (
      preferred_voice = btrim(preferred_voice)
      and length(preferred_voice) between 1 and 64
    ),
  constraint learner_profiles_tts_speech_rate_valid
    check (tts_speech_rate between 0.1 and 2.0),
  constraint learner_profiles_daily_goal_valid
    check (daily_goal_xp between 1 and 100000),
  constraint learner_profiles_onboarding_valid
    check (
      onboarding_version between 1 and 1000
      and onboarding_last_step between 0 and 1000
      and (onboarding_completed_at is null or onboarding_version > 0)
    ),
  constraint learner_profiles_device_id_valid
    check (length(device_id) between 1 and 128)
);

alter sequence public.learner_profiles_revision_seq
  owned by public.learner_profiles.revision;

create table if not exists public.reminder_preferences (
  user_id                  uuid        not null
                                       references auth.users (id) on delete cascade,
  key                      text        not null default 'primary',
  wants_reminder           boolean     not null default false,
  preferred_hour           smallint,
  preferred_minute         smallint,
  days_of_week             jsonb       not null default '[1,2,3,4,5,6,7]'::jsonb,
  catch_up_enabled         boolean     not null default true,
  allow_goal_specific_text boolean     not null default false,
  device_id                text        not null,
  updated_at               timestamptz not null default now(),
  revision                 bigint      not null default
                                       nextval('public.reminder_preferences_revision_seq'),
  primary key (user_id, key),
  constraint reminder_preferences_primary_key_valid
    check (key = 'primary'),
  constraint reminder_preferences_clock_valid
    check (
      (preferred_hour is null) = (preferred_minute is null)
      and (preferred_hour is null or preferred_hour between 0 and 23)
      and (preferred_minute is null or preferred_minute between 0 and 59)
      and (not wants_reminder or preferred_hour is not null)
    ),
  constraint reminder_preferences_study_days_valid
    check (private.valid_study_days(days_of_week)),
  constraint reminder_preferences_device_id_valid
    check (length(device_id) between 1 and 128)
);

alter sequence public.reminder_preferences_revision_seq
  owned by public.reminder_preferences.revision;

-- Mirrors the local Drift placement profile without coupling the server to
-- local auto-increment IDs. Estimates are structured JSON because the set of
-- assessed skills may grow; the validator still rejects unknown/non-numeric or
-- out-of-range values today.
create table if not exists public.placement_profiles (
  user_id              uuid        not null
                                   references auth.users (id) on delete cascade,
  key                  text        not null default 'primary',
  provisional_unit     integer     not null,
  learner_override_unit integer,
  estimates            jsonb       not null default '{}'::jsonb,
  sample_size          integer     not null default 0,
  device_id            text        not null,
  updated_at           timestamptz not null default now(),
  revision             bigint      not null default
                                   nextval('public.placement_profiles_revision_seq'),
  primary key (user_id, key),
  constraint placement_profiles_primary_key_valid
    check (key = 'primary'),
  constraint placement_profiles_provisional_unit_valid
    check (provisional_unit between 1 and 10000),
  constraint placement_profiles_override_unit_valid
    check (learner_override_unit is null or learner_override_unit between 1 and 10000),
  constraint placement_profiles_estimates_valid
    check (private.valid_placement_estimates(estimates)),
  constraint placement_profiles_sample_size_valid
    check (sample_size between 0 and 10000),
  constraint placement_profiles_device_id_valid
    check (length(device_id) between 1 and 128)
);

alter sequence public.placement_profiles_revision_seq
  owned by public.placement_profiles.revision;

drop trigger if exists learner_profiles_stamp_revision
  on public.learner_profiles;
create trigger learner_profiles_stamp_revision
before insert or update on public.learner_profiles
for each row execute function public.stamp_sync_revision(
  'public.learner_profiles_revision_seq'
);

drop trigger if exists keep_newest_sync_row on public.learner_profiles;
create trigger keep_newest_sync_row
before update on public.learner_profiles
for each row execute function private.keep_newest_sync_row();

drop trigger if exists reminder_preferences_stamp_revision
  on public.reminder_preferences;
create trigger reminder_preferences_stamp_revision
before insert or update on public.reminder_preferences
for each row execute function public.stamp_sync_revision(
  'public.reminder_preferences_revision_seq'
);

drop trigger if exists keep_newest_sync_row on public.reminder_preferences;
create trigger keep_newest_sync_row
before update on public.reminder_preferences
for each row execute function private.keep_newest_sync_row();

drop trigger if exists placement_profiles_stamp_revision
  on public.placement_profiles;
create trigger placement_profiles_stamp_revision
before insert or update on public.placement_profiles
for each row execute function public.stamp_sync_revision(
  'public.placement_profiles_revision_seq'
);

drop trigger if exists keep_newest_sync_row on public.placement_profiles;
create trigger keep_newest_sync_row
before update on public.placement_profiles
for each row execute function private.keep_newest_sync_row();

create index if not exists learner_profiles_revision_pull_idx
  on public.learner_profiles (user_id, revision);
create index if not exists reminder_preferences_revision_pull_idx
  on public.reminder_preferences (user_id, revision);
create index if not exists placement_profiles_revision_pull_idx
  on public.placement_profiles (user_id, revision);

alter table public.learner_profiles enable row level security;
alter table public.reminder_preferences enable row level security;
alter table public.placement_profiles enable row level security;

drop policy if exists learner_profiles_owner on public.learner_profiles;
create policy learner_profiles_owner
on public.learner_profiles
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists reminder_preferences_owner
  on public.reminder_preferences;
create policy reminder_preferences_owner
on public.reminder_preferences
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists placement_profiles_owner on public.placement_profiles;
create policy placement_profiles_owner
on public.placement_profiles
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on table public.learner_profiles from anon, authenticated;
revoke all on table public.reminder_preferences from anon, authenticated;
revoke all on table public.placement_profiles from anon, authenticated;

grant select, insert, update, delete on table public.learner_profiles
  to authenticated;
grant select, insert, update, delete on table public.reminder_preferences
  to authenticated;
grant select, insert, update, delete on table public.placement_profiles
  to authenticated;

commit;
