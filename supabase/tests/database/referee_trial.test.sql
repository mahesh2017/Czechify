begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path=public;
select no_plan();

-- Helpers as in referral_foundation.test.sql: an account needs a join date,
-- and lessons qualify only through accepted receipts.
create temp table actors(label text primary key,id uuid not null);
create function pg_temp.actor(p_label text,p_anon boolean default false,p_age interval default interval '1 hour')
returns uuid language plpgsql as $$
declare u uuid:=gen_random_uuid();
begin
  insert into auth.users(id,is_anonymous,created_at) values(u,p_anon,now()-p_age);
  if not p_anon then insert into auth.identities(user_id,provider,provider_id,identity_data) values(u,'email',u::text,'{}'); end if;
  insert into actors values(p_label,u); return u;
end $$;
create function pg_temp.uid(p_label text) returns uuid language sql as $$ select id from actors where label=p_label $$;
create function pg_temp.code(p_label text) returns text language sql as $$
  select get_or_create_referral_code(pg_temp.uid(p_label),'a1-referral-v1')->>'referral_code' $$;
create function pg_temp.claim(p_friend text,p_owner text) returns uuid language sql as $$
  select (claim_referral(pg_temp.uid(p_friend),'a1-referral-v1',pg_temp.code(p_owner))->>'claim_id')::uuid $$;
create function pg_temp.receipt(p_claim uuid,p_lesson integer,p_attempt uuid default gen_random_uuid()) returns jsonb language sql as $$
  select jsonb_build_object('schema_version',1,'claim_id',p_claim,'campaign_id','a1-referral-v1','content_revision',25,
    'lesson_id',p_lesson,'attempt_id',p_attempt,'started_at_client',now(),'completed_at_client',now(),
    'initial_coverage',(select jsonb_agg(jsonb_build_object('exercise_id',e,'interaction',
      case when e=any(m.teaching_ids) then 'teaching_acknowledged' else 'answered_incorrectly' end) order by e)
      from unnest(m.exercise_ids) e)) from monetization_private.referral_manifest_lessons m where lesson_id=p_lesson $$;
create function pg_temp.unit(p_claim uuid,p_unit integer) returns void language plpgsql as $$
declare l integer; r jsonb; u uuid; result jsonb;
begin
  select referee_id into u from monetization_private.referral_claims where id=p_claim;
  for l in select lesson_id from monetization_private.referral_manifest_lessons where unit_id=p_unit order by lesson_id loop
    r:=pg_temp.receipt(p_claim,l);
    result:=accept_verified_referral_receipt(u,p_claim,r,encode(extensions.digest(r::text,'sha256'),'hex'),'verified');
    if result->>'status'<>'accepted' then raise exception 'Receipt failed: %',result; end if;
  end loop;
end $$;
create function pg_temp.trial_until(p_label text) returns timestamptz language sql as $$
  select max(ends_at) from public.course_access_windows
  where user_id=pg_temp.uid(p_label) and kind='referral_trial' $$;

select ok(not has_function_privilege('service_role','private.grant_referral_trial(uuid,uuid,integer)','EXECUTE'),'the trial is granted only by claim processing');

update monetization_private.referral_campaigns set enabled=true,processing_paused=false,
  starts_at=now()-interval '1 day',claim_closes_at=now()+interval '1 month',ends_at=now()+interval '2 months';
select pg_temp.actor('owner'); select pg_temp.actor('friend'); select pg_temp.actor('owner2');
select pg_temp.actor('friend2'); select pg_temp.actor('full'); select pg_temp.actor('friend3');
select pg_temp.actor('held'); select pg_temp.actor('refused');
create temp table claim1 as select pg_temp.claim('friend','owner') id;

-- One unit is not enough: the trial comes with the second.
select pg_temp.unit((select id from claim1),1);
select process_referral_claim((select id from claim1));
select is(pg_temp.trial_until('friend'),null,'no trial after the first unit');
select is((select count(*)::integer from public.course_unit_grants where user_id=pg_temp.uid('owner')),1,'the inviter earns their first unit');

