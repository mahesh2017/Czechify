begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path = public;
select no_plan();

insert into auth.users(id) values ('00000000-0000-0000-0000-0000000000c1'),('00000000-0000-0000-0000-0000000000c2');
select billing_bind_account('00000000-0000-0000-0000-0000000000c1','bindingCCCCCCCCCCCCC',1::smallint);
select billing_bind_account('00000000-0000-0000-0000-0000000000c2','bindingDDDDDDDDDDDDD',1::smallint);

select ok(not has_function_privilege('authenticated','public.record_play_notification(text,text,text,integer,text,timestamptz)','EXECUTE'), 'clients cannot inject notifications');
select ok(not has_function_privilege('anon','public.due_billing_jobs(integer)','EXECUTE'), 'anonymous callers cannot list jobs');
select ok(not has_function_privilege('service_role','private.queue_billing_refresh(uuid,text)','EXECUTE'), 'queue helper is internal');
select ok(has_function_privilege('service_role','public.enqueue_billing_reconciliation(integer)','EXECUTE'), 'worker can queue reconciliation');

-- Verifies a registered purchase with the given state and verification time.
create function pg_temp.verified(p_user uuid, p_digest text, p_state text, p_valid interval, p_verified interval)
returns uuid language plpgsql as $$
declare reg jsonb; fence bigint;
begin
  reg := register_purchase_verification(p_user, p_digest, 'enc', 'czechify_core', null);
  fence := claim_billing_job((reg->>'job_id')::uuid, 'setup', 60);
  perform apply_play_verification((reg->>'job_id')::uuid, fence, 'setup', jsonb_build_object(
    'state', p_state, 'valid_until', now() + p_valid, 'verified_at', now() - p_verified,
    'auto_renewing', true, 'acknowledged', true, 'product_id', 'czechify_core', 'base_plan_id', 'monthly',
    'obfuscated_account_id', (select obfuscated_account_id from monetization_private.billing_account_bindings where user_id = p_user),
    'raw_state', 'test'));
  return (reg->>'purchase_id')::uuid;
end;
$$;
create temp table p as select
  pg_temp.verified('00000000-0000-0000-0000-0000000000c1', repeat('1',64), 'active', interval '20 days', interval '2 days') as stale,
  pg_temp.verified('00000000-0000-0000-0000-0000000000c1', repeat('2',64), 'active', interval '20 days', interval '10 minutes') as fresh,
  pg_temp.verified('00000000-0000-0000-0000-0000000000c1', repeat('3',64), 'pending', interval '0 days', interval '2 hours') as pending,
  pg_temp.verified('00000000-0000-0000-0000-0000000000c1', repeat('4',64), 'expired', interval '-5 days', interval '5 days') as expired,
  pg_temp.verified('00000000-0000-0000-0000-0000000000c1', repeat('5',64), 'canceled', interval '6 hours', interval '3 hours') as ending,
  pg_temp.verified('00000000-0000-0000-0000-0000000000c2', repeat('6',64), 'active', interval '20 days', interval '2 days') as deleted_owner;
select is((select count(*)::integer from monetization_private.billing_jobs where operation in ('verify','reconcile') and state in ('ready','retry','running')),0,'setup leaves no open refresh jobs');

-- Intake is idempotent per message and never provisions by itself.
select is(record_play_notification('projects/p/subscriptions/s','m-1','subscription',2,repeat('2',64),now()),'queued','known token queues a refresh');
select is(record_play_notification('projects/p/subscriptions/s','m-1','subscription',2,repeat('2',64),now()),'duplicate','redelivery is recognized');
select is((select count(*)::integer from monetization_private.billing_notification_inbox),1,'redelivery stores nothing new');
select is((select count(*)::integer from monetization_private.billing_jobs where purchase_id=(select fresh from p) and operation='verify' and state='ready'),1,'exactly one refresh queued');
select is(record_play_notification('projects/p/subscriptions/s','m-2','subscription',2,repeat('2',64),now()),'queued','second message for the same purchase');
select is((select count(*)::integer from monetization_private.billing_jobs where purchase_id=(select fresh from p) and state in ('ready','retry','running')),1,'waiting refresh is reused, not duplicated');
select is(record_play_notification('projects/p/subscriptions/s','m-3','subscription',4,repeat('f',64),now()),'unmatched','unknown token is kept but grants nothing');
select is(record_play_notification('projects/p/subscriptions/s','m-4','test',null,null,now()),'ignored','test notification is acknowledged and ignored');
select is(record_play_notification('projects/p/subscriptions/s','m-5','voided',null,repeat('1',64),now()),'queued','voided purchase triggers a refresh');
select is(get_monetization_snapshot('00000000-0000-0000-0000-0000000000c1')->'features'->'core'->>'state','active','a notification alone changes no access');

