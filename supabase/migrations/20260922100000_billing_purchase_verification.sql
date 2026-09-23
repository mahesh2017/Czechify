-- Play subscription verification: products, account bindings, purchase
-- intents, verified purchases and fenced verification/acknowledgement jobs.
-- Every table is private. Edge Functions reach them only through the
-- service-role RPCs below, after authenticating the caller themselves.
begin;

create table monetization_private.billing_products (
  platform text not null check (platform = 'android'),
  product_id text not null check (length(product_id) between 1 and 100),
  base_plan_id text not null check (length(base_plan_id) between 1 and 100),
  feature text not null check (feature in ('core','ai_chat')),
  enabled boolean not null default false,
  primary key (platform, product_id, base_plan_id),
  unique (platform, product_id)
);
-- Disabled until a staging or production project deliberately enables them.
insert into monetization_private.billing_products(platform, product_id, base_plan_id, feature)
values ('android','czechify_core','monthly','core'), ('android','czechify_ai','monthly','ai_chat');

-- The Play obfuscated account ID is derived once by the Edge Function (HMAC of
-- the user ID) and then frozen here, so rotating that key never changes the
-- binding of a purchase that already exists.
create table monetization_private.billing_account_bindings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  obfuscated_account_id text not null unique check (obfuscated_account_id ~ '^[A-Za-z0-9_-]{16,64}$'),
  key_version smallint not null check (key_version > 0),
  created_at timestamptz not null default now()
);

create table monetization_private.purchase_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null,
  product_id text not null,
  base_plan_id text not null,
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  unique (user_id, idempotency_key),
  foreign key (platform, product_id, base_plan_id)
    references monetization_private.billing_products(platform, product_id, base_plan_id)
);
create index purchase_intents_rate on monetization_private.purchase_intents(user_id, created_at);

-- user_id is null only after the owner's account was deleted. A null owner is
-- a tombstone: another account presenting the same token is never given it.
create table monetization_private.store_purchases (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform = 'android'),
  token_digest text not null unique check (token_digest ~ '^[0-9a-f]{64}$'),
  encrypted_token text not null check (length(encrypted_token) between 1 and 32768),
  user_id uuid references auth.users(id) on delete set null,
  product_id text not null,
  base_plan_id text not null,
  lineage_id uuid not null,
  linked_token_digest text check (linked_token_digest ~ '^[0-9a-f]{64}$'),
  state text check (state in ('pending','active','in_grace_period','canceled','on_hold','paused','expired','revoked')),
  raw_state text,
  valid_until timestamptz,
  auto_renewing boolean,
  acknowledgement_state text not null default 'pending' check (acknowledgement_state in ('pending','acknowledged')),
  last_verified_at timestamptz,
  response_fingerprint text,
  last_error_code text,
  created_at timestamptz not null default now(),
  foreign key (platform, product_id, base_plan_id)
    references monetization_private.billing_products(platform, product_id, base_plan_id)
);
create index store_purchases_owner on monetization_private.store_purchases(user_id);
create index store_purchases_lineage on monetization_private.store_purchases(lineage_id);

