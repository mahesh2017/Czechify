begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path=public;
select no_plan();

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
create function pg_temp.claim(p_friend text,p_owner text default 'owner') returns uuid language sql as $$
  select (claim_referral(pg_temp.uid(p_friend),'a1-referral-v1',pg_temp.code(p_owner))->>'claim_id')::uuid $$;
create function pg_temp.receipt(p_claim uuid,p_lesson integer,p_attempt uuid default gen_random_uuid()) returns jsonb language sql as $$
  select jsonb_build_object('schema_version',1,'claim_id',p_claim,'campaign_id','a1-referral-v1','content_revision',25,
    'lesson_id',p_lesson,'attempt_id',p_attempt,'started_at_client',now(),'completed_at_client',now(),
    'initial_coverage',(select jsonb_agg(jsonb_build_object('exercise_id',e,'interaction',
      case when e=any(m.teaching_ids) then 'teaching_acknowledged' else 'answered_incorrectly' end) order by e)
      from unnest(m.exercise_ids) e)) from monetization_private.referral_manifest_lessons m where lesson_id=p_lesson $$;
create function pg_temp.submit(p_claim uuid,p_lesson integer,p_integrity text default 'verified') returns jsonb language plpgsql as $$
declare r jsonb:=pg_temp.receipt(p_claim,p_lesson); u uuid;
begin
  select referee_id into u from monetization_private.referral_claims where id=p_claim;
  return accept_verified_referral_receipt(u,p_claim,r,encode(extensions.digest(r::text,'sha256'),'hex'),p_integrity);
end $$;
create function pg_temp.unit(p_claim uuid,p_unit integer,p_integrity text default 'verified') returns void language plpgsql as $$
declare l integer; result jsonb;
begin
  for l in select lesson_id from monetization_private.referral_manifest_lessons where unit_id=p_unit order by lesson_id loop
    result:=pg_temp.submit(p_claim,l,p_integrity);
    if result->>'status'<>'accepted' or result->>'status' is null then raise exception 'Receipt failed: %',result; end if;
  end loop;
end $$;

select pg_temp.actor('owner'); select pg_temp.actor('other'); select pg_temp.actor('friend');
select pg_temp.actor('anon',true); select pg_temp.actor('old',false,interval '8 days');
select pg_temp.actor('finished'); select pg_temp.actor('guesser');
select is(get_or_create_referral_code(pg_temp.uid('owner'),'a1-referral-v1')->>'code','campaign_unavailable','campaign ships disabled');
select is(get_or_create_referral_code(pg_temp.uid('anon'),'a1-referral-v1')->>'code','linked_account_required','anonymous learners cannot publish codes');
select ok((select processing_paused from monetization_private.referral_campaigns),'processing ships paused');
select is((select count(*)::integer from monetization_private.referral_manifest_lessons),8,'eight pinned lessons');
select is((select sum(cardinality(exercise_ids))::integer from monetization_private.referral_manifest_lessons),92,'92 authored exercises');
select ok(not has_schema_privilege('authenticated','monetization_private','USAGE'),'no client access to private referral data');
select ok(not has_table_privilege('service_role','monetization_private.referral_reward_events','INSERT'),'service cannot bypass allocation with direct writes');
select ok(not has_function_privilege('authenticated','public.accept_verified_referral_receipt(uuid,uuid,jsonb,text,text)','EXECUTE'),'client cannot assert verified Integrity');
select ok(not has_function_privilege('anon','public.process_referral_claim(uuid)','EXECUTE'),'anonymous role cannot allocate rewards');
select ok(not has_function_privilege('service_role','private.referral_linked(uuid)','EXECUTE'),'identity helper stays internal');
set local role authenticated;
select throws_ok($$select public.process_referral_claim(gen_random_uuid())$$,'42501',null,'actual client RPC call is denied');
reset role;

