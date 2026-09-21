begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path = public;
select no_plan();

insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
select ok(not has_function_privilege('authenticated','public.get_monetization_snapshot(uuid)','EXECUTE'), 'client cannot choose snapshot account');
select ok(not has_function_privilege('anon','public.get_monetization_snapshot(uuid)','EXECUTE'), 'unauthenticated cannot query snapshots');
select ok(has_function_privilege('service_role','public.get_monetization_snapshot(uuid)','EXECUTE'), 'verified Edge handler can query snapshots');
select ok(not has_table_privilege('authenticated','public.course_unit_grants','INSERT'), 'clients cannot mint units');
select ok(not has_table_privilege('service_role','public.course_unit_grants','INSERT'), 'service writers must use audited RPC');
select ok(not has_schema_privilege('authenticated','monetization_private','USAGE'), 'private billing sources are not exposed');
select is((get_monetization_snapshot('00000000-0000-0000-0000-000000000001')->'features'->'core'->>'state'), 'inactive', 'new account has no Core');

select set_course_unit_grant('00000000-0000-0000-0000-000000000001',3,'referral','claim-1:1','a1-referral-v1',false,'qualified milestone');
select set_course_unit_grant('00000000-0000-0000-0000-000000000001',3,'referral','claim-1:1','a1-referral-v1',false,'retry');
select is((select count(*)::integer from course_unit_grants),1,'grant retries are idempotent');
select is((select revision::integer from monetization_accounts where user_id='00000000-0000-0000-0000-000000000001'),1,'retry does not bump revision');
select throws_ok($$select set_course_unit_grant('00000000-0000-0000-0000-000000000001',4,'referral','claim-1:1','a1-referral-v1',false,'conflict')$$,'22023',null,'source key cannot be reused for different content');
select throws_ok($$select set_course_unit_grant('00000000-0000-0000-0000-000000000001',16,'referral','bad:a2','a1-referral-v1',false,'bad')$$,'23514',null,'referrals cannot grant A2');
select throws_ok($$select set_course_unit_grant('00000000-0000-0000-0000-000000000001',4,'referral','bad:null',null,false,'bad')$$,'23514',null,'referral requires its campaign');
select throws_ok($$select set_course_unit_grant('00000000-0000-0000-0000-000000000001',3,'referral','other:1','a1-referral-v1',false,'duplicate')$$,'23505',null,'same campaign cannot grant same unit twice');
select is((select count(*)::integer from monetization_private.entitlement_audit),1,'failed writes roll back audit');
select is((select count(*)::integer from monetization_private.monetization_outbox),1,'outbox is atomic with grant');

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
select is((select count(*)::integer from course_unit_grants),0,'another account cannot read grants');
select throws_ok($$select get_monetization_snapshot('00000000-0000-0000-0000-000000000001')$$,'42501',null,'RPC denies actual client role');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select is((select count(*)::integer from course_unit_grants),1,'owner can read its projection');
reset role;

select apply_verified_feature('00000000-0000-0000-0000-000000000001','core','long-old','active',now()+interval '30 days',now()-interval '6 days');
select apply_verified_feature('00000000-0000-0000-0000-000000000001','core','short-new','canceled',now()+interval '2 days',now());
select is((get_monetization_snapshot('00000000-0000-0000-0000-000000000001')->'features'->'core'->>'offline_valid_until')::timestamptz,now()+interval '2 days','offline bound never mixes different purchase timestamps');
select is(get_monetization_snapshot('00000000-0000-0000-0000-000000000001')->'features'->'ai_chat'->>'state','inactive','Core does not grant AI');
select apply_verified_feature('00000000-0000-0000-0000-000000000001','ai_chat','ai','pending',now()+interval '30 days',now());
select is(get_monetization_snapshot('00000000-0000-0000-0000-000000000001')->'features'->'ai_chat'->>'state','inactive','pending AI grants nothing');
select apply_verified_feature('00000000-0000-0000-0000-000000000001','core','short-new','active',now()+interval '60 days',now()-interval '1 day');
select is((get_monetization_snapshot('00000000-0000-0000-0000-000000000001')->'features'->'core'->>'offline_valid_until')::timestamptz,now()+interval '2 days','stale verification ignored');
select throws_ok($$select apply_verified_feature('00000000-0000-0000-0000-000000000001','core','short-new','revoked',now()+interval '2 days',now())$$,'22023',null,'contradictory same-time verification rejected');
select set_course_unit_grant('00000000-0000-0000-0000-000000000001',3,'referral','claim-1:1','a1-referral-v1',true,'fraud confirmed');
select is(jsonb_array_length(get_monetization_snapshot('00000000-0000-0000-0000-000000000001')->'permanent_unit_grants'),0,'revoked grants omitted');
select throws_ok($$select set_course_unit_grant('00000000-0000-0000-0000-000000000001',3,'referral','claim-1:1','a1-referral-v1',false,'undo')$$,'22023',null,'retry cannot resurrect revoked grant');

-- keep_newest_sync_row drops non-newer writes, and now() is fixed in this
-- transaction, so each update advances updated_at the way a real client does.
insert into placement_profiles(user_id,key,provisional_unit,phase_ceilings,device_id) values('00000000-0000-0000-0000-000000000001','primary',30,'{"a1":30}','test-device');
update placement_profiles set phase_ceilings='{"a2":16}',provisional_unit=16,updated_at=updated_at+interval '1 minute' where user_id='00000000-0000-0000-0000-000000000001';
select is((select phase_ceilings from placement_profiles where user_id='00000000-0000-0000-0000-000000000001'),'{"a1":30,"a2":16}'::jsonb,'new A2 placement retains A1 separately');
update placement_profiles set phase_ceilings=null,provisional_unit=24,updated_at=updated_at+interval '1 minute' where user_id='00000000-0000-0000-0000-000000000001';
select is((select phase_ceilings from placement_profiles where user_id='00000000-0000-0000-0000-000000000001'),'{"a1":30,"a2":24}'::jsonb,'old scalar writer merges without discarding either phase');
select throws_ok($$update placement_profiles set phase_ceilings='{"a1":16}',updated_at=updated_at+interval '1 minute' where user_id='00000000-0000-0000-0000-000000000001'$$,'22023',null,'wrong phase IDs rejected');

-- The grant does not reference an invitee account, so deleting one cannot
-- cascade into another user's benefit. Referral attribution comes in PR 4.
select set_course_unit_grant('00000000-0000-0000-0000-000000000001',4,'legacy','PRIVATE-SOURCE',null,false,'legacy protection');
select is(jsonb_array_length(export_account_snapshot('00000000-0000-0000-0000-000000000001')->'course_unit_grants'),2,'export includes own grant history');
select ok(not (export_account_snapshot('00000000-0000-0000-0000-000000000001')::text like '%PRIVATE-SOURCE%'),'export excludes internal source keys');
select ok(export_account_snapshot('00000000-0000-0000-0000-000000000001') ? 'lesson_progress','existing export contract retained');
delete from auth.users where id='00000000-0000-0000-0000-000000000002';
select is(jsonb_array_length(get_monetization_snapshot('00000000-0000-0000-0000-000000000001')->'permanent_unit_grants'),1,'other account deletion preserves own grant');
delete from auth.users where id='00000000-0000-0000-0000-000000000001';
select is((select count(*)::integer from course_unit_grants),0,'beneficiary deletion removes own access');
select is((select count(*)::integer from monetization_private.feature_entitlements),0,'beneficiary deletion removes feature records');
select * from finish();
rollback;
