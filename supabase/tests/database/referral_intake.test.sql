begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path=public;
select no_plan();

create temp table actors(label text primary key,id uuid not null);
create function pg_temp.actor(p_label text,p_anon boolean default false)
returns uuid language plpgsql as $$
declare u uuid:=gen_random_uuid();
begin
  insert into auth.users(id,is_anonymous,created_at) values(u,p_anon,now()-interval '1 hour');
  if not p_anon then insert into auth.identities(user_id,provider,provider_id,identity_data) values(u,'email',u::text,'{}'); end if;
  insert into actors values(p_label,u); return u;
end $$;
create function pg_temp.uid(p_label text) returns uuid language sql as $$ select id from actors where label=p_label $$;
create function pg_temp.receipt(p_claim uuid,p_lesson integer,p_attempt uuid default gen_random_uuid()) returns jsonb language sql as $$
  select jsonb_build_object('schema_version',1,'claim_id',p_claim,'campaign_id','a1-referral-v1','content_revision',25,
    'lesson_id',p_lesson,'attempt_id',p_attempt,'started_at_client',now(),'completed_at_client',now(),
    'initial_coverage',(select jsonb_agg(jsonb_build_object('exercise_id',e,'interaction',
      case when e=any(m.teaching_ids) then 'teaching_acknowledged' else 'answered_correctly' end) order by e)
      from unnest(m.exercise_ids) e)) from monetization_private.referral_manifest_lessons m where lesson_id=p_lesson $$;
-- Challenge, then submit with it: the API's two steps.
create function pg_temp.submit(p_label text,p_claim uuid,p_lesson integer) returns jsonb language plpgsql as $$
declare r jsonb:=pg_temp.receipt(p_claim,p_lesson); d text:=encode(extensions.digest(r::text,'sha256'),'hex'); n text;
begin
  n:=issue_referral_challenge(pg_temp.uid(p_label),p_claim,d)->>'nonce';
  return submit_referral_receipt(pg_temp.uid(p_label),p_claim,n,r,d,'verified');
end $$;

select pg_temp.actor('owner'); select pg_temp.actor('friend'); select pg_temp.actor('stranger'); select pg_temp.actor('anon',true);
select throws_ok($$select set_referral_campaign('a1-referral-v1',true,false,null,null,null)$$,'23514',null,'an enabled campaign needs its window');
select throws_ok($$select set_referral_campaign('other',false,true,null,null,null)$$,'22023',null,'unknown campaign refused');
select ok(not has_function_privilege('authenticated','public.set_referral_campaign(text,boolean,boolean,timestamptz,timestamptz,timestamptz)','EXECUTE'),'clients cannot open a campaign');
select is(set_referral_campaign('a1-referral-v1',true,false,now()-interval '1 day',now()+interval '1 month',now()+interval '2 months')->>'enabled','true','operator opens the campaign');
select is((select reward_unit_order from monetization_private.referral_campaigns),array[3,4,5,6,7,8,9,10,11,12,13,14,15,28,30],'reward order untouched');
create temp table codes as select get_or_create_referral_code(pg_temp.uid('owner'),'a1-referral-v1')->>'referral_code' as code;
create temp table claims(label text primary key,id uuid);
insert into claims select 'friend',(claim_referral(pg_temp.uid('friend'),'a1-referral-v1',(select code from codes))->>'claim_id')::uuid;
insert into claims select 'anon',(claim_referral(pg_temp.uid('anon'),'a1-referral-v1',(select code from codes))->>'claim_id')::uuid;
-- One transaction gives both claims the same now(); make the order explicit.
update monetization_private.referral_claims set created_at=now()+interval '1 second' where id=(select id from claims where label='anon');

select ok(not has_function_privilege('authenticated','public.submit_referral_receipt(uuid,uuid,text,jsonb,text,text)','EXECUTE'),'clients cannot submit with an asserted verdict');
select ok(not has_function_privilege('anon','public.issue_referral_challenge(uuid,uuid,text)','EXECUTE'),'anonymous role cannot mint challenges');
select ok(not has_function_privilege('service_role','private.referral_milestone_view(uuid,boolean)','EXECUTE'),'status helper is internal');
select ok(has_function_privilege('service_role','public.get_referral_status(uuid,integer,integer)','EXECUTE'),'API can read status');

