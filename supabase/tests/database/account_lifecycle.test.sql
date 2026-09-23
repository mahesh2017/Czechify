begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path=public;
select no_plan();

-- owner invited friend; buyer holds a renewing subscription.
insert into auth.users(id,created_at) values
  ('70000000-0000-0000-0000-000000000001',now()-interval '60 days'),
  ('70000000-0000-0000-0000-000000000002',now()-interval '60 days'),
  ('70000000-0000-0000-0000-000000000003',now()-interval '60 days'),
  ('70000000-0000-0000-0000-000000000004',now());
create temp table ids as select
  '70000000-0000-0000-0000-000000000001'::uuid owner,'70000000-0000-0000-0000-000000000002'::uuid friend,
  '70000000-0000-0000-0000-000000000003'::uuid buyer,'70000000-0000-0000-0000-000000000004'::uuid newcomer;

select ok(not has_function_privilege('authenticated','public.legacy_claim_status(uuid)','EXECUTE'),'clients cannot read another account''s migration status');
select ok(not has_function_privilege('authenticated','public.account_deletion_notice(uuid)','EXECUTE'),'clients cannot probe subscriptions');
select ok(not has_function_privilege('anon','public.export_account_snapshot(uuid)','EXECUTE'),'the export stays service-only');

-- Before any run is applied there is nothing to show.
select is(legacy_claim_status((select owner from ids)),'{"available":false}'::jsonb,'no migration, no status');

-- Referral between owner and friend, with a granted reward.
insert into monetization_private.referral_codes(code,owner_id,campaign_id)
  values('ABCDEF0123456789ABCDEF01',(select owner from ids),'a1-referral-v1');
insert into monetization_private.referral_claims(id,campaign_id,referrer_id,referee_id,attribution_source,risk_state)
  values('71000000-0000-0000-0000-000000000001','a1-referral-v1',(select owner from ids),(select friend from ids),'manual','clear');
select set_course_unit_grant((select owner from ids),3,'referral','claim:1','a1-referral-v1',false,'test reward');
insert into monetization_private.referral_reward_events(claim_id,ordinal,beneficiary_id,grant_id,unit_id,outcome)
  values('71000000-0000-0000-0000-000000000001',1,(select owner from ids),
    (select id from public.course_unit_grants where user_id=(select owner from ids) and unit_id=3),3,'granted');

-- A renewing subscription with its token.
insert into monetization_private.store_purchases(platform,token_digest,encrypted_token,user_id,product_id,base_plan_id,
    lineage_id,state,valid_until,auto_renewing)
  values('android',repeat('ab',32),'SEALED-PURCHASE-TOKEN',(select buyer from ids),'czechify_core','monthly',
    gen_random_uuid(),'active',now()+interval '20 days',true);

create temp table exports as select
  export_account_snapshot((select owner from ids)) owner_export,
  export_account_snapshot((select friend from ids)) friend_export,
  export_account_snapshot((select buyer from ids)) buyer_export;

-- Exports carry the learner's own records...
select is(jsonb_array_length((select owner_export from exports)->'referral_codes'),1,'the referrer exports their code');
select is((select owner_export from exports)->'referral_rewards'->0->>'unit_id','3','the referrer exports their reward');
select is(jsonb_array_length((select friend_export from exports)->'referral_claims'),1,'the invitee exports their claim');
select is((select buyer_export from exports)->'store_purchases'->0->>'product_id','czechify_core','the buyer exports their subscription');
-- ...and never the other learner or a secret.
select ok(not ((select owner_export from exports)::text like '%'||(select friend from ids)||'%'),'the referrer''s export never names the invitee');
select ok(not ((select friend_export from exports)::text like '%'||(select owner from ids)||'%'),'the invitee''s export never names the referrer');
select ok(not ((select owner_export from exports)::text like '%71000000-0000-0000-0000-000000000001%'),'rewards carry no claim ID that links to the invitee');
select ok(not ((select buyer_export from exports)::text like '%SEALED-PURCHASE-TOKEN%'),'no purchase token');
select ok(not ((select buyer_export from exports)::text like '%'||repeat('ab',32)||'%'),'no purchase token digest');
select ok(not ((select friend_export from exports)::text like '%risk_state%'),'no fraud signals');
select ok(not ((select owner_export from exports)::text like '%claim:1%'),'no internal source keys');

