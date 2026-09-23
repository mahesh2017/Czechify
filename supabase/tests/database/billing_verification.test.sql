begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path = public;
select no_plan();

insert into auth.users(id) values
 ('00000000-0000-0000-0000-00000000000a'),('00000000-0000-0000-0000-00000000000b');

-- Clients reach none of it.
select ok(not has_function_privilege('authenticated','public.register_purchase_verification(uuid,text,text,text,uuid)','EXECUTE'), 'clients cannot register tokens directly');
select ok(not has_function_privilege('authenticated','public.apply_play_verification(uuid,bigint,text,jsonb)','EXECUTE'), 'clients cannot apply Play results');
select ok(not has_function_privilege('anon','public.create_purchase_intent(uuid,text,text,uuid)','EXECUTE'), 'anonymous callers cannot create intents');
select ok(has_function_privilege('service_role','public.claim_billing_job(uuid,text,integer)','EXECUTE'), 'service code can lease jobs');
select ok(not has_table_privilege('service_role','monetization_private.store_purchases','SELECT'), 'service role reads purchases only through RPCs');
select ok(not has_function_privilege('service_role','private.billing_lease_is_current(uuid,bigint,text)','EXECUTE'), 'lease helper is internal');

-- Account binding is frozen on first write.
select throws_ok($$select create_purchase_intent('00000000-0000-0000-0000-00000000000a','czechify_core','monthly',gen_random_uuid())$$,'22023',null,'unbound account cannot start checkout');
select is(billing_bind_account('00000000-0000-0000-0000-00000000000a','bindingAAAAAAAAAAAAA',1::smallint),'bindingAAAAAAAAAAAAA','first binding stored');
select is(billing_bind_account('00000000-0000-0000-0000-00000000000a','bindingZZZZZZZZZZZZZ',2::smallint),'bindingAAAAAAAAAAAAA','rotated key never changes an existing binding');
select billing_bind_account('00000000-0000-0000-0000-00000000000b','bindingBBBBBBBBBBBBB',1::smallint);

-- Products ship disabled.
select is(create_purchase_intent('00000000-0000-0000-0000-00000000000a','czechify_core','monthly','10000000-0000-0000-0000-000000000001')->>'status','product_unavailable','disabled product refuses checkout');
select ok(not has_function_privilege('authenticated','public.set_billing_product_enabled(text,boolean)','EXECUTE'), 'clients cannot enable products');
select ok(set_billing_product_enabled('czechify_core',true) and set_billing_product_enabled('czechify_ai',true), 'operator enables both products');
select ok(not set_billing_product_enabled('unknown',true), 'unknown product reports no change');
select is(create_purchase_intent('00000000-0000-0000-0000-00000000000a','czechify_core','monthly','10000000-0000-0000-0000-000000000001')->>'obfuscated_account_id','bindingAAAAAAAAAAAAA','intent returns the frozen binding');
select is(create_purchase_intent('00000000-0000-0000-0000-00000000000a','czechify_core','monthly','10000000-0000-0000-0000-000000000001')->>'intent_id',
  (select id::text from monetization_private.purchase_intents where idempotency_key='10000000-0000-0000-0000-000000000001'),'retried intent returns the same intent');
select is(create_purchase_intent('00000000-0000-0000-0000-00000000000a','czechify_ai','monthly','10000000-0000-0000-0000-000000000001')->>'status','idempotency_conflict','same key with another product conflicts');
select create_purchase_intent('00000000-0000-0000-0000-00000000000a','czechify_ai','monthly',gen_random_uuid()) from generate_series(1,9);
select is(create_purchase_intent('00000000-0000-0000-0000-00000000000a','czechify_ai','monthly',gen_random_uuid())->>'status','rate_limited','eleventh intent in an hour is refused');

-- Registration never hands a known token to another account.
create temp table r as select register_purchase_verification('00000000-0000-0000-0000-00000000000a',repeat('a',64),'enc-a','czechify_core',
  (select id from monetization_private.purchase_intents where idempotency_key='10000000-0000-0000-0000-000000000001')) as v;
select is((select v->>'status' from r),'queued','own token queued for verification');
select is(register_purchase_verification('00000000-0000-0000-0000-00000000000a',repeat('a',64),'enc-a','czechify_core',null)->>'job_id',
  (select v->>'job_id' from r),'resubmitting queues behind the same open job');
select is(register_purchase_verification('00000000-0000-0000-0000-00000000000b',repeat('a',64),'enc-a','czechify_core',null)->>'status','account_binding_mismatch','another account cannot claim a known token');
select is(register_purchase_verification('00000000-0000-0000-0000-00000000000a',repeat('a',64),'enc-a','czechify_ai',null)->>'status','account_binding_mismatch','a token cannot switch product');

-- Leases are fenced.
select is(claim_billing_job((select (v->>'job_id')::uuid from r),'worker-1',60),1::bigint,'first lease gets fence 1');
select is(claim_billing_job((select (v->>'job_id')::uuid from r),'worker-2',60),null,'live lease blocks a second worker');
select is(get_billing_job_purchase((select (v->>'job_id')::uuid from r),1,'worker-2'),null,'another worker cannot read the token');
select is(get_billing_job_purchase((select (v->>'job_id')::uuid from r),1,'worker-1')->>'encrypted_token','enc-a','lease owner reads the encrypted token');
select is(apply_play_verification((select (v->>'job_id')::uuid from r),0,'worker-1','{}')->>'status','stale_lease','stale fence cannot apply');

