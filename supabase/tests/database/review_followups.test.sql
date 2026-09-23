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

select ok(not has_function_privilege('service_role','private.referral_trial_due(uuid)','EXECUTE'),'the trial rule is internal');
select ok(not has_function_privilege('authenticated','public.enabled_billing_products()','EXECUTE'),'clients cannot read product switches directly');

update monetization_private.referral_campaigns set enabled=true,processing_paused=false,
  starts_at=now()-interval '1 day',claim_closes_at=now()+interval '1 month',ends_at=now()+interval '2 months';

-- Two people cannot invite each other.
select pg_temp.actor('a'); select pg_temp.actor('b');
select pg_temp.claim('b','a');
select is(claim_referral(pg_temp.uid('a'),'a1-referral-v1',pg_temp.code('b'))->>'code','referral_ineligible','the invited friend''s code cannot be used by their inviter');
select is((select count(*)::integer from monetization_private.referral_claims where referee_id=pg_temp.uid('a')),0,'no second claim is made');

-- The trial length is the campaign's.
update monetization_private.referral_campaigns set referee_trial_days=21;
select is(get_referral_status(pg_temp.uid('b'),0,20)->>'trial_days','21','the app is told the campaign''s length');
create temp table c1 as select id from monetization_private.referral_claims where referee_id=pg_temp.uid('b');
select pg_temp.unit((select id from c1),1); select pg_temp.unit((select id from c1),2);
select is((pg_temp.trial_until('b')::date - now()::date),21,'and the trial lasts that long');
update monetization_private.referral_campaigns set referee_trial_days=14;

-- An inviter who deletes their account does not take the friend's trial.
select pg_temp.actor('gone'); select pg_temp.actor('left');
create temp table c2 as select pg_temp.claim('left','gone') id;
select pg_temp.unit((select id from c2),1);
delete from auth.users where id=pg_temp.uid('gone');
select is((select referrer_id from monetization_private.referral_claims where id=(select id from c2)),null,'the claim has no inviter now');
select ok(issue_referral_challenge(pg_temp.uid('left'),(select id from c2),repeat('d',64)) ? 'nonce','the friend can still send lesson results');
select pg_temp.unit((select id from c2),2);
select ok(pg_temp.trial_until('left') is not null,'and still gets their trial');

-- Nor does an inviter who is no longer linked.
select pg_temp.actor('unlinked'); select pg_temp.actor('friend');
create temp table c3 as select pg_temp.claim('friend','unlinked') id;
delete from auth.identities where user_id=pg_temp.uid('unlinked');
update auth.users set is_anonymous=true where id=pg_temp.uid('unlinked');
select pg_temp.unit((select id from c3),1); select pg_temp.unit((select id from c3),2);
select ok(pg_temp.trial_until('friend') is not null,'the friend gets their trial');
select is((select status from monetization_private.referral_milestones where claim_id=(select id from c3) and ordinal=2),'waiting_identity','the inviter''s reward waits for them to link');
select is((select count(*)::integer from public.course_unit_grants where user_id=pg_temp.uid('unlinked')),0,'and is not granted meanwhile');

-- The worker picks up a friend owed a trial once processing resumes, and
-- never picks a claim whose trial is settled.
select pg_temp.actor('owner3'); select pg_temp.actor('friend3');
create temp table c4 as select pg_temp.claim('friend3','owner3') id;
update monetization_private.referral_campaigns set processing_paused=true;
select pg_temp.unit((select id from c4),1); select pg_temp.unit((select id from c4),2);
select is(pg_temp.trial_until('friend3'),null,'paused: no trial yet');
select ok(not ((select id from c4) in (select referral_claims_to_process(200))),'nothing to do while paused');
update monetization_private.referral_campaigns set processing_paused=false;
select ok((select id from c4) in (select referral_claims_to_process(200)),'the worker picks it up after resuming');
select process_referral_claim((select id from c4));
select ok(pg_temp.trial_until('friend3') is not null,'and the friend gets the trial');
select ok(not exists (select 1 from referral_claims_to_process(200) x where x in
  ((select id from c1),(select id from c2),(select id from c3),(select id from c4))),'settled trials are not picked again');

-- Products on sale.
select is(enabled_billing_products(),'{}'::text[],'nothing is on sale by default');
select set_billing_product_enabled('czechify_core',true);
select is(enabled_billing_products(),array['czechify_core'],'only switched-on products are named');

select * from finish();
rollback;
