begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path=public;
select no_plan();

insert into auth.users(id,created_at) values
  ('72000000-0000-0000-0000-000000000001',now()-interval '400 days'),
  ('72000000-0000-0000-0000-000000000002',now()-interval '400 days'),
  ('72000000-0000-0000-0000-000000000003',now()-interval '400 days');
create temp table ids as select '72000000-0000-0000-0000-000000000001'::uuid owner,
  '72000000-0000-0000-0000-000000000002'::uuid friend,'72000000-0000-0000-0000-000000000003'::uuid buyer;

select ok(not has_function_privilege('authenticated','public.cleanup_privacy_records()','EXECUTE'),'clients cannot run retention');

-- Purchases: label in base_plan_id is not possible, so the digest tells them apart.
create function pg_temp.purchase(p_digit text,p_owner uuid,p_state text,p_verified interval) returns void language sql as $$
  insert into monetization_private.store_purchases(platform,token_digest,encrypted_token,user_id,product_id,base_plan_id,
      lineage_id,state,valid_until,last_verified_at,created_at)
    values('android',repeat(p_digit,64),'sealed',p_owner,'czechify_core','monthly',gen_random_uuid(),p_state,
      now()-p_verified,now()-p_verified,now()-interval '200 days') $$;
select pg_temp.purchase('1',null,'expired',interval '40 days');
select pg_temp.purchase('2',null,'expired',interval '10 days');
select pg_temp.purchase('3',null,'on_hold',interval '40 days');
select pg_temp.purchase('4',(select buyer from ids),'expired',interval '300 days');
select pg_temp.purchase('5',null,null,interval '40 days');
select pg_temp.purchase('6',null,'revoked',interval '40 days');

-- Referral claims: decided long ago, decided recently, still in progress.
insert into monetization_private.referral_claims(id,campaign_id,referrer_id,referee_id,attribution_source,risk_state) values
  ('73000000-0000-0000-0000-000000000001','a1-referral-v1',(select owner from ids),(select friend from ids),'manual','clear'),
  ('73000000-0000-0000-0000-000000000002','a1-referral-v1',(select owner from ids),(select buyer from ids),'manual','clear');
create function pg_temp.receipt(p_claim uuid,p_referee uuid,p_lesson integer) returns void language sql as $$
  insert into monetization_private.referral_receipts(claim_id,referee_id,attempt_id,lesson_id,content_revision,receipt_digest,
      payload_hash,initial_coverage,started_at_client,completed_at_client,received_at,evidence_state,integrity_state)
    values(p_claim,p_referee,gen_random_uuid(),p_lesson,25,repeat('c',64),'h','[]',now()-interval '200 days',
      now()-interval '200 days',now()-interval '200 days','accepted','verified') $$;
select pg_temp.receipt('73000000-0000-0000-0000-000000000001',(select friend from ids),l) from unnest(array[100,101]) l;
select pg_temp.receipt('73000000-0000-0000-0000-000000000002',(select buyer from ids),l) from unnest(array[100,101]) l;
insert into monetization_private.referral_reward_events(claim_id,ordinal,beneficiary_id,outcome,created_at) values
  ('73000000-0000-0000-0000-000000000001',1,(select owner from ids),'cap_reached',now()-interval '120 days'),
  ('73000000-0000-0000-0000-000000000001',2,(select owner from ids),'cap_reached',now()-interval '100 days'),
  ('73000000-0000-0000-0000-000000000002',1,(select owner from ids),'cap_reached',now()-interval '100 days');

-- A migration whose claim window closed 100 days ago, and one still open.
insert into monetization_private.legacy_migration_runs(migration_id,cutoff_at,grace_ends_at,claim_window_ends_at,
    manifest_revision,snapshot_taken_at,applied_at,applied_by) values
  ('t0-old-run',now()-interval '130 days',now()-interval '100 days',now()-interval '100 days',25,now()-interval '130 days',now()-interval '130 days','ops'),
  ('t0-new-run',now()-interval '10 days',now()+interval '20 days',now()+interval '20 days',25,now()-interval '10 days',null,null);
insert into monetization_private.legacy_migration_snapshot(migration_id,user_id,lesson_id,is_completed,attempted) values
  ('t0-old-run',(select owner from ids),100,true,true),('t0-new-run',(select owner from ids),100,true,true);
