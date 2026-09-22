begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path = public;
select no_plan();

insert into auth.users(id,email,is_anonymous) values
 ('74000000-0000-0000-0000-00000000000a','old@example.com',false),
 ('74000000-0000-0000-0000-00000000000b','new@example.com',false),
 ('74000000-0000-0000-0000-00000000000c','third@example.com',false);
create temp table ids as select '74000000-0000-0000-0000-00000000000a'::uuid old,
  '74000000-0000-0000-0000-00000000000b'::uuid fresh,'74000000-0000-0000-0000-00000000000c'::uuid third;
select billing_bind_account((select old from ids),'bindingOLD-00000000',1::smallint);
select billing_bind_account((select fresh from ids),'bindingNEW-00000000',1::smallint);
select billing_bind_account((select third from ids),'bindingTHIRD-000000',1::smallint);
select set_billing_product_enabled('czechify_core',true);

select ok(not has_function_privilege('authenticated','public.resolve_purchase_recovery(uuid,boolean,text,text)','EXECUTE'),'clients cannot decide recovery');
select ok(not has_function_privilege('authenticated','public.support_account_summary(uuid)','EXECUTE'),'clients cannot read support views');
select ok(not has_function_privilege('authenticated','public.monetization_operations_report()','EXECUTE'),'clients cannot read operations');
select ok(not has_function_privilege('service_role','private.open_purchase_recovery(uuid,uuid,text,uuid)','EXECUTE'),'cases open only from verification');

-- Runs one Play verification of the purchase with this token digest.
create function pg_temp.verify(p_digit text,p_binding text,p_state text default 'active') returns jsonb language plpgsql as $$
declare purchase uuid; job uuid; fence bigint;
begin
  select id into purchase from monetization_private.store_purchases where token_digest=repeat(p_digit,64);
  job := private.queue_billing_refresh(purchase,'verify');
  fence := claim_billing_job(job,'worker',60);
  return apply_play_verification(job,fence,'worker',jsonb_build_object('state',p_state,
    'valid_until',now()+interval '30 days','verified_at',clock_timestamp(),'auto_renewing',true,'acknowledged',true,
    'product_id','czechify_core','base_plan_id','monthly','obfuscated_account_id',p_binding,'raw_state','x'));
end $$;
create function pg_temp.core(p_user uuid) returns text language sql as $$
  select get_monetization_snapshot(p_user)->'features'->'core'->>'state' $$;

-- The old account buys Core, then deletes itself.
select register_purchase_verification((select old from ids),repeat('1',64),'enc-secret-1','czechify_core',null);
select is(pg_temp.verify('1','bindingOLD-00000000')->>'status','provisioned','the buyer is provisioned');
delete from auth.users where id=(select old from ids);

-- Restoring on a new account opens one case and grants nothing.
create temp table first as select register_purchase_verification((select fresh from ids),repeat('1',64),'enc-secret-1','czechify_core',null) v;
select is((select v->>'status' from first),'account_binding_mismatch','the token is still refused');
select ok((select v ? 'recovery_case_id' from first),'a support case is opened');
select is(register_purchase_verification((select fresh from ids),repeat('1',64),'enc-secret-1','czechify_core',null)->>'recovery_case_id',
  (select v->>'recovery_case_id' from first),'restoring again returns the same case');
select is((select reason from monetization_private.purchase_recovery_cases where id=(select (v->>'recovery_case_id')::uuid from first)),'ownerless','the case says the owner is gone');
select is(pg_temp.core((select fresh from ids)),'inactive','no access before support decides');

-- What support sees: enough to decide, no token.
create temp table seen as select support_recovery_case((select (v->>'recovery_case_id')::uuid from first)) s;
select is((select s->'purchase'->>'product_id' from seen),'czechify_core','the product is shown');
select is((select s->'current_owner' from seen),'null'::jsonb,'the owner is shown as deleted');
select is((select s->'requester'->>'email' from seen),'new@example.com','the requester is identified');
select ok(not ((select s from seen)::text like '%enc-secret%' or (select s from seen)::text like '%'||repeat('1',64)||'%'),'no token or digest reaches support');

select throws_ok(format($$select resolve_purchase_recovery(%L,true,'support@example','')$$,(select v->>'recovery_case_id' from first)),'22023',null,'a reason is required');
select throws_ok(format($$select resolve_purchase_recovery(%L,true,'','order GPA.1 matches')$$,(select v->>'recovery_case_id' from first)),'22023',null,'an operator is required');

-- Approval moves the purchase and asks Play again; Play's answer grants.
select is(resolve_purchase_recovery((select (v->>'recovery_case_id')::uuid from first),true,'support@example','Play order GPA.1 matches')->>'status','approved','support approves');
select is((select user_id from monetization_private.store_purchases where token_digest=repeat('1',64)),(select fresh from ids),'the purchase belongs to the requester');
select is(pg_temp.core((select fresh from ids)),'inactive','access still waits for Play');
select ok(not exists (select 1 from jsonb_array_elements(monetization_operations_report()->'alerts') a
  where a->>'alert'='acknowledged_without_access'),'waiting for Play after a recovery is not a pause alert');