update monetization_private.referral_campaigns set enabled=true,processing_paused=false,
  starts_at=now()-interval '1 day',claim_closes_at=now()+interval '1 month',ends_at=now()+interval '2 months';
select matches(pg_temp.code('owner'),'^[A-F0-9]{24}$','random opaque code contains no user data');
select is(pg_temp.code('owner'),pg_temp.code('owner'),'code creation is idempotent');
select is(claim_referral(pg_temp.uid('owner'),'a1-referral-v1',pg_temp.code('owner'))->>'code','referral_ineligible','self referral denied');
select is(claim_referral(pg_temp.uid('old'),'a1-referral-v1',pg_temp.code('owner'))->>'code','referral_ineligible','older than seven days denied');
insert into public.lesson_progress(user_id,lesson_id,unit_id,is_completed,device_id)
  select pg_temp.uid('finished'),lesson_id,1,true,'test' from monetization_private.referral_manifest_lessons where unit_id=1;
select is(claim_referral(pg_temp.uid('finished'),'a1-referral-v1',pg_temp.code('owner'))->>'code','referral_ineligible','completed unit 1 before claim denied');
create temp table claims(label text primary key,id uuid);
insert into claims values('friend',pg_temp.claim('friend')),('anon',pg_temp.claim('anon'));
select ok((select id is not null from claims where label='anon'),'anonymous invitee may reserve a claim');
select is(pg_temp.claim('friend'),(select id from claims where label='friend'),'same attribution retry is idempotent');
select is(claim_referral(pg_temp.uid('friend'),'a1-referral-v1',pg_temp.code('other'))->>'code','referral_already_claimed','different referrer cannot replace attribution');
select is((select count(*)::integer from public.course_unit_grants),0,'joining alone earns nothing');
do $$ begin for i in 1..10 loop perform claim_referral(pg_temp.uid('guesser'),'a1-referral-v1','invalid'); end loop; end $$;
select is(claim_referral(pg_temp.uid('guesser'),'a1-referral-v1',pg_temp.code('owner'))->>'code','rate_limited','failed guesses consume claim rate limit');

create temp table receipt_input as select id claim_id,pg_temp.receipt(id,100) receipt from claims where label='friend';
select is(accept_verified_referral_receipt(pg_temp.uid('other'),claim_id,receipt,repeat('a',64),'verified')->>'code','referral_unavailable','receipt belongs only to its referee') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,receipt,repeat('a',64),'rejected')->>'code','integrity_rejected','failed attestation cannot persist evidence') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,jsonb_set(receipt,'{content_revision}','26'),repeat('a',64),'verified')->>'code','content_update_required','unknown manifest revision rejected') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,receipt||'{"extra":true}',repeat('a',64),'verified')->>'code','invalid_receipt','unknown receipt fields rejected') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,jsonb_set(receipt,'{claim_id}','null'),repeat('a',64),'verified')->>'code','invalid_receipt','null claim cannot bypass binding') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,jsonb_set(receipt,'{initial_coverage,0}','1'),repeat('a',64),'verified')->>'code','invalid_receipt','scalar coverage item fails safely') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,jsonb_set(receipt,'{started_at_client}','"infinity"'),repeat('a',64),'verified')->>'code','invalid_receipt','nonfinite diagnostic timestamp rejected') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,jsonb_set(receipt,'{initial_coverage}',(receipt->'initial_coverage')-0),repeat('a',64),'verified')->>'code','invalid_receipt','missing authored exercise rejected') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,jsonb_set(receipt,'{initial_coverage,1}',receipt#>'{initial_coverage,0}'),repeat('a',64),'verified')->>'code','invalid_receipt','duplicate coverage rejected') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,jsonb_set(receipt,'{initial_coverage,2,exercise_id}','999999'),repeat('a',64),'verified')->>'code','invalid_receipt','foreign exercise rejected') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,jsonb_set(receipt,'{initial_coverage,0,interaction}','"answered_correctly"'),repeat('a',64),'verified')->>'code','invalid_receipt','teaching needs explicit acknowledgement') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,jsonb_set(receipt,'{initial_coverage,2,interaction}','"teaching_acknowledged"'),repeat('a',64),'verified')->>'code','invalid_receipt','answered exercise cannot masquerade as teaching') from receipt_input;
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,jsonb_set(receipt,'{initial_coverage,2,interaction}','"skipped"'),repeat('b',64),'verified')->>'status','nonqualifying','skipping persists nonqualifying evidence') from receipt_input;
select is((select count(*)::integer from monetization_private.referral_lesson_qualifications),0,'skipped attempt qualifies nothing');
select is(accept_verified_referral_receipt(pg_temp.uid('friend'),claim_id,receipt,repeat('b',64),'verified')->>'code','idempotency_conflict','same attempt with altered payload conflicts even with same digest') from receipt_input;
select is(pg_temp.submit((select id from claims where label='friend'),100)->>'status','accepted','a new complete attempt can qualify the skipped lesson');
select is((select count(*)::integer from monetization_private.referral_lesson_qualifications),1,'one complete lesson qualifies once');

