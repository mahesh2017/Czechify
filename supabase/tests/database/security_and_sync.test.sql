begin;

-- Recreate pgTAP inside this rollback-only transaction. Some hosted projects
-- retain the extension registry entry while omitting its functions from the
-- exposed schema dump; a transactional recreation gives local and linked test
-- runs the same complete harness without persisting any extension change.
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path = public;

select public.plan(51);

select public.has_table('public', 'lesson_progress', 'lesson progress exists');
select public.has_table('public', 'earned_badges', 'earned badges exists');
select public.has_table('public', 'user_progress', 'user progress exists');
select public.has_table('public', 'srs_cards', 'SRS cards exists');
select public.has_table(
  'public',
  'gamification_state',
  'gamification state exists'
);
select public.has_table(
  'public',
  'learner_profiles',
  'learner profiles exist'
);
select public.has_table(
  'public',
  'reminder_preferences',
  'reminder preferences exist'
);
select public.has_table(
  'public',
  'placement_profiles',
  'placement profiles exist'
);

select public.ok(
  (select bool_and(relrowsecurity)
   from pg_class
   where oid in (
     'public.lesson_progress'::regclass,
     'public.earned_badges'::regclass,
     'public.user_progress'::regclass,
     'public.srs_cards'::regclass,
     'public.gamification_state'::regclass,
     'public.custom_cards'::regclass,
     'public.learner_profiles'::regclass,
     'public.reminder_preferences'::regclass,
     'public.placement_profiles'::regclass
   )),
  'RLS is enabled on every user sync table'
);

select public.ok(
  not has_table_privilege('anon', 'public.lesson_progress', 'SELECT')
  and not has_table_privilege('anon', 'public.earned_badges', 'SELECT')
  and not has_table_privilege('anon', 'public.user_progress', 'SELECT')
  and not has_table_privilege('anon', 'public.srs_cards', 'SELECT')
  and not has_table_privilege('anon', 'public.gamification_state', 'SELECT')
  and not has_table_privilege('anon', 'public.custom_cards', 'SELECT')
  and not has_table_privilege('anon', 'public.learner_profiles', 'SELECT')
  and not has_table_privilege('anon', 'public.reminder_preferences', 'SELECT')
  and not has_table_privilege('anon', 'public.placement_profiles', 'SELECT'),
  'anon cannot read user sync tables'
);

