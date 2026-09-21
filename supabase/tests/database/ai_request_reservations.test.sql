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
  insert into actors values(p_label,u); return u;
end $$;
create function pg_temp.uid(p_label text) returns uuid language sql as $$ select id from actors where label=p_label $$;
create function pg_temp.digest(p_text text) returns text language sql as $$ select encode(extensions.digest(p_text,'sha256'),'hex') $$;
-- reserve with the default limits: 3 turns, 2 summaries, 1 new turn, 90 s lease.
create function pg_temp.reserve(p_label text,p_request uuid,p_op text,p_payload text,p_session uuid)
returns jsonb language sql as $$
  select reserve_ai_request(pg_temp.uid(p_label),p_request,p_op,pg_temp.digest(p_payload),p_session,3,2,1,90) $$;

select pg_temp.actor('buyer'); select pg_temp.actor('staff'); select pg_temp.actor('referrer'); select pg_temp.actor('free');
insert into public.monetization_accounts(user_id) select id from actors;
insert into monetization_private.feature_entitlements(user_id,feature,source_key,state,valid_until,verified_at)
  values(pg_temp.uid('buyer'),'ai_chat','play:ai','active',now()+interval '20 days',now()),
        (pg_temp.uid('referrer'),'core','play:core','active',now()+interval '20 days',now());
insert into public.curriculum_entitlements(user_id,unlock_all,expires_at) values(pg_temp.uid('staff'),true,null);

-- Privileges: only the proxy's service role reaches any of this.
select ok(not has_function_privilege('authenticated','public.reserve_ai_request(uuid,uuid,text,text,uuid,integer,integer,integer,integer)','EXECUTE'),'clients cannot reserve');
select ok(not has_function_privilege('authenticated','public.has_ai_chat_access(uuid)','EXECUTE'),'clients cannot probe access');
select ok(not has_function_privilege('anon','public.record_ai_spend(bigint)','EXECUTE'),'anonymous role cannot add spend');
select ok(has_function_privilege('service_role','public.complete_ai_request(uuid,uuid,integer,integer,bigint,text,integer)','EXECUTE'),'proxy can complete');
select ok(not has_table_privilege('service_role','monetization_private.ai_request_reservations','SELECT'),'reservations are reached only through functions');

-- AI access: a verified ai_chat purchase only.
select ok(has_ai_chat_access(pg_temp.uid('buyer')),'AI buyer has chat');
select ok(not has_ai_chat_access(pg_temp.uid('staff')),'staff course override is not AI');
select ok(not has_ai_chat_access(pg_temp.uid('referrer')),'Core is not AI');
update monetization_private.feature_entitlements set valid_until=now()-interval '1 minute' where user_id=pg_temp.uid('buyer');
select ok(not has_ai_chat_access(pg_temp.uid('buyer')),'expired AI is not AI');
update monetization_private.feature_entitlements set valid_until=now()+interval '20 days',state='on_hold' where user_id=pg_temp.uid('buyer');
select ok(not has_ai_chat_access(pg_temp.uid('buyer')),'account hold stops chat');
update monetization_private.feature_entitlements set state='in_grace_period' where user_id=pg_temp.uid('buyer');
select ok(has_ai_chat_access(pg_temp.uid('buyer')),'grace period keeps chat');

-- A reserved turn, replayed on retry, never reserved twice.
create temp table ids(label text primary key,id uuid);
insert into ids values('s1',gen_random_uuid()),('t1',gen_random_uuid()),('t2',gen_random_uuid()),('t3',gen_random_uuid()),
  ('t4',gen_random_uuid()),('sum1',gen_random_uuid()),('sum2',gen_random_uuid()),('lost',gen_random_uuid());
create function pg_temp.id(p_label text) returns uuid language sql as $$ select id from ids where label=p_label $$;

select is(pg_temp.reserve('buyer',pg_temp.id('t1'),'conversation','hello',pg_temp.id('s1'))->>'outcome','reserved','first turn reserves');
select is(pg_temp.reserve('buyer',pg_temp.id('t1'),'conversation','hello',pg_temp.id('s1'))->>'outcome','in_flight','retry while running is told to wait');
select is(pg_temp.reserve('buyer',pg_temp.id('t1'),'conversation','other',pg_temp.id('s1'))->>'outcome','conflict','same ID, different payload conflicts');
select is(pg_temp.reserve('buyer',pg_temp.id('t1'),'conversation_summary','hello',pg_temp.id('s1'))->>'outcome','conflict','same ID, different operation conflicts');
select is((select conversation_count from monetization_private.ai_daily_allowance where user_id=pg_temp.uid('buyer')),1,'one turn counted');
select ok(complete_ai_request(pg_temp.uid('buyer'),pg_temp.id('t1'),100,50,700,'v1.sealed',86400),'turn completes');
select ok(not complete_ai_request(pg_temp.uid('buyer'),pg_temp.id('t1'),100,50,700,'v1.again',86400),'a turn completes once');
select is(pg_temp.reserve('buyer',pg_temp.id('t1'),'conversation','hello',pg_temp.id('s1'))->>'replay_sealed','v1.sealed','retry after completion replays');
select is((select conversation_count from monetization_private.ai_daily_allowance where user_id=pg_temp.uid('buyer')),1,'replay reserves nothing');
select is((select cost_micros from monetization_private.ai_project_spend),700::bigint,'cost reaches project spend');
select is((select turns from monetization_private.ai_chat_sessions where session_id=pg_temp.id('s1')),1,'the session knows one turn');
select is(pg_temp.reserve('free',pg_temp.id('t1'),'conversation','hello',pg_temp.id('s1'))->>'outcome','reserved','replay is account-scoped');