-- Unit two arrives first; no reward until unit one is complete.
select pg_temp.unit((select id from claims where label='friend'),2);
select is((select count(*)::integer from monetization_private.referral_reward_events),0,'unit two cannot skip milestone one');
select pg_temp.unit((select id from claims where label='friend'),1);
select is((select array_agg(unit_id order by unit_id) from public.course_unit_grants where user_id=pg_temp.uid('owner')),array[3,4],'both completed units grant exactly two permanent units');
select is((select revision::integer from public.monetization_accounts where user_id=pg_temp.uid('owner')),2,'revision changes once per award');
select is((select count(*)::integer from monetization_private.monetization_outbox where user_id=pg_temp.uid('owner')),2,'two atomic access events');
select pg_temp.unit((select id from claims where label='friend'),1);
select pg_temp.unit((select id from claims where label='friend'),2);
select is((select count(*)::integer from monetization_private.referral_reward_events),2,'whole-course replay never adds a third reward');
select is((select count(*)::integer from monetization_private.feature_entitlements),0,'referral grants no Core or AI feature');
select is(get_monetization_snapshot(pg_temp.uid('owner'))->'features'->'ai_chat'->>'state','inactive','signed access keeps AI inactive');

-- Anonymous receipts can qualify learning, then wait for in-place linking.
select pg_temp.unit((select id from claims where label='anon'),1);
select is((select status from monetization_private.referral_milestones where claim_id=(select id from claims where label='anon')),'waiting_identity','anonymous learning waits for identity');
update auth.users set is_anonymous=false where id=pg_temp.uid('anon');
insert into auth.identities(user_id,provider,provider_id,identity_data) values(pg_temp.uid('anon'),'email',pg_temp.uid('anon')::text,'{}');
select process_referral_claim((select id from claims where label='anon'));
select is((select unit_id from monetization_private.referral_reward_events where claim_id=(select id from claims where label='anon')),5,'in-place link unlocks one earned reward');

-- Review is sticky; another verified receipt cannot clear it automatically.
select pg_temp.actor('review'); insert into claims values('review',pg_temp.claim('review'));
select pg_temp.unit((select id from claims where label='review'),1,'needs_review');
select pg_temp.unit((select id from claims where label='review'),2);
select is((select count(*)::integer from monetization_private.referral_reward_events where claim_id=(select id from claims where label='review')),0,'review holds all rewards');
select is((select risk_state from monetization_private.referral_claims where id=(select id from claims where label='review')),'needs_review','verified retry does not clear review');
select resolve_referral_review((select id from claims where label='review'),'clear','Manually verified supported device');
select is((select count(*)::integer from monetization_private.referral_reward_events where claim_id=(select id from claims where label='review')),2,'audited review release awards pending milestones');