-- A backing-off refresh is brought forward by a notification.
update monetization_private.billing_jobs set state='retry', not_before=now()+interval '30 minutes'
  where purchase_id=(select stale from p) and operation='verify' and state='ready';
select is(record_play_notification('projects/p/subscriptions/s','m-6','subscription',3,repeat('1',64),now()),'queued','notification during backoff');
select ok((select not_before <= now() from monetization_private.billing_jobs where purchase_id=(select stale from p) and operation='verify' and state='retry'),'backoff is cut short');

-- A notification during a running refresh queues one more behind it.
select claim_billing_job((select id from monetization_private.billing_jobs where purchase_id=(select fresh from p) and operation='verify' and state='ready'),'worker',60);
select is(record_play_notification('projects/p/subscriptions/s','m-7','subscription',2,repeat('2',64),now()),'queued','notification while refresh runs');
select is((select count(*)::integer from monetization_private.billing_jobs where purchase_id=(select fresh from p) and operation='reconcile' and state='ready'),1,'a follow-up refresh waits behind the running one');
select is(claim_billing_job((select id from monetization_private.billing_jobs where purchase_id=(select fresh from p) and operation='reconcile'),'worker-2',60),null,'follow-up cannot run beside the live lease');

-- Reconciliation picks stale, ending and hourly-pending purchases only. The
-- deleted owner's purchase is excluded.
delete from auth.users where id='00000000-0000-0000-0000-0000000000c2';
delete from monetization_private.billing_jobs where purchase_id in (select stale from p union all select pending from p union all select expired from p union all select ending from p);
select is(enqueue_billing_reconciliation(100),3,'three purchases due for reconciliation');
select is((select array_agg(purchase_id order by purchase_id) from monetization_private.billing_jobs where operation='reconcile' and state='ready' and purchase_id <> (select fresh from p)),
  (select array_agg(x order by x) from (select stale x from p union all select pending from p union all select ending from p) s),'stale, pending and near-expiry purchases queued');
select is(enqueue_billing_reconciliation(100),0,'queued reconciliations are not duplicated');
update monetization_private.billing_jobs set state='retry', not_before=now()+interval '20 minutes'
  where purchase_id=(select stale from p) and operation='reconcile';
select is(enqueue_billing_reconciliation(100),0,'a purchase in backoff is not queued again');
select ok((select not_before > now() from monetization_private.billing_jobs where purchase_id=(select stale from p) and operation='reconcile'),'reconciliation never cancels a backoff');

-- Due order: acknowledgements first; expired leases are recoverable.
insert into monetization_private.billing_jobs(purchase_id, operation, not_before) values ((select expired from p),'acknowledge',now()-interval '1 minute');
select is((select due from due_billing_jobs(1) due),(select id from monetization_private.billing_jobs where operation='acknowledge' and state='ready'),'acknowledgement is served first');
update monetization_private.billing_jobs set lease_expires_at=now()-interval '1 second'
  where purchase_id=(select fresh from p) and operation='verify' and state='running';
select ok((select id from monetization_private.billing_jobs where purchase_id=(select fresh from p) and operation='verify' and state='running') in (select due_billing_jobs(200)),'a job with an expired lease is due again');
update monetization_private.billing_jobs set state='retry', not_before=now()+interval '1 hour' where operation='acknowledge' and state='ready';
select ok((select id from monetization_private.billing_jobs where operation='acknowledge') not in (select due_billing_jobs(200)),'backing-off jobs are not due');

-- Health counts, and a deleted owner's token stops matching.
update monetization_private.store_purchases set acknowledgement_state='pending' where id=(select stale from p);
select is((billing_health()->>'unacknowledged_over_1h')::integer,1,'unacknowledged paid purchase is counted');
select is((billing_health()->>'unmatched_notifications_24h')::integer,1,'unmatched notification is counted');
select is(record_play_notification('projects/p/subscriptions/s','m-8','subscription',2,repeat('6',64),now()),'unmatched','a tombstoned purchase is not refreshed for anyone');
select * from finish();
rollback;
