begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path = public;
select no_plan();

-- The buyer (A) and another account on the same phone (B).
insert into auth.users(id,email,is_anonymous) values
 ('75000000-0000-0000-0000-00000000000a','buyer@example.com',false),
 ('75000000-0000-0000-0000-00000000000b','other@example.com',false);
create temp table ids as select '75000000-0000-0000-0000-00000000000a'::uuid buyer,
  '75000000-0000-0000-0000-00000000000b'::uuid other;
select billing_bind_account((select buyer from ids),'bindingBUYER-000000',1::smallint);
select billing_bind_account((select other from ids),'bindingOTHER-000000',1::smallint);
select set_billing_product_enabled('czechify_core',true);

select ok(not has_function_privilege('authenticated','public.queue_play_discovery(text,text,text)','EXECUTE'),'clients cannot queue discoveries');
select ok(not has_function_privilege('authenticated','public.resolve_play_discovery(text,text)','EXECUTE'),'clients cannot resolve discoveries');
select ok(not has_function_privilege('service_role','private.lock_referral_accounts(uuid)','EXECUTE'),'the lock helper is internal');

-- One Play verification of the purchase with this digest, as the worker runs it.
create function pg_temp.verify(p_digit text,p_binding text) returns jsonb language plpgsql as $$
declare purchase uuid; job uuid; fence bigint;
begin
  select id into purchase from monetization_private.store_purchases where token_digest=repeat(p_digit,64);
  select id into job from monetization_private.billing_jobs where purchase_id=purchase
    and operation in ('verify','reconcile') and state in ('ready','retry');
  job := coalesce(job, private.queue_billing_refresh(purchase,'verify'));
  fence := claim_billing_job(job,'worker',60);
  return apply_play_verification(job,fence,'worker',jsonb_build_object('state','active',
    'valid_until',now()+interval '30 days','verified_at',clock_timestamp(),'auto_renewing',true,'acknowledged',false,
    'product_id','czechify_core','base_plan_id','monthly','obfuscated_account_id',p_binding,'raw_state','x'));
end $$;
create function pg_temp.core(p_user uuid) returns text language sql as $$
  select get_monetization_snapshot(p_user)->'features'->'core'->>'state' $$;
create function pg_temp.owner(p_digit text) returns uuid language sql as $$
  select user_id from monetization_private.store_purchases where token_digest=repeat(p_digit,64) $$;

-- B sends in A's purchase first (A's app crashed before it could).
select is(register_purchase_verification((select other from ids),repeat('1',64),'enc-1','czechify_core',null)->>'status','queued','the first sender holds the token for now');
create temp table moved as select pg_temp.verify('1','bindingBUYER-000000') v;
select is((select v->>'status' from moved),'provisioned','Play names the buyer, so it is provisioned');
select is((select v->>'owner_id' from moved),(select buyer::text from ids),'the result says whose it is');
select is(pg_temp.owner('1'),(select buyer from ids),'the purchase belongs to the buyer');
select is(pg_temp.core((select buyer from ids)),'active','the buyer has Core');
select is(pg_temp.core((select other from ids)),'inactive','the sender has nothing');
select ok((select v->>'ack_job_id' from moved) is not null,'it is acknowledged for the buyer');
select is((select count(*)::integer from monetization_private.purchase_recovery_cases),0,'nobody needs support');
select is((select count(*)::integer from monetization_private.billing_audit_events where event in
  ('ownership_confirmed_by_play','ownership_moved_by_play')),2,'the move is audited on both sides');
select is(register_purchase_verification((select buyer from ids),repeat('1',64),'enc-1','czechify_core',null)->>'status','queued','the buyer''s own restore now just works');

-- Once confirmed, Play's answer never moves it again.
select is(pg_temp.verify('1','bindingOTHER-000000')->>'status','account_binding_mismatch','a confirmed purchase stays put');
select is(pg_temp.owner('1'),(select buyer from ids),'still the buyer''s');

-- A token the buyer sends while B still holds it, before Play was asked:
-- the buyer's case closes by itself once Play answers.
select register_purchase_verification((select other from ids),repeat('2',64),'enc-2','czechify_core',null);
create temp table waiting as select register_purchase_verification((select buyer from ids),repeat('2',64),'enc-2','czechify_core',null) v;
select is((select v->>'status' from waiting),'account_binding_mismatch','until Play answers, the buyer is told it is held elsewhere');
select is((select status from monetization_private.purchase_recovery_cases where id=(select (v->>'recovery_case_id')::uuid from waiting)),'open','a case is open meanwhile');
select is(pg_temp.verify('2','bindingBUYER-000000')->>'status','provisioned','Play answers for the buyer');
select is((select status from monetization_private.purchase_recovery_cases where id=(select (v->>'recovery_case_id')::uuid from waiting)),'superseded','the case closes');
select is((select decided_by from monetization_private.purchase_recovery_cases where id=(select (v->>'recovery_case_id')::uuid from waiting)),'google_play','closed by Play''s answer, not an operator');