select is(pg_temp.verify('1','bindingOLD-00000000')->>'status','provisioned','Play''s original binding is accepted once');
select is(pg_temp.core((select fresh from ids)),'active','the requester has Core');
select is(pg_temp.verify('1','bindingOTHER-000000')->>'status','account_binding_mismatch','later a different binding is refused');
select is(pg_temp.verify('1','bindingOLD-00000000')->>'status','provisioned','the recorded binding keeps working at renewal');
select throws_ok(format($$select resolve_purchase_recovery(%L,false,'support@example','again')$$,(select v->>'recovery_case_id' from first)),'22023',null,'a decided case cannot be decided again');
select is((select count(*)::integer from monetization_private.entitlement_audit where source_key='play:'||(select id from monetization_private.store_purchases where token_digest=repeat('1',64))::text and action='purchase_recovered'),1,'the recovery is audited with its operator');

-- Another live account's purchase: moving it ends the old owner's access.
select register_purchase_verification((select fresh from ids),repeat('2',64),'enc-2','czechify_core',null);
select pg_temp.verify('2','bindingNEW-00000000');
create temp table second as select register_purchase_verification((select third from ids),repeat('2',64),'enc-2','czechify_core',null) v;
select is((select reason from monetization_private.purchase_recovery_cases where id=(select (v->>'recovery_case_id')::uuid from second)),'other_account','the case names another owner');
select is((support_recovery_case((select (v->>'recovery_case_id')::uuid from second))->'current_owner'->>'email'),'new@example.com','support sees who holds it now');
-- A rejection changes nothing.
select is(resolve_purchase_recovery((select (v->>'recovery_case_id')::uuid from second),false,'support@example','could not confirm ownership')->>'status','rejected','support rejects');
select is((select user_id from monetization_private.store_purchases where token_digest=repeat('2',64)),(select fresh from ids),'a rejected case moves nothing');
create temp table third_try as select register_purchase_verification((select third from ids),repeat('2',64),'enc-2','czechify_core',null) v;
select isnt((select v->>'recovery_case_id' from third_try),(select v->>'recovery_case_id' from second),'restoring again opens a new case');
select resolve_purchase_recovery((select (v->>'recovery_case_id')::uuid from third_try),true,'support@example','owner confirmed the move by email from new@example.com');
select is((select state from monetization_private.feature_entitlements where user_id=(select fresh from ids)
  and source_key='play:'||(select id from monetization_private.store_purchases where token_digest=repeat('2',64))::text),'revoked','the previous owner loses access from it');
select is(pg_temp.core((select fresh from ids)),'active','their own other purchase is untouched');
select is(pg_temp.verify('2','bindingNEW-00000000')->>'status','provisioned','Play confirms for the new owner');
select is(pg_temp.core((select third from ids)),'active','the new owner has Core');

-- A token new to Czechify whose Play binding is someone else's opens a case.
select register_purchase_verification((select third from ids),repeat('3',64),'enc-3','czechify_core',null);
create temp table third_binding as select pg_temp.verify('3','bindingSOMEONE-0000') v;
select is((select v->>'status' from third_binding),'account_binding_mismatch','Play''s binding still decides');
select is((select reason from monetization_private.purchase_recovery_cases where id=(select (v->>'recovery_case_id')::uuid from third_binding)),'play_binding','a case opens for the registering account');

-- Summary for support.
select is(jsonb_array_length(support_account_summary((select third from ids))->'purchases'),2,'support sees the account''s purchases');
select ok(not (support_account_summary((select third from ids))::text like '%enc-%'),'the summary holds no tokens');

-- Operations report.
create temp table ops as select monetization_operations_report() o;
select ok((select o ? 'verify_p95_seconds' and o ? 'recovery_cases_open' and o ? 'ai_spend_today_micros' from ops),'the report has its metrics');
-- Two: the third account's binding case, and the owner's own case from the
-- refused binding after recovery, which support should look at too.
select is(((select o from ops)->>'recovery_cases_open')::integer,2,'open cases are counted');
select ok(not exists (select 1 from jsonb_array_elements((select o->'alerts' from ops)) a where a->>'alert'='acknowledged_without_access'),'no pause alert while every acknowledged purchase has access');
update monetization_private.store_purchases set acknowledgement_state='acknowledged' where token_digest=repeat('3',64);
delete from monetization_private.feature_entitlements where source_key='play:'||(select id from monetization_private.store_purchases where token_digest=repeat('3',64))::text;
select ok(exists (select 1 from jsonb_array_elements(monetization_operations_report()->'alerts') a
  where a->>'alert'='acknowledged_without_access' and a->>'level'='pause'),'acknowledged without access is a pause alert');
update monetization_private.billing_jobs set state='dead' where id=(select id from monetization_private.billing_jobs limit 1);
select ok(exists (select 1 from jsonb_array_elements(monetization_operations_report()->'alerts') a where a->>'alert'='billing_jobs_dead'),'dead jobs raise an alert');
update monetization_private.purchase_recovery_cases set opened_at=now()-interval '3 days' where status='open';
select ok(exists (select 1 from jsonb_array_elements(monetization_operations_report()->'alerts') a where a->>'alert'='support_queue_waiting'),'a case waiting two days raises a support alert');

-- Retention: decided cases go 90 days after the decision, open ones expire.
update monetization_private.purchase_recovery_cases set decided_at=now()-interval '91 days' where status<>'open';
update monetization_private.purchase_recovery_cases set opened_at=now()-interval '91 days' where status='open';
select is((cleanup_privacy_records()->>'recovery_cases')::integer,5,'old cases are deleted');
select is((select count(*)::integer from monetization_private.purchase_recovery_cases),0,'none remain');

select * from finish();
rollback;
