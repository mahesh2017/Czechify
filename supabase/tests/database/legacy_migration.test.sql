begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path=public;
select no_plan();

-- T0 is ten days ago; accounts are placed before or after it.
create temp table t0 as select now() - interval '10 days' as cutoff;
create temp table actors(label text primary key,id uuid not null);
create function pg_temp.actor(p_label text,p_before boolean) returns uuid language plpgsql as $$
declare u uuid:=gen_random_uuid();
begin
  insert into auth.users(id,created_at) values(u,(select cutoff from t0)
    + case when p_before then -interval '30 days' else interval '1 day' end);
  insert into actors values(p_label,u); return u;
end $$;
create function pg_temp.uid(p_label text) returns uuid language sql as $$ select id from actors where label=p_label $$;
create function pg_temp.progress(p_label text,p_lesson integer,p_unit integer,p_done boolean,p_attempted boolean)
returns void language sql as $$
  insert into public.lesson_progress(user_id,lesson_id,unit_id,is_completed,last_attempted,device_id)
  values(pg_temp.uid(p_label),p_lesson,p_unit,p_done,case when p_attempted then now()-interval '20 days' end,'d1') $$;
create function pg_temp.legacy_units(p_label text) returns integer[] language sql as $$
  select coalesce(array_agg(unit_id order by unit_id),'{}') from public.course_unit_grants
  where user_id=pg_temp.uid(p_label) and source='legacy' and revoked_at is null $$;

select pg_temp.actor('partial',true); select pg_temp.actor('complete',true); select pg_temp.actor('empty',true);
select pg_temp.actor('a2',true); select pg_temp.actor('late',false); select pg_temp.actor('offline',true);
select pg_temp.actor('greedy',true); select pg_temp.actor('newcomer',false);

-- Unit 1 finished, unit 2 only started: reached 1 and 2, but not 3.
select pg_temp.progress('partial',l,1,true,true) from unnest(array[100,101,102,103]) l;
select pg_temp.progress('partial',201,2,false,true);
-- Units 1 and 2 finished: unit 3 is the next unit and is earned.
select pg_temp.progress('complete',l,case when l<200 then 1 else 2 end,true,true)
  from unnest(array[100,101,102,103,201,202,203,204]) l;
-- Default rows the app creates carry no evidence.
select pg_temp.progress('empty',l,1,false,false) from unnest(array[100,101]) l;
-- A2 progress stays A2, and the client's own unit ID is not trusted.
select pg_temp.progress('a2',1601,3,false,true);
-- An unknown lesson is ignored.
select pg_temp.progress('a2',99999,1,true,true);
-- After the cutoff: normal rules, no migration.
select pg_temp.progress('late',l,1,true,true) from unnest(array[100,101,102,103]) l;

select ok(not has_function_privilege('authenticated','public.legacy_migration_apply(text,text)','EXECUTE'),'clients cannot apply a migration');
select ok(not has_function_privilege('authenticated','public.submit_legacy_claim(uuid,text,integer[],integer[],integer)','EXECUTE'),'clients cannot claim directly');
select ok(not has_table_privilege('service_role','monetization_private.legacy_migration_claims','SELECT'),'claims are reached only through functions');
select is((select count(*)::integer from monetization_private.course_lessons),124,'every bundled lesson is known');

-- Unit rules on their own.
select is(private.legacy_reached_units(array[100,101,102,103],array[201]),array[1,2],'partial next unit is not granted');
select is(private.legacy_reached_units(array[100,101,102,103,201,202,203,204],'{}'),array[1,2,3],'a finished phase prefix earns the next unit');
select is(private.legacy_reached_units('{}','{}'),'{}'::integer[],'no evidence, no units');
select is(private.legacy_reached_units('{}',array[1601]),array[16],'A2 stays A2');

select throws_ok(format($$select legacy_migration_prepare('t0-test',%L,25)$$,now()+interval '1 day'),'22023',null,'no snapshot before the cutoff');
create temp table dry as select legacy_migration_prepare('t0-test',(select cutoff from t0),25) s;
select is(((select s from dry)->>'accounts_with_units')::integer,3,'three pre-cutoff accounts reached units');
select is(((select s from dry)->>'unit_grants')::integer,6,'six unit grants planned: 1,2 + 1,2,3 + 16');
select ok(((select s from dry)->>'eligible_accounts')::integer >= 6,'every pre-cutoff account is eligible for grace');
select is((select count(*)::integer from public.course_unit_grants where source='legacy'),0,'a dry run grants nothing');
select throws_ok(format($$select legacy_migration_prepare('t0-test',%L,25)$$,(select cutoff from t0)-interval '1 hour'),'22023',null,'a run''s cutoff never changes');

-- Progress changed after the snapshot does not move the migration.
select pg_temp.progress('empty',102,1,true,true);
select legacy_migration_prepare('t0-test',(select cutoff from t0),25);
select is(((select dry_run_summary from monetization_private.legacy_migration_runs where migration_id='t0-test')->>'unit_grants')::integer,6,'the snapshot is fixed once taken');