-- Summaries need a server-known session with a new turn since the last one.
select is(pg_temp.reserve('buyer',pg_temp.id('sum1'),'conversation_summary','sum',gen_random_uuid())->>'outcome','summary_not_due','unknown session cannot summarize');
select is(pg_temp.reserve('buyer',pg_temp.id('sum1'),'conversation_summary','sum',pg_temp.id('s1'))->>'outcome','reserved','a session with a new turn can summarize');
select is(pg_temp.reserve('buyer',pg_temp.id('sum2'),'conversation_summary','sum2',pg_temp.id('s1'))->>'outcome','summary_not_due','in-flight summary reserves the same turns');
select ok(release_ai_request(pg_temp.uid('buyer'),pg_temp.id('sum1'),0),'definite summary failure releases eligibility');
select is(pg_temp.reserve('buyer',pg_temp.id('sum1'),'conversation_summary','sum',pg_temp.id('s1'))->>'outcome','reserved','failed summary may retry');
select ok(complete_ai_request(pg_temp.uid('buyer'),pg_temp.id('sum1'),10,5,20,'v1.sum',86400),'summary completes');
select is(pg_temp.reserve('buyer',pg_temp.id('sum2'),'conversation_summary','sum2',pg_temp.id('s1'))->>'outcome','summary_not_due','no new turn, no second summary');
select is((select conversation_count from monetization_private.ai_daily_allowance where user_id=pg_temp.uid('buyer')),1,'summaries do not spend turns');

-- A definite failure refunds and may be retried; an unknown outcome never is.
select is(pg_temp.reserve('buyer',pg_temp.id('t2'),'conversation','two',pg_temp.id('s1'))->>'outcome','reserved','second turn reserves');
select ok(release_ai_request(pg_temp.uid('buyer'),pg_temp.id('t2'),30),'failed turn is released');
select is((select conversation_count from monetization_private.ai_daily_allowance where user_id=pg_temp.uid('buyer')),1,'release refunds the turn');
select is((select cost_micros from monetization_private.ai_project_spend),750::bigint,'a failure still records what it cost');
select is(pg_temp.reserve('buyer',pg_temp.id('t2'),'conversation','two',pg_temp.id('s1'))->>'outcome','reserved','a released request may retry');
select ok(abandon_ai_request(pg_temp.uid('buyer'),pg_temp.id('t2')),'unknown outcome abandons');
select is(pg_temp.reserve('buyer',pg_temp.id('t2'),'conversation','two',pg_temp.id('s1'))->>'outcome','result_unavailable','an unknown outcome is never redispatched');
select is((select conversation_count from monetization_private.ai_daily_allowance where user_id=pg_temp.uid('buyer')),2,'an unknown outcome stays charged');

-- A lease that runs out without a report becomes unavailable, not retried.
select is(pg_temp.reserve('buyer',pg_temp.id('lost'),'conversation','lost',pg_temp.id('s1'))->>'outcome','reserved','third turn reserves');
update monetization_private.ai_request_reservations set lease_expires_at=now()-interval '1 second' where request_id=pg_temp.id('lost');
select is(pg_temp.reserve('buyer',pg_temp.id('lost'),'conversation','lost',pg_temp.id('s1'))->>'outcome','result_unavailable','an expired lease is not a second call');
select ok(not complete_ai_request(pg_temp.uid('buyer'),pg_temp.id('lost'),1,1,1,'late',86400),'a late completion cannot revive it');

-- The daily allowance is a hard stop.
select is(pg_temp.reserve('buyer',pg_temp.id('t3'),'conversation','three',pg_temp.id('s1'))->>'outcome','quota_exceeded','the fourth turn exceeds three');
select ok((pg_temp.reserve('buyer',pg_temp.id('t4'),'conversation','four',pg_temp.id('s1'))->>'resets_at')::timestamptz > now(),'the refusal says when it resets');
select is((select conversation_count from monetization_private.ai_daily_allowance where user_id=pg_temp.uid('buyer')),3,'nothing counted past the limit');
select is((get_ai_allowance(pg_temp.uid('buyer'),3)->>'remaining')::integer,0,'none left today');
select throws_ok($$select reserve_ai_request(gen_random_uuid(),gen_random_uuid(),'grammar_check',repeat('a',64),gen_random_uuid(),3,2,1,90)$$,'22023',null,'course operations do not reserve chat');

-- Spend ceiling trips once.
select is(ai_spend_ceiling_reached(1000)->>'reached','false','below the ceiling');
select is(ai_spend_ceiling_reached(750)->>'newly_tripped','true','first request at the ceiling records the trip');
select is(ai_spend_ceiling_reached(750)->>'newly_tripped','false','later requests do not record it again');

-- Retention: replay content goes after its expiry, tombstones after seven days.
update monetization_private.ai_request_reservations set replay_expires_at=now()-interval '1 second' where request_id=pg_temp.id('t1') and user_id=pg_temp.uid('buyer');
select is((cleanup_ai_request_records()->>'replay_cleared')::integer,1,'expired replay content cleared');
select is(pg_temp.reserve('buyer',pg_temp.id('t1'),'conversation','hello',pg_temp.id('s1'))->>'outcome','result_unavailable','after replay expiry the tombstone still prevents a second call');
update monetization_private.ai_request_reservations set created_at=now()-interval '8 days' where user_id=pg_temp.uid('buyer');
select ok((cleanup_ai_request_records()->>'tombstones_removed')::integer >= 1,'old tombstones removed');

select * from finish();
rollback;
