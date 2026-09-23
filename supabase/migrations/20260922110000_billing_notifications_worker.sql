-- Play real-time notification intake and the scheduled billing worker.
-- A notification is only a hint to re-fetch Play; it never grants anything
-- itself. The worker processes due jobs and queues periodic reconciliation.
begin;

create table monetization_private.billing_notification_inbox (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider = 'google_play'),
  subscription_resource text not null check (length(subscription_resource) between 1 and 300),
  message_id text not null check (length(message_id) between 1 and 200),
  notification_kind text not null check (notification_kind in ('subscription','voided','test','other')),
  notification_type integer,
  token_digest text check (token_digest ~ '^[0-9a-f]{64}$'),
  purchase_id uuid references monetization_private.store_purchases(id) on delete set null,
  outcome text not null check (outcome in ('queued','unmatched','ignored')),
  event_time timestamptz,
  received_at timestamptz not null default now(),
  unique (provider, subscription_resource, message_id)
);
create index billing_notification_inbox_received on monetization_private.billing_notification_inbox(received_at);
alter table monetization_private.billing_notification_inbox enable row level security;
revoke all on monetization_private.billing_notification_inbox from public, anon, authenticated, service_role;

-- Queues a Play refresh, or brings a waiting one forward. A notification
-- arriving while a refresh is already running queues one more behind it
-- (the lineage lease runs them in turn), because the running one may have
-- read Play before the change. Reconciliation never piles up behind one.
create function private.queue_billing_refresh(p_purchase uuid, p_operation text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare job_id uuid;
begin
  update monetization_private.billing_jobs set not_before = least(not_before, now()), updated_at = now()
    where purchase_id = p_purchase and operation in ('verify','reconcile')
      and state in ('ready','retry')
    returning id into job_id;
  if job_id is not null then return job_id; end if;
  if p_operation = 'reconcile' and exists (select 1 from monetization_private.billing_jobs
      where purchase_id = p_purchase and operation in ('verify','reconcile') and state = 'running') then
    return null;
  end if;
  insert into monetization_private.billing_jobs(purchase_id, operation)
    values (p_purchase, p_operation) on conflict do nothing returning id into job_id;
  if job_id is null then
    -- The same operation is running; the other one queues behind it.
    insert into monetization_private.billing_jobs(purchase_id, operation)
      values (p_purchase, case when p_operation = 'verify' then 'reconcile' else 'verify' end)
      on conflict do nothing returning id into job_id;
  end if;
  return job_id;
end;
$$;

-- Durably records one authenticated push message. Returns duplicate for a
-- redelivery already stored, so the endpoint can acknowledge it again.
-- Unknown tokens are kept as unmatched: without a registered owner there is
-- nobody to provision, and the owner's own verify call will fetch Play.
create function public.record_play_notification(p_subscription text, p_message_id text,
  p_kind text, p_type integer, p_token_digest text, p_event_time timestamptz)
returns text language plpgsql security definer set search_path = '' as $$
declare purchase uuid; result text; inserted uuid;
begin
  if p_token_digest is not null then
    select id into purchase from monetization_private.store_purchases
      where token_digest = p_token_digest and user_id is not null;
  end if;
  result := case when p_kind not in ('subscription','voided') then 'ignored'
    when purchase is null then 'unmatched' else 'queued' end;
  insert into monetization_private.billing_notification_inbox(provider, subscription_resource, message_id,
    notification_kind, notification_type, token_digest, purchase_id, outcome, event_time)
    values ('google_play', p_subscription, p_message_id, p_kind, p_type, p_token_digest, purchase,
      result, p_event_time)
    on conflict (provider, subscription_resource, message_id) do nothing
    returning id into inserted;
  if inserted is null then return 'duplicate'; end if;
  if result = 'queued' then perform private.queue_billing_refresh(purchase, 'verify'); end if;
  return result;
end;
$$;

-- Purchases whose Play state should be re-read: anything that grants or may
-- soon change access and was not verified in the last day, anything near its
-- paid-through time, and pending purchases hourly. A purchase with an open
-- refresh is skipped: bringing it forward here would cancel its backoff on
-- every scheduler run.
create function public.enqueue_billing_reconciliation(p_limit integer)
returns integer language plpgsql security definer set search_path = '' as $$
declare queued integer := 0; p record;
begin
  for p in select s.id from monetization_private.store_purchases s
    where s.user_id is not null
      and not exists (select 1 from monetization_private.billing_jobs j where j.purchase_id = s.id
        and j.operation in ('verify','reconcile') and j.state in ('ready','running','retry'))
      and (
      (state in ('active','in_grace_period','canceled','on_hold','paused')
        and (last_verified_at < now() - interval '1 day'
          or valid_until between now() - interval '1 day' and now() + interval '1 day')
        and coalesce(last_verified_at, '-infinity') < now() - interval '1 hour')
      or (state = 'pending' and last_verified_at < now() - interval '1 hour'))
    order by last_verified_at nulls first
    limit greatest(0, least(p_limit, 500))
  loop
    if private.queue_billing_refresh(p.id, 'reconcile') is not null then queued := queued + 1; end if;
  end loop;
  return queued;
end;
$$;

-- Due jobs, acknowledgements first. Includes running jobs whose lease expired.
create function public.due_billing_jobs(p_limit integer)
returns setof uuid language sql stable security definer set search_path = '' as $$
  select id from monetization_private.billing_jobs
  where (state in ('ready','retry') and not_before <= now())
     or (state = 'running' and lease_expires_at <= now())
  order by (operation = 'acknowledge') desc, not_before
  limit greatest(0, least(p_limit, 200));
$$;

-- Counts for alerting. No tokens and no account identifiers.
create function public.billing_health()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'unacknowledged_over_1h', (select count(*) from monetization_private.store_purchases p
      where p.acknowledgement_state = 'pending'
        and p.state in ('active','in_grace_period','canceled') and p.valid_until > now()
        and p.last_verified_at < now() - interval '1 hour'),
    'dead_jobs', (select count(*) from monetization_private.billing_jobs where state = 'dead'),
    'oldest_due_seconds', (select coalesce(extract(epoch from now() - min(not_before))::integer, 0)
      from monetization_private.billing_jobs where state in ('ready','retry') and not_before <= now()),
    'unmatched_notifications_24h', (select count(*) from monetization_private.billing_notification_inbox
      where outcome = 'unmatched' and received_at > now() - interval '1 day'));
$$;

revoke all on function
  private.queue_billing_refresh(uuid,text),
  public.record_play_notification(text,text,text,integer,text,timestamptz),
  public.enqueue_billing_reconciliation(integer),
  public.due_billing_jobs(integer),
  public.billing_health()
  from public, anon, authenticated;
grant execute on function
  public.record_play_notification(text,text,text,integer,text,timestamptz),
  public.enqueue_billing_reconciliation(integer),
  public.due_billing_jobs(integer),
  public.billing_health()
  to service_role;
commit;