create table monetization_private.billing_jobs (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references monetization_private.store_purchases(id) on delete cascade,
  operation text not null check (operation in ('verify','acknowledge','reconcile')),
  state text not null default 'ready' check (state in ('ready','running','retry','done','dead')),
  attempts integer not null default 0,
  not_before timestamptz not null default now(),
  lease_owner text,
  lease_expires_at timestamptz,
  fence bigint not null default 0,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- One open job per purchase and operation; duplicates queue behind it.
create unique index billing_jobs_open_once on monetization_private.billing_jobs(purchase_id, operation)
  where state in ('ready','running','retry');
create index billing_jobs_due on monetization_private.billing_jobs(not_before) where state in ('ready','retry');

create table monetization_private.billing_audit_events (
  id bigint generated always as identity primary key,
  purchase_id uuid references monetization_private.store_purchases(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  event text not null,
  detail text,
  created_at timestamptz not null default now()
);

alter table monetization_private.billing_products enable row level security;
alter table monetization_private.billing_account_bindings enable row level security;
alter table monetization_private.purchase_intents enable row level security;
alter table monetization_private.store_purchases enable row level security;
alter table monetization_private.billing_jobs enable row level security;
alter table monetization_private.billing_audit_events enable row level security;
revoke all on all tables in schema monetization_private from public, anon, authenticated, service_role;
revoke all on all sequences in schema monetization_private from public, anon, authenticated, service_role;

create function public.billing_bind_account(p_user uuid, p_candidate text, p_key_version smallint)
returns text language plpgsql security definer set search_path = '' as $$
declare bound text;
begin
  insert into monetization_private.billing_account_bindings(user_id, obfuscated_account_id, key_version)
    values (p_user, p_candidate, p_key_version) on conflict (user_id) do nothing;
  select obfuscated_account_id into bound
    from monetization_private.billing_account_bindings where user_id = p_user;
  return bound;
end;
$$;

-- Returns {status, ...}. Statuses: created, product_unavailable, rate_limited.
create function public.create_purchase_intent(p_user uuid, p_product text, p_base_plan text,
  p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare intent monetization_private.purchase_intents; bound text;
begin
  select obfuscated_account_id into bound
    from monetization_private.billing_account_bindings where user_id = p_user;
  if bound is null then raise exception 'Account is not bound' using errcode = '22023'; end if;
  select * into intent from monetization_private.purchase_intents
    where user_id = p_user and idempotency_key = p_idempotency_key;
  if found then
    if intent.product_id <> p_product or intent.base_plan_id <> p_base_plan then
      return jsonb_build_object('status','idempotency_conflict');
    end if;
  else
    if not exists (select 1 from monetization_private.billing_products
      where platform = 'android' and product_id = p_product and base_plan_id = p_base_plan and enabled) then
      return jsonb_build_object('status','product_unavailable');
    end if;
    if (select count(*) from monetization_private.purchase_intents
        where user_id = p_user and created_at > now() - interval '1 hour') >= 10 then
      return jsonb_build_object('status','rate_limited');
    end if;
    insert into monetization_private.purchase_intents(user_id, platform, product_id, base_plan_id,
      idempotency_key, expires_at)
      values (p_user, 'android', p_product, p_base_plan, p_idempotency_key, now() + interval '30 minutes')
      returning * into intent;
  end if;
  return jsonb_build_object('status','created','intent_id',intent.id,'expires_at',intent.expires_at,
    'obfuscated_account_id',bound,'product_id',intent.product_id,'base_plan_id',intent.base_plan_id);
end;
$$;

-- Records a token the authenticated caller submitted and queues its
-- verification. Knowing a token never binds it to the caller: an existing
-- purchase owned by anyone else (or by a deleted account) is refused.
-- Statuses: queued, account_binding_mismatch, product_unavailable.
create function public.register_purchase_verification(p_user uuid, p_token_digest text,
  p_encrypted_token text, p_product text, p_intent uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare purchase monetization_private.store_purchases; product monetization_private.billing_products;
  job_id uuid;
begin
  select * into product from monetization_private.billing_products
    where platform = 'android' and product_id = p_product;
  if not found then return jsonb_build_object('status','product_unavailable'); end if;
  if p_intent is not null then
    update monetization_private.purchase_intents set consumed_at = coalesce(consumed_at, now())
      where id = p_intent and user_id = p_user and product_id = p_product;
    if not found then return jsonb_build_object('status','product_unavailable'); end if;
  end if;
  insert into monetization_private.store_purchases(platform, token_digest, encrypted_token, user_id,
    product_id, base_plan_id, lineage_id)
    values ('android', p_token_digest, p_encrypted_token, p_user, p_product, product.base_plan_id,
      gen_random_uuid())
    on conflict (token_digest) do nothing;
  select * into purchase from monetization_private.store_purchases
    where token_digest = p_token_digest for update;
  if purchase.user_id is distinct from p_user or purchase.product_id <> p_product then
    insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
      values (purchase.id, p_user, 'foreign_token_submitted');
    return jsonb_build_object('status','account_binding_mismatch');
  end if;
  insert into monetization_private.billing_jobs(purchase_id, operation)
    values (purchase.id, 'verify') on conflict do nothing;
  select id into job_id from monetization_private.billing_jobs
    where purchase_id = purchase.id and operation = 'verify' and state in ('ready','running','retry');
  return jsonb_build_object('status','queued','purchase_id',purchase.id,'job_id',job_id);
end;
$$;

-- Leases a due job with a new fencing number. Returns null when the job is
-- finished, leased elsewhere, backing off, or another job of the same
-- purchase lineage holds a live lease.
create function public.claim_billing_job(p_job uuid, p_owner text, p_lease_seconds integer)
returns bigint language plpgsql security definer set search_path = '' as $$
declare job monetization_private.billing_jobs; lineage uuid; next_fence bigint;
begin
  if p_lease_seconds not between 5 and 600 or length(p_owner) not between 1 and 100 then
    raise exception 'Invalid lease request' using errcode = '22023';
  end if;
  select p.lineage_id into lineage from monetization_private.billing_jobs j
    join monetization_private.store_purchases p on p.id = j.purchase_id where j.id = p_job;
  if lineage is null then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended(lineage::text, 0));
  select * into job from monetization_private.billing_jobs where id = p_job for update;
  if job.state in ('done','dead') or job.not_before > now()
     or (job.state = 'running' and job.lease_expires_at > now()) then
    return null;
  end if;
  if exists (select 1 from monetization_private.billing_jobs j
      join monetization_private.store_purchases p on p.id = j.purchase_id
      where p.lineage_id = lineage and j.id <> p_job and j.state = 'running'
        and j.lease_expires_at > now()) then
    return null;
  end if;
  update monetization_private.billing_jobs set state = 'running', attempts = attempts + 1,
    fence = fence + 1, lease_owner = p_owner,
    lease_expires_at = now() + make_interval(secs => p_lease_seconds), updated_at = now()
    where id = p_job returning fence into next_fence;
  return next_fence;
end;
$$;

create function private.billing_lease_is_current(p_job uuid, p_fence bigint, p_owner text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from monetization_private.billing_jobs where id = p_job
    and state = 'running' and fence = p_fence and lease_owner = p_owner and lease_expires_at > now());
$$;

-- Applies a Play response normalized by the Edge Function. Rechecks the lease
-- first, so a stale worker can never overwrite a newer result, then checks
-- the Play account binding against the purchase owner's frozen binding.
-- Statuses: provisioned, stale_lease, account_binding_mismatch, product_mismatch.
create function public.apply_play_verification(p_job uuid, p_fence bigint, p_owner text, p_result jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare job monetization_private.billing_jobs; purchase monetization_private.store_purchases;
  product monetization_private.billing_products; bound text; linked uuid; rev bigint;
  new_state text := p_result->>'state'; valid timestamptz := (p_result->>'valid_until')::timestamptz;
  verified timestamptz := (p_result->>'verified_at')::timestamptz; ack_job uuid; grants boolean;
begin
  if not private.billing_lease_is_current(p_job, p_fence, p_owner) then
    return jsonb_build_object('status','stale_lease');
  end if;
  select * into job from monetization_private.billing_jobs where id = p_job for update;
  select * into purchase from monetization_private.store_purchases where id = job.purchase_id for update;
  select * into product from monetization_private.billing_products
    where platform = purchase.platform and product_id = purchase.product_id;
  if purchase.user_id is null then
    update monetization_private.billing_jobs set state = 'done', last_error_code = 'owner_deleted',
      lease_owner = null, lease_expires_at = null, updated_at = now() where id = p_job;
    return jsonb_build_object('status','account_binding_mismatch');
  end if;
  if p_result->>'product_id' is distinct from purchase.product_id
     or p_result->>'base_plan_id' is distinct from product.base_plan_id then
    update monetization_private.billing_jobs set state = 'dead', last_error_code = 'product_mismatch',
      lease_owner = null, lease_expires_at = null, updated_at = now() where id = p_job;
    insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
      values (purchase.id, purchase.user_id, 'product_mismatch');
    return jsonb_build_object('status','product_mismatch');
  end if;
  select obfuscated_account_id into bound from monetization_private.billing_account_bindings
    where user_id = purchase.user_id;
  if bound is null or p_result->>'obfuscated_account_id' is distinct from bound then
    update monetization_private.store_purchases set last_error_code = 'account_binding_mismatch'
      where id = purchase.id;
    update monetization_private.billing_jobs set state = 'done', last_error_code = 'account_binding_mismatch',
      lease_owner = null, lease_expires_at = null, updated_at = now() where id = p_job;
    insert into monetization_private.billing_audit_events(purchase_id, user_id, event)
      values (purchase.id, purchase.user_id, 'account_binding_mismatch');
    return jsonb_build_object('status','account_binding_mismatch');
  end if;
  if p_result->>'linked_token_digest' is not null then
    select lineage_id into linked from monetization_private.store_purchases
      where token_digest = p_result->>'linked_token_digest' and user_id = purchase.user_id;
  end if;
  update monetization_private.store_purchases set state = new_state, raw_state = p_result->>'raw_state',
    valid_until = valid, auto_renewing = (p_result->>'auto_renewing')::boolean,
    linked_token_digest = p_result->>'linked_token_digest', lineage_id = coalesce(linked, lineage_id),
    acknowledgement_state = case when (p_result->>'acknowledged')::boolean then 'acknowledged'
      else acknowledgement_state end,
    last_verified_at = verified, response_fingerprint = p_result->>'response_fingerprint',
    last_error_code = null
    where id = purchase.id;
  rev := public.apply_verified_feature(purchase.user_id, product.feature, 'play:' || purchase.id::text,
    new_state, valid, verified);
  grants := new_state in ('active','in_grace_period','canceled') and valid > now();
  -- Acknowledge only after provisioning commits in this same transaction.
  if grants and not (p_result->>'acknowledged')::boolean then
    insert into monetization_private.billing_jobs(purchase_id, operation)
      values (purchase.id, 'acknowledge') on conflict do nothing;
    select id into ack_job from monetization_private.billing_jobs
      where purchase_id = purchase.id and operation = 'acknowledge' and state in ('ready','running','retry');
  end if;
  update monetization_private.billing_jobs set state = 'done', last_error_code = null,
    lease_owner = null, lease_expires_at = null, updated_at = now() where id = p_job;
  insert into monetization_private.billing_audit_events(purchase_id, user_id, event, detail)
    values (purchase.id, purchase.user_id, 'verified', new_state);
  return jsonb_build_object('status','provisioned','revision',rev,'access',grants,'ack_job_id',ack_job);
end;
$$;

create function public.complete_billing_acknowledgement(p_job uuid, p_fence bigint, p_owner text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare purchase_id uuid;
begin
  if not private.billing_lease_is_current(p_job, p_fence, p_owner) then return false; end if;
  update monetization_private.billing_jobs set state = 'done', last_error_code = null,
    lease_owner = null, lease_expires_at = null, updated_at = now()
    where id = p_job and operation = 'acknowledge' returning billing_jobs.purchase_id into purchase_id;
  if purchase_id is null then return false; end if;
  update monetization_private.store_purchases set acknowledgement_state = 'acknowledged'
    where id = purchase_id;
  insert into monetization_private.billing_audit_events(purchase_id, event)
    values (purchase_id, 'acknowledged');
  return true;
end;
$$;

-- Backs a leased job off, or ends it as dead. The last verified entitlement
-- is untouched either way.
create function public.fail_billing_job(p_job uuid, p_fence bigint, p_owner text, p_error text,
  p_retry_seconds integer, p_dead boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not private.billing_lease_is_current(p_job, p_fence, p_owner) then return false; end if;
  update monetization_private.billing_jobs set
    state = case when p_dead then 'dead' else 'retry' end,
    not_before = now() + make_interval(secs => greatest(0, least(p_retry_seconds, 3600))),
    last_error_code = left(p_error, 100), lease_owner = null, lease_expires_at = null, updated_at = now()
    where id = p_job;
  return true;
end;
$$;

-- Operator switch for staging and rollout. Disabling stops new checkouts
-- (purchase intents); restores and checks of any token still run, so a
-- learner who already paid is never refused. It never changes existing
-- entitlements.
create function public.set_billing_product_enabled(p_product text, p_enabled boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update monetization_private.billing_products set enabled = p_enabled
    where platform = 'android' and product_id = p_product;
  return found;
end;
$$;

-- Owner-scoped status for GET /purchases/status/<id>. Never returns tokens.
create function public.get_purchase_verification_status(p_user uuid, p_purchase uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('purchase_id', p.id, 'product_id', p.product_id, 'state', p.state,
    'valid_until', p.valid_until, 'verification',
    case when exists (select 1 from monetization_private.billing_jobs j where j.purchase_id = p.id
        and j.operation = 'verify' and j.state in ('ready','running','retry')) then 'pending'
      when p.last_error_code is not null then p.last_error_code else 'verified' end,
    'revision', (select revision from public.monetization_accounts a where a.user_id = p_user))
  from monetization_private.store_purchases p where p.id = p_purchase and p.user_id = p_user;
$$;

-- Service code needs the encrypted token to call Play for a leased job.
create function public.get_billing_job_purchase(p_job uuid, p_fence bigint, p_owner text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('operation', j.operation, 'purchase_id', p.id, 'product_id', p.product_id,
    'encrypted_token', p.encrypted_token)
  from monetization_private.billing_jobs j join monetization_private.store_purchases p on p.id = j.purchase_id
  where j.id = p_job and private.billing_lease_is_current(p_job, p_fence, p_owner);
$$;

revoke all on function
  public.billing_bind_account(uuid,text,smallint),
  public.create_purchase_intent(uuid,text,text,uuid),
  public.register_purchase_verification(uuid,text,text,text,uuid),
  public.claim_billing_job(uuid,text,integer),
  public.apply_play_verification(uuid,bigint,text,jsonb),
  public.complete_billing_acknowledgement(uuid,bigint,text),
  public.fail_billing_job(uuid,bigint,text,text,integer,boolean),
  public.get_purchase_verification_status(uuid,uuid),
  public.get_billing_job_purchase(uuid,bigint,text),
  public.set_billing_product_enabled(text,boolean),
  private.billing_lease_is_current(uuid,bigint,text)
  from public, anon, authenticated;
grant execute on function
  public.billing_bind_account(uuid,text,smallint),
  public.create_purchase_intent(uuid,text,text,uuid),
  public.register_purchase_verification(uuid,text,text,text,uuid),
  public.claim_billing_job(uuid,text,integer),
  public.apply_play_verification(uuid,bigint,text,jsonb),
  public.complete_billing_acknowledgement(uuid,bigint,text),
  public.fail_billing_job(uuid,bigint,text,text,integer,boolean),
  public.get_purchase_verification_status(uuid,uuid),
  public.get_billing_job_purchase(uuid,bigint,text),
  public.set_billing_product_enabled(text,boolean)
  to service_role;
commit;