select public.ok(
  has_table_privilege('authenticated', 'public.lesson_progress', 'SELECT,INSERT,UPDATE,DELETE'),
  'authenticated has the required lesson progress API grants'
);
select public.ok(
  has_table_privilege('authenticated', 'public.earned_badges', 'SELECT,INSERT,UPDATE,DELETE'),
  'authenticated has the required badge API grants'
);
select public.ok(
  has_table_privilege('authenticated', 'public.user_progress', 'SELECT,INSERT,UPDATE,DELETE'),
  'authenticated has the required KV progress API grants'
);
select public.ok(
  has_table_privilege('authenticated', 'public.srs_cards', 'SELECT,INSERT,UPDATE,DELETE'),
  'authenticated has the required SRS API grants'
);
select public.ok(
  has_table_privilege(
    'authenticated',
    'public.gamification_state',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'authenticated has the required gamification API grants'
);

select public.ok(
  has_table_privilege(
    'authenticated',
    'public.learner_profiles',
    'SELECT,INSERT,UPDATE,DELETE'
  )
  and has_table_privilege(
    'authenticated',
    'public.reminder_preferences',
    'SELECT,INSERT,UPDATE,DELETE'
  )
  and has_table_privilege(
    'authenticated',
    'public.placement_profiles',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'authenticated has the required profile foundation API grants'
);

select public.ok(
  (select count(*)
   from pg_attribute attribute
   join pg_class relation on relation.oid = attribute.attrelid
   join pg_namespace namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'public'
     and relation.relname in (
       'learner_profiles',
       'reminder_preferences',
       'placement_profiles'
     )
     and attribute.attname = 'revision'
     and attribute.attnotnull) = 3
  and
  (select count(*)
   from pg_indexes
   where schemaname = 'public'
     and indexname in (
       'learner_profiles_revision_pull_idx',
       'reminder_preferences_revision_pull_idx',
       'placement_profiles_revision_pull_idx'
     )
     and indexdef like '%(user_id, revision)%') = 3,
  'profile foundation tables have server revision pull metadata'
);

select public.ok(
  has_table_privilege('anon', 'public.curriculum_packs', 'SELECT')
  and has_table_privilege('authenticated', 'public.curriculum_packs', 'SELECT'),
  'published curriculum is readable by both client roles'
);

select public.ok(
  not has_function_privilege('anon', 'public.consume_ai_quota(uuid,integer)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.consume_ai_quota(uuid,integer)', 'EXECUTE')
  and has_function_privilege('service_role', 'public.consume_ai_quota(uuid,integer)', 'EXECUTE'),
  'AI quota function is service-role only'
);

select public.has_table(
  'private',
  'ai_burst_usage',
  'private AI burst counter exists'
);

select public.ok(
  not has_schema_privilege('anon', 'private', 'USAGE')
  and not has_schema_privilege('authenticated', 'private', 'USAGE'),
  'client roles cannot inspect AI burst counters'
);

select public.ok(
  not has_function_privilege(
    'anon',
    'public.consume_ai_burst_quota(uuid,integer,integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.consume_ai_burst_quota(uuid,integer,integer)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.consume_ai_burst_quota(uuid,integer,integer)',
    'EXECUTE'
  ),
  'AI burst function is service-role only'
);

select public.has_table(
  'public',
  'ai_service_daily_usage',
  'service-scoped daily AI usage table exists'
);

select public.ok(
  not has_table_privilege('anon', 'public.ai_service_daily_usage', 'SELECT')
  and not has_table_privilege(
    'authenticated', 'public.ai_service_daily_usage', 'SELECT'
  ),
  'client roles cannot read service usage counters'
);

select public.ok(
  not has_function_privilege(
    'anon',
    'public.consume_service_daily_quota(text,uuid,integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.consume_service_daily_quota(text,uuid,integer)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.consume_service_daily_quota(text,uuid,integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.consume_service_burst_quota(text,uuid,integer,integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.consume_service_burst_quota(text,uuid,integer,integer)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.consume_service_burst_quota(text,uuid,integer,integer)',
    'EXECUTE'
  ),
  'service quota functions are service-role only'
);

select public.ok(
  not has_function_privilege(
    'anon', 'public.purge_stale_anonymous_users()', 'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated', 'public.purge_stale_anonymous_users()', 'EXECUTE'
  ),
  'anonymous-user purge is not callable by client roles'
);

set local role service_role;

select public.is(
  public.consume_service_burst_quota(
    'whisper',
    '40000000-0000-0000-0000-000000000004',
    1,
    100
  ),
  true,
  'first speech request in a burst window is accepted'
);

select public.is(
  public.consume_service_burst_quota(
    'whisper',
    '40000000-0000-0000-0000-000000000004',
    1,
    100
  ),
  false,
  'per-user speech burst limit rejects the next request'
);

select public.is(
  public.consume_ai_burst_quota(
    '30000000-0000-0000-0000-000000000003',
    1,
    100
  ),
  true,
  'first request in a burst window is accepted'
);

select public.is(
  public.consume_ai_burst_quota(
    '30000000-0000-0000-0000-000000000003',
    1,
    100
  ),
  false,
  'per-user burst limit rejects the next request'
);

select public.throws_ok(
  $$select public.consume_ai_burst_quota(
      '30000000-0000-0000-0000-000000000003', 0, 100
    )$$,
  '22023',
  'invalid AI burst quota arguments',
  'invalid burst limits are rejected'
);

select public.is(
  (select count(*)::integer
   from pg_attribute attribute
   join pg_class relation on relation.oid = attribute.attrelid
   join pg_namespace namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'public'
     and relation.relname in (
       'lesson_progress',
       'earned_badges',
       'user_progress',
       'srs_cards',
       'gamification_state'
     )
     and attribute.attname = 'sync_id'
     and attribute.attidentity = 'a'),
  5,
  'all sync tables have server-generated pagination IDs'
);

select public.is(
  (select count(*)::integer
   from pg_indexes
   where schemaname = 'public'
     and indexname in (
       'lesson_progress_sync_pull_idx',
       'earned_badges_sync_pull_idx',
       'user_progress_sync_pull_idx',
       'srs_cards_sync_pull_idx',
       'gamification_state_sync_pull_idx'
     )
     and indexdef like '%(user_id, updated_at, sync_id)%'),
  5,
  'all pull queries have matching composite indexes'
);

set local role service_role;

select public.is(
  (select count(*)::integer from storage.buckets where id = 'course-audio' and public),
  1,
  'public course audio bucket exists'
);

reset role;

select has_schema_privilege(current_user, 'auth', 'USAGE') as can_manage_auth \gset
\if :can_manage_auth
insert into auth.users (id)
values
  ('10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002');

select public.throws_ok(
  $$insert into public.lesson_progress
      (user_id, lesson_id, unit_id, best_score, device_id)
    values
      ('10000000-0000-0000-0000-000000000001', 1, 1, 101, 'device-a')$$,
  '23514',
  'new row for relation "lesson_progress" violates check constraint "lesson_progress_score_range"',
  'score range constraint rejects invalid progress'
);

select public.throws_ok(
  $$insert into public.srs_cards
      (user_id, card_type, content_key, difficulty, device_id)
    values
      ('10000000-0000-0000-0000-000000000001', 'vocabulary', '1', 11, 'device-a')$$,
  '23514',
  'new row for relation "srs_cards" violates check constraint "srs_cards_difficulty_range"',
  'difficulty constraint rejects invalid SRS state'
);

select public.throws_ok(
  $$insert into public.gamification_state
      (user_id, key, hearts, max_hearts, device_id)
    values
      ('10000000-0000-0000-0000-000000000001', 'primary', 6, 5, 'device-a')$$,
  '23514',
  'new row for relation "gamification_state" violates check constraint "gamification_state_hearts_range"',
  'gamification constraints reject impossible heart state'
);

select public.throws_ok(
  $$insert into public.learner_profiles
      (user_id, self_assessed_cefr, device_id)
    values
      ('10000000-0000-0000-0000-000000000001', '', 'device-a')$$,
  '23514',
  'new row for relation "learner_profiles" violates check constraint "learner_profiles_cefr_valid"',
  'learner profile rejects an empty course-level key'
);

select public.throws_ok(
  $$insert into public.reminder_preferences
      (user_id, wants_reminder, preferred_hour, preferred_minute, device_id)
    values
      ('10000000-0000-0000-0000-000000000001', true, 24, 0, 'device-a')$$,
  '23514',
  'new row for relation "reminder_preferences" violates check constraint "reminder_preferences_clock_valid"',
  'reminder preference rejects an invalid local time'
);

select public.throws_ok(
  $$insert into public.placement_profiles
      (user_id, provisional_unit, estimates, device_id)
    values
      ('10000000-0000-0000-0000-000000000001', 1,
       '{"reading":1.5}'::jsonb, 'device-a')$$,
  '23514',
  'new row for relation "placement_profiles" violates check constraint "placement_profiles_estimates_valid"',
  'placement profile rejects an out-of-range skill estimate'
);

insert into public.lesson_progress (
  user_id, lesson_id, unit_id, is_completed, best_score, attempts,
  device_id, updated_at
) values (
  '10000000-0000-0000-0000-000000000001', 10, 1, true, 80, 1,
  'device-b', '2026-07-20T10:00:00Z'
);

update public.lesson_progress
set best_score = 20, device_id = 'device-z', updated_at = '2026-07-20T09:00:00Z'
where user_id = '10000000-0000-0000-0000-000000000001' and lesson_id = 10;

select public.is(
  (select best_score from public.lesson_progress
   where user_id = '10000000-0000-0000-0000-000000000001' and lesson_id = 10),
  80::real,
  'older LWW update is rejected'
);

update public.lesson_progress
set best_score = 90, device_id = 'device-a', updated_at = '2026-07-20T10:00:00Z'
where user_id = '10000000-0000-0000-0000-000000000001' and lesson_id = 10;

select public.is(
  (select best_score from public.lesson_progress
   where user_id = '10000000-0000-0000-0000-000000000001' and lesson_id = 10),
  80::real,
  'lower device ID loses an equal-timestamp tie'
);

update public.lesson_progress
set best_score = 90, device_id = 'device-z', updated_at = '2026-07-20T10:00:00Z'
where user_id = '10000000-0000-0000-0000-000000000001' and lesson_id = 10;

select public.is(
  (select best_score from public.lesson_progress
   where user_id = '10000000-0000-0000-0000-000000000001' and lesson_id = 10),
  90::real,
  'higher device ID wins an equal-timestamp tie'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select public.lives_ok(
  $$insert into public.user_progress (user_id, key, value, device_id)
    values ('10000000-0000-0000-0000-000000000001', 'streak', '4', 'device-a')$$,
  'owner can insert their progress'
);

select public.lives_ok(
  $$insert into public.learner_profiles
      (user_id, display_name, primary_goal, onboarding_version,
       onboarding_last_step, onboarding_completed_at, device_id, updated_at)
    values
      ('10000000-0000-0000-0000-000000000001', 'Mahesh',
       'everyday_communication', 2, 7, '2026-08-30T10:00:00Z',
       'device-a', '2026-08-30T10:00:00Z')$$,
  'owner can insert their learner profile'
);

update public.learner_profiles
set onboarding_version = 1,
    onboarding_last_step = 1,
    onboarding_completed_at = null,
    primary_goal = 'legacyOverwrite',
    device_id = 'device-z',
    updated_at = '2026-08-30T11:00:00Z'
where user_id = '10000000-0000-0000-0000-000000000001'
  and key = 'primary';

select public.ok(
  (select onboarding_version = 2
          and onboarding_last_step = 7
          and primary_goal = 'everyday_communication'
          and onboarding_completed_at = '2026-08-30T10:00:00Z'::timestamptz
   from public.learner_profiles
   where user_id = '10000000-0000-0000-0000-000000000001'
     and key = 'primary'),
  'a legacy profile schema cannot erase richer onboarding fields or milestones'
);

update public.learner_profiles
set onboarding_version = 3,
    onboarding_last_step = 8,
    primary_goal = 'workAndCareer',
    focus_skills = '["speaking"]'::jsonb,
    device_id = 'device-a',
    updated_at = '2026-08-30T09:00:00Z'
where user_id = '10000000-0000-0000-0000-000000000001'
  and key = 'primary';

select public.ok(
  (select onboarding_version = 3
          and onboarding_last_step = 8
          and primary_goal = 'workAndCareer'
          and focus_skills = '["speaking"]'::jsonb
   from public.learner_profiles
   where user_id = '10000000-0000-0000-0000-000000000001'
     and key = 'primary'),
  'a higher profile schema wins even when its device clock is behind'
);

insert into public.placement_profiles (
  user_id, provisional_unit, estimates, sample_size, device_id, updated_at
) values (
  '10000000-0000-0000-0000-000000000001', 18,
  '{"reading":0.8}'::jsonb, 10, 'device-a', '2026-08-30T10:00:00Z'
);

update public.placement_profiles
set provisional_unit = 1,
    estimates = '{"reading":0.1}'::jsonb,
    sample_size = 2,
    device_id = 'device-z',
    updated_at = '2026-08-30T11:00:00Z'
where user_id = '10000000-0000-0000-0000-000000000001'
  and key = 'primary';

select public.ok(
  (select provisional_unit = 18
          and sample_size = 10
          and estimates = '{"reading":0.8}'::jsonb
   from public.placement_profiles
   where user_id = '10000000-0000-0000-0000-000000000001'
     and key = 'primary'),
  'a newer device cannot reduce established placement evidence'
);

select public.throws_ok(
  $$insert into public.user_progress (user_id, key, value, device_id)
    values ('20000000-0000-0000-0000-000000000002', 'streak', '4', 'device-a')$$,
  '42501',
  'new row violates row-level security policy for table "user_progress"',
  'RLS rejects writes for another user'
);

select public.throws_ok(
  $$insert into public.learner_profiles
      (user_id, display_name, device_id)
    values
      ('20000000-0000-0000-0000-000000000002', 'Other', 'device-a')$$,
  '42501',
  'new row violates row-level security policy for table "learner_profiles"',
  'RLS rejects learner profiles for another user'
);

select public.is(
  (select count(*)::integer from public.lesson_progress),
  1,
  'RLS exposes only the current owner rows'
);
\else
select * from public.skip(
  'hosted CLI role cannot create rollback-only auth fixtures',
  15
);
\endif

select * from public.finish();
rollback;