-- Challenges belong to one referee, claim and receipt; only the digest is kept.
create temp table ch as select pg_temp.receipt((select id from claims where label='friend'),100) r;
alter table ch add column d text; update ch set d=encode(extensions.digest(r::text,'sha256'),'hex');
alter table ch add column n text;
update ch set n=issue_referral_challenge(pg_temp.uid('friend'),(select id from claims where label='friend'),d)->>'nonce';
select matches((select n from ch),'^[0-9a-f]{64}$','nonce is 256 random bits');
select is((select count(*)::integer from monetization_private.integrity_challenges where nonce_digest=(select n from ch)),0,'raw nonce is never stored');
select is(issue_referral_challenge(pg_temp.uid('stranger'),(select id from claims where label='friend'),(select d from ch))->>'code','referral_unavailable','only the referee gets a challenge');
select is(issue_referral_challenge(pg_temp.uid('friend'),(select id from claims where label='friend'),'nothex')->>'code','invalid_request','digest must be SHA-256 hex');

-- A challenge is bound and single use; consumption and receipt commit together.
select is(submit_referral_receipt(pg_temp.uid('stranger'),(select id from claims where label='friend'),(select n from ch),(select r from ch),(select d from ch),'verified')->>'code','challenge_invalid','another account cannot use the challenge');
select is(submit_referral_receipt(pg_temp.uid('friend'),(select id from claims where label='friend'),(select n from ch),(select r from ch),repeat('b',64),'verified')->>'code','challenge_invalid','challenge is bound to its receipt digest');
select is((select consumed_at from monetization_private.integrity_challenges),null,'refused uses leave the challenge unconsumed');
create temp table first_submit as select submit_referral_receipt(pg_temp.uid('friend'),(select id from claims where label='friend'),(select n from ch),(select r from ch),(select d from ch),'verified') v;
select is((select v->>'status' from first_submit),'accepted','bound challenge stores the receipt');
select is((select receipt_id::text from monetization_private.integrity_challenges),(select v->>'receipt_id' from first_submit),'challenge records the receipt it admitted');
select is(submit_referral_receipt(pg_temp.uid('friend'),(select id from claims where label='friend'),(select n from ch),(select r from ch),(select d from ch),'verified')->>'code','challenge_invalid','a used challenge cannot admit anything again');

-- A committed receipt is found again without a challenge.
select is(find_referral_receipt(pg_temp.uid('friend'),(select id from claims where label='friend'),((select r from ch)->>'attempt_id')::uuid,(select d from ch))->>'receipt_id',(select v->>'receipt_id' from first_submit),'replay returns the original receipt');
select is(find_referral_receipt(pg_temp.uid('friend'),(select id from claims where label='friend'),((select r from ch)->>'attempt_id')::uuid,repeat('c',64))->>'code','idempotency_conflict','same attempt with other content conflicts');
select is(find_referral_receipt(pg_temp.uid('friend'),(select id from claims where label='friend'),gen_random_uuid(),(select d from ch)),null,'unknown attempt has no replay');

-- A failed intake still spends the challenge; an expired one admits nothing.
create temp table bad as select pg_temp.receipt((select id from claims where label='friend'),101) r;
update bad set r=jsonb_set(r,'{initial_coverage}','[]'::jsonb);
alter table bad add column d text; update bad set d=encode(extensions.digest(r::text,'sha256'),'hex');
alter table bad add column n text; update bad set n=issue_referral_challenge(pg_temp.uid('friend'),(select id from claims where label='friend'),d)->>'nonce';
select is(submit_referral_receipt(pg_temp.uid('friend'),(select id from claims where label='friend'),(select n from bad),(select r from bad),(select d from bad),'verified')->>'code','invalid_receipt','invalid evidence is refused');
select isnt((select consumed_at from monetization_private.integrity_challenges where receipt_digest=(select d from bad)),null,'refused evidence still spends its challenge');
update monetization_private.integrity_challenges set created_at=now()-interval '20 minutes',expires_at=now()-interval '10 minutes',consumed_at=null where receipt_digest=(select d from bad);
select is(submit_referral_receipt(pg_temp.uid('friend'),(select id from claims where label='friend'),(select n from bad),(select r from bad),(select d from bad),'verified')->>'code','challenge_invalid','expired challenge admits nothing');