-- Temporary paid access never consumes permanent rewards; existing permanent
-- legacy grants are skipped. The fifteenth A1 paid unit is 30, never A2.
select pg_temp.actor('cap-owner'); select pg_temp.actor('cap-friend');
select set_course_unit_grant(pg_temp.uid('cap-owner'),u,'legacy','legacy-'||u,null,false,'migration')
  from unnest(array[3,4,5,6,7,8,9,10,11,12,13,14,15,28]) u;
select apply_verified_feature(pg_temp.uid('cap-owner'),'core','test-purchase','active',now()+interval '1 month',now());
insert into claims values('cap-friend',pg_temp.claim('cap-friend','cap-owner'));
select pg_temp.unit((select id from claims where label='cap-friend'),1);
select pg_temp.unit((select id from claims where label='cap-friend'),2);
select is((select unit_id from monetization_private.referral_reward_events where claim_id=(select id from claims where label='cap-friend') and ordinal=1),30,'final slot is unit 30 despite active Core');
select is((select outcome from monetization_private.referral_reward_events where claim_id=(select id from claims where label='cap-friend') and ordinal=2),'cap_reached','sixteenth reward cannot spill into A2');

-- The complete business promise: seven full friends give 14 units; the eighth
-- gives unit 30 and then cap_reached, with no payment by either party.
select pg_temp.actor('eight-owner');
do $$
declare friend text; cl uuid;
begin
  for i in 1..8 loop
    friend:='eight-friend-'||i;
    perform pg_temp.actor(friend);
    cl:=pg_temp.claim(friend,'eight-owner');
    perform pg_temp.unit(cl,1); perform pg_temp.unit(cl,2);
  end loop;
end $$;
select is((select array_agg(unit_id order by unit_id) from public.course_unit_grants where user_id=pg_temp.uid('eight-owner')),
  array[3,4,5,6,7,8,9,10,11,12,13,14,15,28,30],'eight friends unlock every paid A1 unit');
select is((select count(*)::integer from monetization_private.referral_reward_events where beneficiary_id=pg_temp.uid('eight-owner') and outcome='cap_reached'),1,'only the eighth friend second milestone hits the cap');
select is((select count(*)::integer from monetization_private.feature_entitlements where user_id=pg_temp.uid('eight-owner')),0,'full A1 referral ownership requires no purchase');
select set_course_unit_grant(g.user_id,g.unit_id,g.source,g.source_key,g.campaign_id,true,'documented fraud correction')
  from public.course_unit_grants g where user_id=pg_temp.uid('eight-owner') and unit_id=3;
select process_referral_claim(id) from monetization_private.referral_claims where referrer_id=pg_temp.uid('eight-owner');
select is((select count(*)::integer from public.course_unit_grants where user_id=pg_temp.uid('eight-owner') and revoked_at is null),14,'replay cannot resurrect revoked or cap-reached awards');

select pg_temp.actor('rejected'); insert into claims values('rejected',pg_temp.claim('rejected'));
select pg_temp.unit((select id from claims where label='rejected'),1,'needs_review');
select resolve_referral_review((select id from claims where label='rejected'),'rejected','Verified abuse');
select is((select outcome from monetization_private.referral_reward_events where claim_id=(select id from claims where label='rejected')),'rejected','review rejection records a final zero-grant outcome');
select is(resolve_referral_review((select id from claims where label='rejected'),'clear','Retry')->>'code','review_unavailable','resolved review cannot silently be reversed');

select pg_temp.actor('clock'); insert into claims values('clock',pg_temp.claim('clock'));
select accept_verified_referral_receipt(pg_temp.uid('clock'),id,jsonb_set(pg_temp.receipt(id,100),'{started_at_client}',to_jsonb(now()-interval '1 day')),repeat('c',64),'verified') from claims where label='clock';
select is((select reason from monetization_private.referral_review_cases where claim_id=(select id from claims where label='clock')),'timing_anomaly','pre-claim diagnostic time requires review');