select pg_temp.unit((select id from claim1),2);
select process_referral_claim((select id from claim1));
create temp table after as select pg_temp.trial_until('friend') ends;
select ok((select ends from after) is not null,'finishing the free units starts the friend''s trial');
select is((select (ends::date - now()::date) from after),14,'it runs fourteen days');
select is((select kind from public.course_access_windows where user_id=pg_temp.uid('friend')),'referral_trial','it is recorded as a trial, not existing-user grace');
select is((select count(*)::integer from public.course_unit_grants where user_id=pg_temp.uid('friend')),0,'the friend keeps no permanent unit');
select is((select count(*)::integer from public.course_unit_grants where user_id=pg_temp.uid('owner')),2,'the inviter earns their second unit');

-- What the app is told.
select is((get_monetization_snapshot(pg_temp.uid('friend'))->>'referral_trial_until')::timestamptz,(select ends from after),'the signed snapshot carries the trial');
select is(get_monetization_snapshot(pg_temp.uid('friend'))->>'migration_grace_until',null,'a trial is not reported as existing-user grace');
select is((get_referral_status(pg_temp.uid('friend'),0,20)->'own_claim'->>'trial_until')::timestamptz,(select ends from after),'the invite screen can say when it ends');
select is(get_referral_status(pg_temp.uid('friend'),0,20)->>'trial_days','14','the app is told the length the server grants');
select is(get_referral_status(pg_temp.uid('owner'),0,20)->'own_claim','null'::jsonb,'the inviter has no claim of their own');

-- Processing again never extends it; a second invitation gives no second trial.
select process_referral_claim((select id from claim1));
select is(pg_temp.trial_until('friend'),(select ends from after),'reprocessing the same claim changes nothing');
create temp table claim2 as select pg_temp.claim('friend2','owner2') id;
select pg_temp.unit((select id from claim2),1); select pg_temp.unit((select id from claim2),2);
select process_referral_claim((select id from claim2));
select ok(pg_temp.trial_until('friend2') is not null,'the second friend gets their own trial');
update public.course_access_windows set starts_at=now()-interval '30 days',ends_at=now()-interval '16 days'
  where user_id=pg_temp.uid('friend2');
select process_referral_claim((select id from claim2));
select ok(pg_temp.trial_until('friend2')<now(),'an account that already had a trial never gets another');
select is(get_monetization_snapshot(pg_temp.uid('friend2'))->>'referral_trial_until',null,'an ended trial opens nothing');

-- The inviter's cap does not reach the friend.
select set_course_unit_grant(pg_temp.uid('full'),u,'referral','fill:'||u,'a1-referral-v1',false,'test fill')
  from unnest(array[3,4,5,6,7,8,9,10,11,12,13,14,15,28,30]) u;
create temp table claim3 as select pg_temp.claim('friend3','full') id;
select pg_temp.unit((select id from claim3),1); select pg_temp.unit((select id from claim3),2);
select process_referral_claim((select id from claim3));
select is((select outcome from monetization_private.referral_reward_events where claim_id=(select id from claim3) and ordinal=2),'cap_reached','the inviter is at the cap');
select ok(pg_temp.trial_until('friend3') is not null,'their friend still gets the trial');

-- Held and refused invitations give nothing to either side.
create temp table claim4 as select pg_temp.claim('held','owner') id;
-- Paused before the learning, or accepting the receipts would already award it.
update monetization_private.referral_campaigns set processing_paused=true;
select pg_temp.unit((select id from claim4),1); select pg_temp.unit((select id from claim4),2);
select process_referral_claim((select id from claim4));
select is(pg_temp.trial_until('held'),null,'a paused campaign holds the trial too');
update monetization_private.referral_campaigns set processing_paused=false;
select process_referral_claim((select id from claim4));
select ok(pg_temp.trial_until('held') is not null,'resuming releases it');

create temp table claim5 as select pg_temp.claim('refused','owner2') id;
update monetization_private.referral_claims set risk_state='rejected' where id=(select id from claim5);
select pg_temp.unit((select id from claim5),1); select pg_temp.unit((select id from claim5),2);
select process_referral_claim((select id from claim5));
select is(pg_temp.trial_until('refused'),null,'a rejected invitation gives no trial');

select * from finish();
rollback;