select set_course_unit_grant((select owner from ids),1,'legacy','t0-old-run:1',null,false,'legacy migration');

-- Operational rows.
insert into monetization_private.billing_notification_inbox(provider,subscription_resource,message_id,notification_kind,outcome,received_at)
  values('google_play','r','old','test','ignored',now()-interval '40 days'),('google_play','r','new','test','ignored',now());
insert into monetization_private.purchase_intents(user_id,platform,product_id,base_plan_id,idempotency_key,expires_at)
  values((select buyer from ids),'android','czechify_core','monthly',gen_random_uuid(),now()-interval '40 days'),
    ((select buyer from ids),'android','czechify_core','monthly',gen_random_uuid(),now()+interval '1 hour');
insert into monetization_private.entitlement_audit(user_id,action,source_key,reason,created_at)
  values(null,'grant','claim:x','deleted account',now()-interval '40 days'),((select owner from ids),'grant','claim:y','kept',now()-interval '400 days');
insert into monetization_private.billing_audit_events(purchase_id,user_id,event,created_at)
  values(null,null,'orphaned',now()-interval '40 days');

create temp table run as select cleanup_privacy_records() r;

select is((select count(*)::integer from monetization_private.store_purchases where token_digest=repeat('1',64)),0,'an ownerless expired purchase goes 30 days later');
select is((select count(*)::integer from monetization_private.store_purchases where token_digest=repeat('6',64)),0,'so does a revoked one');
select is((select count(*)::integer from monetization_private.store_purchases where token_digest=repeat('5',64)),0,'and one that never completed');
select is((select count(*)::integer from monetization_private.store_purchases where token_digest=repeat('2',64)),1,'a recently expired one stays for a late restore');
select is((select count(*)::integer from monetization_private.store_purchases where token_digest=repeat('3',64)),1,'a purchase on hold can still be restored, so it stays');
select is((select count(*)::integer from monetization_private.store_purchases where token_digest=repeat('4',64)),1,'an owned purchase stays with its account');

select is((select count(*)::integer from monetization_private.referral_receipts where claim_id='73000000-0000-0000-0000-000000000001'),0,'lesson summaries go 90 days after the invitation is decided');
select is((select count(*)::integer from monetization_private.referral_receipts where claim_id='73000000-0000-0000-0000-000000000002'),2,'an undecided invitation keeps its evidence');
select is((select count(*)::integer from monetization_private.referral_reward_events where claim_id='73000000-0000-0000-0000-000000000001'),2,'the reward record that explains a grant stays');

select is((select count(*)::integer from monetization_private.legacy_migration_snapshot where migration_id='t0-old-run'),0,'the migration copy goes 90 days after its window');
select is((select count(*)::integer from monetization_private.legacy_migration_snapshot where migration_id='t0-new-run'),1,'an open window keeps its copy');
select is((select count(*)::integer from public.course_unit_grants where user_id=(select owner from ids) and source='legacy'),1,'granted units are never touched');

select is((select count(*)::integer from monetization_private.billing_notification_inbox),1,'old notification dedupe rows go');
select is((select count(*)::integer from monetization_private.purchase_intents where user_id=(select buyer from ids)),1,'expired intents go');
select is((select count(*)::integer from monetization_private.entitlement_audit where source_key in ('claim:x','claim:y')),1,'audit of deleted accounts goes; an account''s own stays');
select is((select count(*)::integer from monetization_private.billing_audit_events where event='orphaned'),0,'orphaned billing audit goes');
select is(((select r from run)->>'ownerless_purchases')::integer,3,'the worker is told what was removed');

-- Once more changes nothing.
select is(cleanup_privacy_records()->>'ownerless_purchases','0','retention is idempotent');

-- Campaign over for 90 days: every remaining summary goes.
update monetization_private.referral_campaigns set starts_at=now()-interval '300 days',claim_closes_at=now()-interval '200 days',
  ends_at=now()-interval '100 days';
select cleanup_privacy_records();
select is((select count(*)::integer from monetization_private.referral_receipts where claim_id='73000000-0000-0000-0000-000000000002'),0,'summaries go 90 days after the campaign ends');

select * from finish();
rollback;