-- Play binding must match the owner's frozen binding. (A binding that is
-- another Czechify account's moves the purchase to it: purchase_ownership.)
select is(apply_play_verification((select (v->>'job_id')::uuid from r),1,'worker-1',jsonb_build_object(
  'state','active','valid_until',now()+interval '30 days','verified_at',now(),'auto_renewing',true,'acknowledged',false,
  'product_id','czechify_core','base_plan_id','monthly','obfuscated_account_id','bindingNOBODYAAAAAAA','raw_state','SUBSCRIPTION_STATE_ACTIVE'))->>'status',
  'account_binding_mismatch','purchase made for an unknown account is not provisioned');
select is(get_monetization_snapshot('00000000-0000-0000-0000-00000000000a')->'features'->'core'->>'state','inactive','mismatch grants nothing');

-- A correct verification provisions before any acknowledgement exists.
create temp table r2 as select register_purchase_verification('00000000-0000-0000-0000-00000000000a',repeat('b',64),'enc-b','czechify_core',null) as v;
select is(claim_billing_job((select (v->>'job_id')::uuid from r2),'worker-1',60),1::bigint,'new purchase leases');
select is(apply_play_verification((select (v->>'job_id')::uuid from r2),1,'worker-1',jsonb_build_object(
  'state','pending','valid_until',now(),'verified_at',now()-interval '1 minute','auto_renewing',false,'acknowledged',false,
  'product_id','czechify_core','base_plan_id','monthly','obfuscated_account_id','bindingAAAAAAAAAAAAA','raw_state','SUBSCRIPTION_STATE_PENDING'))->>'ack_job_id',
  null,'pending purchase is not acknowledged');
select is(get_monetization_snapshot('00000000-0000-0000-0000-00000000000a')->'features'->'core'->>'state','inactive','pending grants nothing');

select is(register_purchase_verification('00000000-0000-0000-0000-00000000000a',repeat('b',64),'enc-b','czechify_core',null)->>'status','queued','a later restore queues a fresh verification');
create temp table r3 as select (select id from monetization_private.billing_jobs where purchase_id=(select (v->>'purchase_id')::uuid from r2) and state='ready') as job;
select is(claim_billing_job((select job from r3),'worker-1',60),1::bigint,'fresh verify job leases');
create temp table applied as select apply_play_verification((select job from r3),1,'worker-1',jsonb_build_object(
  'state','active','valid_until',now()+interval '30 days','verified_at',now(),'auto_renewing',true,'acknowledged',false,
  'product_id','czechify_core','base_plan_id','monthly','obfuscated_account_id','bindingAAAAAAAAAAAAA','raw_state','SUBSCRIPTION_STATE_ACTIVE')) as v;
select is((select v->>'status' from applied),'provisioned','active purchase provisioned');
select ok((select (v->>'access')::boolean from applied),'active purchase grants access');
select is(get_monetization_snapshot('00000000-0000-0000-0000-00000000000a')->'features'->'core'->>'state','active','snapshot shows Core');
select is(get_monetization_snapshot('00000000-0000-0000-0000-00000000000a')->'features'->'ai_chat'->>'state','inactive','Core purchase does not grant AI');
select is((select acknowledgement_state from monetization_private.store_purchases where token_digest=repeat('b',64)),'pending','not acknowledged until the job runs');

-- Acknowledgement is its own fenced job, created by provisioning.
select is(claim_billing_job((select (v->>'ack_job_id')::uuid from applied),'worker-1',60),1::bigint,'ack job leases');
select ok(not complete_billing_acknowledgement((select (v->>'ack_job_id')::uuid from applied),1,'worker-2'),'wrong owner cannot complete ack');
select ok(complete_billing_acknowledgement((select (v->>'ack_job_id')::uuid from applied),1,'worker-1'),'lease owner completes ack');
select is((select acknowledgement_state from monetization_private.store_purchases where token_digest=repeat('b',64)),'acknowledged','purchase marked acknowledged');

-- Failures back off and keep the last verified access.
select register_purchase_verification('00000000-0000-0000-0000-00000000000a',repeat('b',64),'enc-b','czechify_core',null);
create temp table r4 as select (select id from monetization_private.billing_jobs where purchase_id=(select (v->>'purchase_id')::uuid from r2) and operation='verify' and state='ready') as job;
select is(claim_billing_job((select job from r4),'worker-1',60),1::bigint,'retry job leases');
select ok(fail_billing_job((select job from r4),1,'worker-1','play_unavailable',60,false),'failure recorded');
select is(claim_billing_job((select job from r4),'worker-1',60),null,'backoff blocks an early retry');
select is(get_monetization_snapshot('00000000-0000-0000-0000-00000000000a')->'features'->'core'->>'state','active','failed refresh keeps verified access');

-- Status is owner-scoped and token-free.
select is(get_purchase_verification_status('00000000-0000-0000-0000-00000000000b',(select (v->>'purchase_id')::uuid from r2)),null,'another account cannot read status');
select ok(not (get_purchase_verification_status('00000000-0000-0000-0000-00000000000a',(select (v->>'purchase_id')::uuid from r2))::text like '%enc-b%'),'status never includes the token');

-- A deleted owner leaves a tombstone nobody else can claim.
delete from auth.users where id='00000000-0000-0000-0000-00000000000a';
select is((select user_id from monetization_private.store_purchases where token_digest=repeat('b',64)),null,'purchase owner tombstoned');
select is(register_purchase_verification('00000000-0000-0000-0000-00000000000b',repeat('b',64),'enc-b','czechify_core',null)->>'status','account_binding_mismatch','tombstoned token is not reassigned');
select * from finish();
rollback;