-- An old mismatch (checked before this rule existed) is asked again when the
-- buyer restores.
select register_purchase_verification((select other from ids),repeat('3',64),'enc-3','czechify_core',null);
update monetization_private.billing_jobs set state='done',last_error_code='account_binding_mismatch'
  where purchase_id=(select id from monetization_private.store_purchases where token_digest=repeat('3',64));
update monetization_private.store_purchases set last_error_code='account_binding_mismatch' where token_digest=repeat('3',64);
select register_purchase_verification((select buyer from ids),repeat('3',64),'enc-3','czechify_core',null);
select ok(exists (select 1 from monetization_private.billing_jobs j join monetization_private.store_purchases p on p.id=j.purchase_id
  where p.token_digest=repeat('3',64) and j.state='ready'),'a fresh check is queued');
select pg_temp.verify('3','bindingBUYER-000000');
select is(pg_temp.owner('3'),(select buyer from ids),'and it goes to the buyer');

-- A binding that is nobody's still opens a case, as before.
select register_purchase_verification((select other from ids),repeat('4',64),'enc-4','czechify_core',null);
select is(pg_temp.verify('4','bindingNOBODY-00000')->>'status','account_binding_mismatch','an unknown binding is refused');
select is(pg_temp.owner('4'),(select other from ids),'nothing moves');

-- Discovery: Google's notification arrives, the app never sends the token.
select is(queue_play_discovery(repeat('5',64),'enc-5','czechify_core'),'queued','an unknown token is kept for the worker');
select is(queue_play_discovery(repeat('5',64),'enc-5','czechify_core'),'duplicate','a redelivery is not queued twice');
select is(queue_play_discovery(repeat('1',64),'enc-1','czechify_core'),'known','a registered purchase needs no discovery');
select is(queue_play_discovery(repeat('6',64),'enc-6','some_other_app_product'),'ignored','a product not sold here is ignored');
select throws_ok($$select queue_play_discovery('not-a-digest','enc','czechify_core')$$,'22023',null,'the digest is checked');
select is(jsonb_array_length(due_play_discoveries(10)),1,'one discovery is due');
select is(due_play_discoveries(10)->0->>'encrypted_token','enc-5','the worker reads the encrypted token');

create temp table found as select resolve_play_discovery(repeat('5',64),'bindingBUYER-000000') v;
select is((select v->>'status' from found),'queued','the purchase is registered for the account Play named');
select is(pg_temp.owner('5'),(select buyer from ids),'it belongs to the buyer');
select ok((select v->>'job_id' from found) is not null,'with a verification to run');
select is((select encrypted_token from monetization_private.play_purchase_discoveries where token_digest=repeat('5',64)),null,'the discovery drops its copy of the token');
select is(resolve_play_discovery(repeat('5',64),'bindingBUYER-000000')->>'status','already_resolved','resolving twice does nothing');
select is(jsonb_array_length(due_play_discoveries(10)),0,'nothing more is due');

select queue_play_discovery(repeat('7',64),'enc-7','czechify_core');
select is(resolve_play_discovery(repeat('7',64),'bindingNOBODY-00000')->>'status','no_owner','a purchase naming no account is left alone');
select is((select count(*)::integer from monetization_private.store_purchases where token_digest=repeat('7',64)),0,'and not registered');

select queue_play_discovery(repeat('8',64),'enc-8','czechify_core');
select ok(fail_play_discovery(repeat('8',64),60,false),'an outage backs off');
select is(jsonb_array_length(due_play_discoveries(10)),0,'not due during the backoff');
select is((select attempts from monetization_private.play_purchase_discoveries where token_digest=repeat('8',64)),1,'the attempt is counted');
select ok(fail_play_discovery(repeat('8',64),60,true),'it can be given up');
select is((select outcome||':'||coalesce(encrypted_token,'none') from monetization_private.play_purchase_discoveries where token_digest=repeat('8',64)),'failed:none','a given-up discovery keeps no token');

-- Retention: discoveries go 30 days after they arrived.
update monetization_private.play_purchase_discoveries set received_at=now()-interval '31 days';
select is((cleanup_privacy_records()->>'play_discoveries')::integer,3,'old discoveries are deleted');

select * from finish();
rollback;
