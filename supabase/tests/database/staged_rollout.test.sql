begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path=public;
select no_plan();

select ok(not has_function_privilege('authenticated','public.rollout_for(uuid)','EXECUTE'),'clients cannot read cohorts directly');
select ok(not has_function_privilege('authenticated','public.set_rollout(text,integer,uuid[],text,text)','EXECUTE'),'clients cannot change the rollout');

create temp table people as select gen_random_uuid() id from generate_series(1,2000);
create temp table tester as select '75000000-0000-0000-0000-000000000001'::uuid id;

select is(rollout_for((select id from tester)),
  '{"paid_chat": false, "play_checkout": false, "course_paywall": false, "referral_claims": false}'::jsonb,
  'everything starts off');

-- Buckets are stable and spread evenly.
select is(private.rollout_bucket((select id from tester)),private.rollout_bucket((select id from tester)),'an account keeps its bucket');
select ok((select min(private.rollout_bucket(id)) >= 0 and max(private.rollout_bucket(id)) <= 99 from people),'buckets are 0–99');
select ok((select count(*) filter (where private.rollout_bucket(id) < 10) between 120 and 280 from people),'about 10% fall under 10');

-- Internal testers first.
select throws_ok($$select set_rollout('play_checkout',0,array['75000000-0000-0000-0000-000000000001'::uuid],'','testers')$$,'22023',null,'an operator is required');
select set_rollout('play_checkout',0,array['75000000-0000-0000-0000-000000000001'::uuid],'ops@example','internal testers');
select ok((rollout_for((select id from tester))->>'play_checkout')::boolean,'a tester is in the cohort at 0%');
select ok(not exists (select 1 from people where (rollout_for(id)->>'play_checkout')::boolean),'nobody else is');

-- No paywall or paid chat for anyone who cannot buy.
select throws_ok($$select set_rollout('course_paywall',10,'{}','ops@example','too early')$$,'22023',null,'a paywall wider than checkout is refused');
select throws_ok($$select set_rollout('paid_chat',0,array[gen_random_uuid()],'ops@example','someone else')$$,'22023',null,'paid chat for a non-tester is refused');
select lives_ok($$select set_rollout('course_paywall',0,array['75000000-0000-0000-0000-000000000001'::uuid],'ops@example','testers')$$,'the paywall follows checkout');

select throws_ok($$select set_rollout('play_checkout',10,'{}','ops@example','dropping testers')$$,'22023',null,'checkout cannot drop testers who have the paywall');

-- Widening keeps earlier members: 10% is a subset of 50%.
select set_rollout('play_checkout',10,array['75000000-0000-0000-0000-000000000001'::uuid],'ops@example','10% cohort');
create temp table at10 as select id from people where (rollout_for(id)->>'play_checkout')::boolean;
select set_rollout('play_checkout',50,array['75000000-0000-0000-0000-000000000001'::uuid],'ops@example','50% cohort');
select ok(not exists (select id from at10 except select id from people where (rollout_for(id)->>'play_checkout')::boolean),'widening never drops an account');
select ok((select count(*) from people where (rollout_for(id)->>'play_checkout')::boolean) between 850 and 1150,'about half at 50%');
select throws_ok($$select set_rollout('course_paywall',60,array['75000000-0000-0000-0000-000000000001'::uuid],'ops@example','wider than checkout')$$,'22023',null,'the paywall cannot pass checkout');
select is((select count(*)::integer from monetization_private.rollout_changes),4,'every accepted change is audited; refused ones leave nothing');
select throws_ok($$select set_rollout('ads',10,'{}','ops@example','no')$$,'22023',null,'unknown features are refused');

-- Alert delivery is throttled per alert.
select is(claim_alert_deliveries(array['billing_jobs_dead','verification_slow','billing_jobs_dead'],60),
  array['billing_jobs_dead','verification_slow'],'new alerts are sent once each');
select is(claim_alert_deliveries(array['billing_jobs_dead','referral_queue_slow'],60),array['referral_queue_slow'],
  'an alert sent within the hour waits');
update monetization_private.alert_deliveries set last_sent_at=now()-interval '2 hours' where alert='billing_jobs_dead';
select is(claim_alert_deliveries(array['billing_jobs_dead'],60),array['billing_jobs_dead'],'after the hour it is sent again');
select is(claim_alert_deliveries(array['Bad Name; drop'],60),'{}'::text[],'odd names are ignored');

select * from finish();
rollback;