select throws_ok($$select legacy_migration_apply('t0-test','')$$,'22023',null,'an operator is required');
select is((legacy_migration_apply('t0-test','ops@example')->>'accounts_granted')::integer,3,'apply grants the planned accounts');
select is(pg_temp.legacy_units('partial'),array[1,2],'exact reached units granted');
select is(pg_temp.legacy_units('complete'),array[1,2,3],'next unit granted after a finished prefix');
select is(pg_temp.legacy_units('empty'),'{}'::integer[],'empty rows grant nothing');
select is(pg_temp.legacy_units('a2'),array[16],'the A2 grant is A2 only');
select is(pg_temp.legacy_units('late'),'{}'::integer[],'accounts after the cutoff are not migrated');
select is((select ends_at from public.course_access_windows where user_id=pg_temp.uid('empty')),(select cutoff from t0)+interval '30 days','grace ends at T0 + 30 days, even without units');
select is((select count(*)::integer from public.course_access_windows where user_id=pg_temp.uid('late')),0,'no grace after the cutoff');
select ok((get_monetization_snapshot(pg_temp.uid('empty'))->>'migration_grace_until')::timestamptz > now(),'the signed snapshot carries the grace');

-- Rerunning applies nothing twice.
create temp table counts as select (select count(*) from public.course_unit_grants) g,(select count(*) from public.course_access_windows) w,
  (select count(*) from monetization_private.monetization_outbox) o;
select ok(legacy_migration_apply('t0-test','ops@example') ? 'already_applied_at','a second apply is a no-op');
select is((select count(*) from public.course_unit_grants),(select g from counts),'no duplicate grants');
select is((select count(*) from public.course_access_windows),(select w from counts),'no duplicate windows');
select is((select count(*) from monetization_private.monetization_outbox),(select o from counts),'no duplicate events');

-- A reinstall cannot restart grace: the window is server-side and fixed.
delete from public.lesson_progress where user_id=pg_temp.uid('empty');
select legacy_migration_apply('t0-test','ops@example');
select is((select count(*)::integer from public.course_access_windows where user_id=pg_temp.uid('empty')),1,'still one window after progress is wiped');

-- Offline claims.
select is(submit_legacy_claim(pg_temp.uid('newcomer'),'t0-test',array[100],'{}',3)->>'code','not_eligible','post-cutoff accounts cannot claim');
select is(submit_legacy_claim(pg_temp.uid('offline'),'nope','{}','{}',3)->>'code','migration_not_ready','unknown run');
select is(submit_legacy_claim(pg_temp.uid('offline'),'t0-test',array[100,101,102,103],array[201],3)->>'status','applied','a modest offline claim applies');
select is(pg_temp.legacy_units('offline'),array[1,2],'offline evidence grants the reached units');
select is(submit_legacy_claim(pg_temp.uid('offline'),'t0-test',array[103,102,101,100],array[201],3)->>'status','applied','the same claim again returns its result');
select is(submit_legacy_claim(pg_temp.uid('offline'),'t0-test',array[100,101,102,103,201],'{}',3)->>'code','already_claimed','one claim per account');
select is(submit_legacy_claim(pg_temp.uid('complete'),'t0-test',array[100,101,102,103,201,202,203,204],'{}',3)->'unit_ids','[]'::jsonb,'units already granted are not counted again');
select is(submit_legacy_claim(pg_temp.uid('greedy'),'t0-test',
  array(select lesson_id from monetization_private.course_lessons where unit_id in (1,2,3,4,5)),'{}',3)->>'status','needs_review','a large claim waits for support');
select is(pg_temp.legacy_units('greedy'),'{}'::integer[],'nothing is granted while under review');
select is((resolve_legacy_claim('t0-test',pg_temp.uid('greedy'),true,'support@example')->>'status'),'applied','support approves');
select is(pg_temp.legacy_units('greedy'),array[1,2,3,4,5,6],'approved units are granted');
select throws_ok(format($$select resolve_legacy_claim('t0-test',%L,false,'support@example')$$,pg_temp.uid('greedy')),'22023',null,'a decided claim cannot be decided again');
select is(submit_legacy_claim(pg_temp.uid('empty'),'t0-test','{}','{}',3)->>'status','rejected','a claim with no evidence is rejected');

-- The window closes 30 days after the cutoff.
create temp table old as select legacy_migration_prepare('t0-old',now()-interval '31 days',25) s;
select legacy_migration_apply('t0-old','ops@example');
select is(submit_legacy_claim(pg_temp.uid('offline'),'t0-old',array[100],'{}',3)->>'code','claim_window_closed','claims close with the window');

-- Legacy units are never taken for a referral reward.
select ok(not exists (select 1 from public.course_unit_grants where source='legacy' and campaign_id is not null),'legacy grants carry no campaign');

select * from finish();
rollback;
