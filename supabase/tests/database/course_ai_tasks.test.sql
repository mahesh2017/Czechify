begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path=public;
select no_plan();

create temp table actors(label text primary key,id uuid not null);
create function pg_temp.actor(p_label text) returns uuid language plpgsql as $$
declare u uuid:=gen_random_uuid();
begin
  insert into auth.users(id,created_at) values(u,now()-interval '1 day');
  insert into public.monetization_accounts(user_id) values(u);
  insert into actors values(p_label,u); return u;
end $$;
create function pg_temp.uid(p_label text) returns uuid language sql as $$ select id from actors where label=p_label $$;

select pg_temp.actor('free'); select pg_temp.actor('core'); select pg_temp.actor('staff'); select pg_temp.actor('expired_staff');
select pg_temp.actor('grace'); select pg_temp.actor('referral'); select pg_temp.actor('ai_only');
insert into monetization_private.feature_entitlements(user_id,feature,source_key,state,valid_until,verified_at)
  values(pg_temp.uid('core'),'core','play:core','active',now()+interval '20 days',now()),
        (pg_temp.uid('ai_only'),'ai_chat','play:ai','active',now()+interval '20 days',now());
insert into public.curriculum_entitlements(user_id,unlock_all,expires_at)
  values(pg_temp.uid('staff'),true,null),(pg_temp.uid('expired_staff'),true,now()-interval '1 minute');
insert into public.course_access_windows(user_id,kind,starts_at,ends_at,source_key)
  values(pg_temp.uid('grace'),'migration_grace',now()-interval '1 day',now()+interval '29 days','t0');
-- Every paid A1 unit earned through referrals, as if all fifteen rewards landed.
insert into public.course_unit_grants(user_id,unit_id,source,source_key,campaign_id)
  select pg_temp.uid('referral'),u,'referral','m'||u,'a1-referral-v1'
  from unnest(array[3,4,5,6,7,8,9,10,11,12,13,14,15,28,30]) u;

-- The manifest: eleven writing tasks from the bundled exam banks.
select is((select count(*)::integer from monetization_private.course_ai_tasks),11,'eleven server-known writing tasks');
select is((select count(*)::integer from monetization_private.course_ai_tasks where level='a1'),5,'five A1 tasks');
select is((select array_agg(distinct operation) from monetization_private.course_ai_tasks),array['writing_evaluation'],'only writing evaluation is authorized');
select ok(not has_table_privilege('service_role','monetization_private.course_ai_tasks','SELECT'),'tasks are reached only through functions');
select ok(not has_function_privilege('authenticated','public.course_ai_task(uuid,text)','EXECUTE'),'clients cannot look up tasks');
select ok(not has_function_privilege('authenticated','public.consume_ai_feedback(uuid,integer)','EXECUTE'),'clients cannot spend feedback');

-- Level access mirrors the app's CourseAccessPolicy.
select ok(not has_course_level_access(pg_temp.uid('free'),'a1'),'two free units do not open the A1 exam');
select ok(not has_course_level_access(pg_temp.uid('free'),'a2'),'nor A2');
select ok(has_course_level_access(pg_temp.uid('core'),'a1') and has_course_level_access(pg_temp.uid('core'),'a2'),'Core opens both levels');
select ok(has_course_level_access(pg_temp.uid('staff'),'a2'),'an open-ended staff override opens A2');
select ok(not has_course_level_access(pg_temp.uid('expired_staff'),'a1'),'an expired staff override does not');
select ok(has_course_level_access(pg_temp.uid('grace'),'a2'),'the migration grace window opens A2');
select ok(has_course_level_access(pg_temp.uid('referral'),'a1'),'every A1 unit earned opens the A1 exam');
select ok(not has_course_level_access(pg_temp.uid('referral'),'a2'),'referral units never open A2');
select ok(not has_course_level_access(pg_temp.uid('ai_only'),'a1'),'the AI subscription is not course access');
update public.course_unit_grants set revoked_at=now(),revocation_reason_code='fraud' where user_id=pg_temp.uid('referral') and unit_id=30;
select ok(not has_course_level_access(pg_temp.uid('referral'),'a1'),'one revoked grant closes the level');
select ok(not has_course_level_access(pg_temp.uid('core'),'b1'),'an unknown level is never open');

-- Task lookup carries the server's text and the access decision.
select is(course_ai_task(pg_temp.uid('core'),'nope/s1/q0'),null,'an unknown task is null');
select is(course_ai_task(pg_temp.uid('core'),'a1-practice-1/s1/q0')->>'level','a1','task level comes from the server');
select ok((course_ai_task(pg_temp.uid('core'),'a2-practice-1/s1/q0')->>'task_description') like 'Napište e-mail%','task text comes from the server');
select is(course_ai_task(pg_temp.uid('core'),'a2-practice-1/s1/q0')->>'allowed','true','Core may have A2 evaluated');
select is(course_ai_task(pg_temp.uid('free'),'a1-practice-1/s1/q0')->>'allowed','false','free learners may not');

-- Feedback has its own allowance, apart from chat turns.
select is(consume_ai_feedback(pg_temp.uid('core'),2)->>'remaining','1','first feedback leaves one');
select is(consume_ai_feedback(pg_temp.uid('core'),2)->>'allowed','true','second feedback allowed');
select is(consume_ai_feedback(pg_temp.uid('core'),2)->>'allowed','false','third feedback refused');
select ok((consume_ai_feedback(pg_temp.uid('core'),2)->>'resets_at')::timestamptz > now(),'the refusal says when it resets');
select is((select conversation_count from monetization_private.ai_daily_allowance where user_id=pg_temp.uid('core')),0,'feedback spends no chat turns');
select refund_ai_feedback(pg_temp.uid('core'),(timezone('utc',now()))::date);
select is((select feedback_count from monetization_private.ai_daily_allowance where user_id=pg_temp.uid('core')),1,'a refund returns one');
select refund_ai_feedback(pg_temp.uid('core'),(timezone('utc',now()))::date - 1);
select is((select feedback_count from monetization_private.ai_daily_allowance where user_id=pg_temp.uid('core')),1,'a refund for another day changes nothing today');
select is(consume_ai_feedback(pg_temp.uid('core'),0)->>'allowed','false','a zero limit allows nothing');

select * from finish();
rollback;
