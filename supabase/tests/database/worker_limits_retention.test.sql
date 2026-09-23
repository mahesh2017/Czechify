begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path = public;
select no_plan();

insert into auth.users(id,email,is_anonymous) values
 ('76000000-0000-0000-0000-00000000000a','prober@example.com',false),
 ('76000000-0000-0000-0000-00000000000b','buyer@example.com',false);
create temp table ids as select '76000000-0000-0000-0000-00000000000a'::uuid prober,
  '76000000-0000-0000-0000-00000000000b'::uuid buyer;

select ok(not has_function_privilege('authenticated','public.allow_purchase_verification(uuid,integer)','EXECUTE'),'clients cannot spend or reset the limit');

-- 1. Purchase checks per hour.
select ok(bool_and(allow_purchase_verification((select prober from ids),30)),'thirty checks in an hour are allowed')
  from generate_series(1,30);
select ok(not allow_purchase_verification((select prober from ids),30),'the next one is refused');
select is((select count(*)::integer from monetization_private.purchase_verify_attempts where user_id=(select prober from ids)),30,'a refused check is not recorded');
select ok(allow_purchase_verification((select buyer from ids),30),'other accounts are unaffected');
update monetization_private.purchase_verify_attempts set attempted_at=now()-interval '61 minutes' where user_id=(select prober from ids);
select ok(allow_purchase_verification((select prober from ids),30),'an hour later the account can check again');
select throws_ok($$select allow_purchase_verification(null,30)$$,'22023',null,'an account is required');

-- Purchases for the rest.
create function pg_temp.purchase(p_digit text,p_owner uuid,p_state text,p_valid interval,p_created interval) returns uuid language sql as $$
  insert into monetization_private.store_purchases(platform,token_digest,encrypted_token,user_id,product_id,base_plan_id,
      lineage_id,state,valid_until,last_verified_at,created_at)
    values('android',repeat(p_digit,64),'sealed',p_owner,'czechify_core','monthly',gen_random_uuid(),p_state,
      case when p_state is null then null else now()-p_valid end,
      case when p_state is null then null else now()-p_valid end,now()-p_created)
  returning id $$;

-- 2. Dead jobs: only recent ones raise the alert.
create temp table dead as select pg_temp.purchase('1',(select buyer from ids),'active',interval '-20 days',interval '40 days') id;
insert into monetization_private.billing_jobs(purchase_id,operation,state,updated_at)
  values((select id from dead),'verify','dead',now()-interval '3 days');
select is((billing_health()->>'dead_jobs')::integer,0,'a job that died days ago is not counted as new');
select ok(not exists (select 1 from jsonb_array_elements(monetization_operations_report()->'alerts') a
  where a->>'alert'='billing_jobs_dead'),'and raises no alert');
select is((monetization_operations_report()->>'dead_billing_jobs')::integer,1,'the total is still reported');
insert into monetization_private.billing_jobs(purchase_id,operation,state)
  values((select id from dead),'acknowledge','dead');
select is((billing_health()->>'dead_jobs')::integer,1,'a job that died today is counted');
select ok(exists (select 1 from jsonb_array_elements(monetization_operations_report()->'alerts') a
  where a->>'alert'='billing_jobs_dead'),'and raises the alert');
delete from monetization_private.billing_jobs where purchase_id=(select id from dead);

-- 3. A deleted account's purchase, whose state nothing re-checks.
select pg_temp.purchase('2',null,'active',interval '130 days',interval '200 days');
select pg_temp.purchase('3',null,'canceled',interval '100 days',interval '200 days');
select pg_temp.purchase('4',null,'paused',interval '10 days',interval '200 days');

-- Tokens that never became a purchase.
select pg_temp.purchase('5',(select prober from ids),null,null,interval '31 days');
select pg_temp.purchase('6',(select prober from ids),null,null,interval '10 days');
create temp table queued as select pg_temp.purchase('7',(select prober from ids),null,null,interval '31 days') id;
insert into monetization_private.billing_jobs(purchase_id,operation) values((select id from queued),'verify');
create temp table disputed as select pg_temp.purchase('8',(select prober from ids),null,null,interval '31 days') id;
insert into monetization_private.purchase_recovery_cases(purchase_id,requester_id,reason)
  values((select id from disputed),(select buyer from ids),'other_account');

update monetization_private.purchase_verify_attempts set attempted_at=now()-interval '2 days';
create temp table run as select cleanup_privacy_records() r;
create function pg_temp.kept(p_digit text) returns boolean language sql as $$
  select exists (select 1 from monetization_private.store_purchases where token_digest=repeat(p_digit,64)) $$;

select ok(not pg_temp.kept('2'),'an ownerless purchase last seen active goes 120 days after its paid-through date');
select ok(pg_temp.kept('3'),'one within 120 days stays, in case Play still holds it');
select ok(pg_temp.kept('4'),'a recent pause stays');
select ok(pg_temp.kept('1'),'a live account''s purchase is untouched');
select is(((select r from run)->>'ownerless_purchases')::integer,1,'one ownerless purchase was removed');
select ok(not pg_temp.kept('5'),'a token Play never confirmed goes after 30 days');
select ok(pg_temp.kept('6'),'a recent one stays');
select ok(pg_temp.kept('7'),'one still being checked stays');
select ok(pg_temp.kept('8'),'one with an open support case stays');
select is(((select r from run)->>'unconfirmed_tokens')::integer,1,'the worker is told');
select is(((select r from run)->>'verify_attempts')::integer,32,'check records go after a day');
select is(cleanup_privacy_records()->>'ownerless_purchases','0','retention is idempotent');

select * from finish();
rollback;