-- Deletion warns while a subscription renews.
select is(account_deletion_notice((select buyer from ids))->>'renewing_subscriptions','1','a renewing subscription is reported');
select is(account_deletion_notice((select owner from ids))->>'renewing_subscriptions','0','no subscription, no warning');
update monetization_private.store_purchases set auto_renewing=false,state='canceled' where user_id=(select buyer from ids);
select is(account_deletion_notice((select buyer from ids))->>'renewing_subscriptions','0','a canceled subscription does not warn');

-- Deleting the buyer keeps the purchase as an ownerless tombstone for support
-- recovery; another account can never be handed it by the deletion itself.
delete from auth.users where id=(select buyer from ids);
select is((select count(*)::integer from monetization_private.store_purchases where token_digest=repeat('ab',32) and user_id is null),1,'the purchase is tombstoned, not reassigned');

-- Deleting the referrer removes their code and access; the invitee keeps
-- their own claim record, with the referrer tombstoned.
delete from auth.users where id=(select owner from ids);
select is((select count(*)::integer from monetization_private.referral_codes where code='ABCDEF0123456789ABCDEF01'),0,'the referrer''s code is gone');
select ok((select referrer_id is null from monetization_private.referral_claims where id='71000000-0000-0000-0000-000000000001'),'the referrer is tombstoned on the claim');
select is(jsonb_array_length(export_account_snapshot((select friend from ids))->'referral_claims'),1,'the invitee still exports their own claim');
-- Processing still runs for the invitee's own trial (delivery 12), but no
-- reward can go to the deleted referrer.
create temp table events_before as select count(*) n from monetization_private.referral_reward_events
  where claim_id='71000000-0000-0000-0000-000000000001';
select ok(process_referral_claim('71000000-0000-0000-0000-000000000001') ? 'claim_id','the invitee''s side is still processed');
select is((select count(*) from monetization_private.referral_reward_events where claim_id='71000000-0000-0000-0000-000000000001'),
  (select n from events_before),'a deleted referrer earns nothing further');

-- Migration status once a run is applied.
select legacy_migration_prepare('t0-lifecycle',now()-interval '5 days',25);
select legacy_migration_apply('t0-lifecycle','ops@example');
create temp table st as select legacy_claim_status((select friend from ids)) s;
select is((select s->>'available' from st),'true','the applied run is reported');
select is((select s->>'migration_id' from st),'t0-lifecycle','the latest applied run');
select is((select s->>'eligible' from st),'true','a pre-cutoff account is eligible');
select is((select s->>'claim_window_open' from st),'true','the window is open');
select is((select (s->>'grace_ends_at')::timestamptz from st),(select (s->>'cutoff_at')::timestamptz + interval '30 days' from st),'grace ends 30 days after the cutoff');
select is((select s->'claim' from st),'null'::jsonb,'no claim yet');
select is(legacy_claim_status((select newcomer from ids))->>'eligible','false','a post-cutoff account is not eligible');
select submit_legacy_claim((select friend from ids),'t0-lifecycle',array[100,101,102,103],'{}',3);
select is(legacy_claim_status((select friend from ids))->'claim'->>'status','applied','the claim shows once made');
select is(legacy_claim_status((select friend from ids))->'legacy_unit_ids','[1, 2]'::jsonb,'granted legacy units are listed, with the next unit after a finished one');
select is(jsonb_array_length(export_account_snapshot((select friend from ids))->'legacy_migration_claims'),1,'the claim is exported');

-- An unapplied later run does not replace the applied one.
select legacy_migration_prepare('t0-later',now()-interval '1 day',25);
select is(legacy_claim_status((select friend from ids))->>'migration_id','t0-lifecycle','only applied runs are reported');

select * from finish();
rollback;