-- Pausing processing keeps evidence. An allocation crash must roll back the
-- grant, account revision, audit and outbox together, leaving a retryable claim.
select pg_temp.actor('crash-owner'); select pg_temp.actor('crash-friend');
insert into claims values('crash',pg_temp.claim('crash-friend','crash-owner'));
update monetization_private.referral_campaigns set processing_paused=true;
select pg_temp.unit((select id from claims where label='crash'),1);
select is((select status from monetization_private.referral_milestones where claim_id=(select id from claims where label='crash')),'verification_pending','pause keeps qualified evidence pending');
update monetization_private.referral_campaigns set processing_paused=false;
create function pg_temp.fail_reward() returns trigger language plpgsql as $$ begin raise exception 'simulated allocation crash'; end $$;
create trigger test_fail_reward before insert on monetization_private.referral_reward_events for each row execute function pg_temp.fail_reward();
select throws_ok(format('select process_referral_claim(%L)',(select id from claims where label='crash')),'P0001','simulated allocation crash','failure after grant is transactional');
select is((select count(*)::integer from public.course_unit_grants where user_id=pg_temp.uid('crash-owner')),0,'failed transaction leaves no grant');
select is((select revision::integer from public.monetization_accounts where user_id=pg_temp.uid('crash-owner')),0,'failed transaction leaves revision unchanged');
select is((select count(*)::integer from monetization_private.monetization_outbox where user_id=pg_temp.uid('crash-owner')),0,'failed transaction leaves no outbox event');
drop trigger test_fail_reward on monetization_private.referral_reward_events;
select process_referral_claim((select id from claims where label='crash'));
select is((select count(*)::integer from public.course_unit_grants where user_id=pg_temp.uid('crash-owner')),1,'retry awards once');

-- Exact receipt replays return the same result after campaign closure.
create temp table replay as select r.*,pg_temp.receipt(r.claim_id,r.lesson_id,r.attempt_id) payload
  from monetization_private.referral_receipts r where claim_id=(select id from claims where label='crash') limit 1;
update monetization_private.referral_campaigns set enabled=false;
select is((claim_referral(pg_temp.uid('friend'),'a1-referral-v1',(select code from monetization_private.referral_codes where owner_id=pg_temp.uid('owner')))->>'claim_id')::uuid,
  (select id from claims where label='friend'),'claim replay survives enrollment disable');
select is(accept_verified_referral_receipt(referee_id,claim_id,payload,receipt_digest,'verified')->>'receipt_id',id::text,'receipt replay returns original result') from replay;

-- Deleting the friend erases their evidence but preserves the beneficiary's
-- already granted access. Deleting the beneficiary only removes their access.
delete from auth.users where id=pg_temp.uid('friend');
select is((select count(*)::integer from monetization_private.referral_receipts where claim_id=(select id from claims where label='friend')),0,'deletion erases private learning receipts');
select ok((select referee_id is null from monetization_private.referral_claims where id=(select id from claims where label='friend')),'deleted referee is tombstoned');
select is((select count(*)::integer from monetization_private.referral_reward_events where claim_id=(select id from claims where label='friend')),2,'reward audit survives invitee deletion');
select is((select count(*)::integer from public.course_unit_grants where user_id=pg_temp.uid('owner') and unit_id in (3,4)),2,'earned units survive invitee deletion');
select is(process_referral_claim((select id from claims where label='friend'))->>'code','referral_unavailable','deleted identity cannot earn again');
delete from auth.users where id=pg_temp.uid('cap-owner');
select is((select count(*)::integer from public.course_unit_grants where user_id=pg_temp.uid('cap-owner')),0,'beneficiary deletion removes their access');
select is((select count(*)::integer from monetization_private.referral_receipts where claim_id=(select id from claims where label='cap-friend')),8,'beneficiary deletion preserves friend evidence');

select * from finish();
rollback;