-- Status: own claim for the invitee, numbered friends for the referrer.
select pg_temp.submit('friend',(select id from claims where label='friend'),l) from unnest(array[101,102,103]) l;
select is(get_referral_status(pg_temp.uid('owner'),0,20)->>'units_earned','1','first unit earned after unit 1');
select is(get_referral_status(pg_temp.uid('owner'),0,20)->>'next_reward_unit','4','next reward is unit 4');
select is(get_referral_status(pg_temp.uid('owner'),0,20)->>'referral_code',(select code from codes),'referrer sees their code');
select is(get_referral_status(pg_temp.uid('owner'),0,20)->'friends'->0,
  '{"friend":1,"milestones":[{"ordinal":1,"status":"reward_granted"},{"ordinal":2,"status":"waiting_for_learning"}]}'::jsonb,'friend shown by number and milestone only');
select is(get_referral_status(pg_temp.uid('owner'),0,20)->'friends'->1->'milestones'->0->>'status','waiting_for_learning','second friend not started');
select ok(not (get_referral_status(pg_temp.uid('owner'),0,20)::text ~ (select id::text from actors where label='friend')),'referrer never sees the friend''s account ID');
select is(get_referral_status(pg_temp.uid('friend'),0,20)->'own_claim'->>'lessons_completed','4','invitee sees their own progress');
select is(get_referral_status(pg_temp.uid('owner'),0,1)->>'next_cursor','1','page of one points to the next friend');
select is(get_referral_status(pg_temp.uid('owner'),1,1)->'friends'->0->>'friend','2','cursor continues after friend 1');
select is(get_referral_status(pg_temp.uid('owner'),1,1)->>'next_cursor',null,'last page has no cursor');
select is(jsonb_array_length(get_referral_status(pg_temp.uid('stranger'),0,20)->'friends'),0,'another account sees nobody');

-- Review is visible to the invitee only.
update monetization_private.referral_claims set risk_state='needs_review' where id=(select id from claims where label='anon');
insert into monetization_private.referral_milestones(claim_id,ordinal,status) values((select id from claims where label='anon'),1,'needs_review');
select is(get_referral_status(pg_temp.uid('anon'),0,20)->'own_claim'->'milestones'->0->>'status','needs_review','invitee sees review, to contact support');
select is(get_referral_status(pg_temp.uid('owner'),0,20)->'friends'->1->'milestones'->0->>'status','verification_pending','referrer sees only pending');

-- Worker selection: identity-held after linking, paused-then-resumed.
update monetization_private.referral_milestones set status='waiting_identity' where claim_id=(select id from claims where label='anon');
update monetization_private.referral_claims set risk_state='clear' where id=(select id from claims where label='anon');
select ok(not ((select id from claims where label='anon') in (select referral_claims_to_process(50))),'anonymous invitee stays held');
update auth.users set is_anonymous=false where id=pg_temp.uid('anon');
insert into auth.identities(user_id,provider,provider_id,identity_data) values(pg_temp.uid('anon'),'email',pg_temp.uid('anon')::text,'{}');
select ok((select id from claims where label='anon') in (select referral_claims_to_process(50)),'linked invitee becomes processable');
update monetization_private.referral_milestones set status='verification_pending' where claim_id=(select id from claims where label='anon');
update monetization_private.referral_campaigns set processing_paused=true;
select ok(not ((select id from claims where label='anon') in (select referral_claims_to_process(50))),'paused processing selects nothing');
update monetization_private.referral_campaigns set processing_paused=false;
select ok((select id from claims where label='anon') in (select referral_claims_to_process(50)),'resumed processing selects the held claim');

-- Retention.
insert into monetization_private.referral_claim_attempts(actor_id,attempted_at) values(pg_temp.uid('stranger'),now()-interval '2 days');
update monetization_private.integrity_challenges set created_at=now()-interval '3 days',expires_at=now()-interval '2 days'
  where receipt_digest=(select d from bad);
create temp table cleaned as select cleanup_referral_records() v;
select is((select (v->>'claim_attempts')::integer from cleaned),1,'day-old claim attempts removed');
select is((select (v->>'challenges')::integer from cleaned),1,'long-expired challenge removed');
select is((select count(*)::integer from monetization_private.integrity_challenges),4,'the four recent challenges are kept');
select * from finish();
rollback;
