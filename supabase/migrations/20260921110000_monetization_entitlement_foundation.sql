begin;
create schema if not exists monetization_private;
revoke all on schema monetization_private from public, anon, authenticated;

create table public.monetization_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null default 0 check (revision >= 0),
  policy_cohort text not null default 'disabled' check (policy_cohort in ('disabled','pilot')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.course_unit_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.monetization_accounts(user_id) on delete cascade,
  unit_id integer not null references private.placement_unit_order(unit_id),
  source text not null check (source in ('referral','legacy','staff_permanent')),
  source_key text not null check (length(source_key) between 1 and 200),
  campaign_id text,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  revocation_reason_code text,
  unique (user_id, source, source_key),
  check (source <> 'referral' or (campaign_id is not null and campaign_id = 'a1-referral-v1' and
    unit_id = any(array[3,4,5,6,7,8,9,10,11,12,13,14,15,28,30]))),
  check ((revoked_at is null) = (revocation_reason_code is null))
);
create unique index course_referral_unit_once on public.course_unit_grants(user_id,campaign_id,unit_id)
  where source = 'referral' and revoked_at is null;
create table public.course_access_windows (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.monetization_accounts(user_id) on delete cascade,
  kind text not null check (kind = 'migration_grace'),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  source_key text not null,
  unique (user_id, kind, source_key),
  check (ends_at > starts_at)
);
create table monetization_private.feature_entitlements (
  user_id uuid not null references public.monetization_accounts(user_id) on delete cascade,
  feature text not null check (feature in ('core','ai_chat')),
  source_key text not null,
  state text not null check (state in ('pending','active','in_grace_period','canceled','on_hold','paused','expired','revoked')),
  valid_until timestamptz not null,
  verified_at timestamptz not null,
  primary key (user_id,feature,source_key)
);
create table monetization_private.entitlement_audit (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  action text not null,
  source_key text not null,
  reason text not null,
  created_at timestamptz not null default now()
);
create table monetization_private.monetization_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  revision bigint not null,
  event_type text not null,
  created_at timestamptz not null default now(),
  published_at timestamptz
);

alter table public.monetization_accounts enable row level security;
alter table public.course_unit_grants enable row level security;
alter table public.course_access_windows enable row level security;
alter table monetization_private.feature_entitlements enable row level security;
alter table monetization_private.entitlement_audit enable row level security;
alter table monetization_private.monetization_outbox enable row level security;
create policy own_monetization_account on public.monetization_accounts for select to authenticated using ((select auth.uid()) = user_id);
create policy own_course_grants on public.course_unit_grants for select to authenticated using ((select auth.uid()) = user_id);
create policy own_course_windows on public.course_access_windows for select to authenticated using ((select auth.uid()) = user_id);
revoke all on public.monetization_accounts, public.course_unit_grants, public.course_access_windows from public, anon, authenticated, service_role;
grant select on public.monetization_accounts, public.course_unit_grants, public.course_access_windows to authenticated, service_role;
revoke all on all tables in schema monetization_private from public, anon, authenticated, service_role;
revoke all on all sequences in schema monetization_private from public, anon, authenticated, service_role;

-- All changes use one lock and revision/outbox transaction. No direct client writes.
create function public.set_course_unit_grant(p_user uuid, p_unit integer, p_source text,
  p_source_key text, p_campaign text, p_revoke boolean, p_reason text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare existing public.course_unit_grants; grant_id uuid; rev bigint;
begin
  if p_reason is null or length(trim(p_reason)) not between 1 and 200 or p_revoke is null then
    raise exception 'A reason and action are required' using errcode = '22023';
  end if;
  insert into public.monetization_accounts(user_id) values(p_user) on conflict do nothing;
  perform 1 from public.monetization_accounts where user_id = p_user for update;
  select * into existing from public.course_unit_grants
    where user_id = p_user and source = p_source and source_key = p_source_key;
  if found then
    if existing.unit_id is distinct from p_unit or existing.campaign_id is distinct from p_campaign then
      raise exception 'Grant identity conflict' using errcode = '22023';
    end if;
    if (existing.revoked_at is not null) = p_revoke then return existing.id; end if;
    if not p_revoke then raise exception 'Revoked grants require a new audited source key' using errcode = '22023'; end if;
    update public.course_unit_grants set revoked_at = now(), revocation_reason_code = p_reason where id = existing.id;
    grant_id := existing.id;
  else
    if p_revoke then raise exception 'Unknown grant' using errcode = '22023'; end if;
    insert into public.course_unit_grants(user_id,unit_id,source,source_key,campaign_id)
      values(p_user,p_unit,p_source,p_source_key,p_campaign) returning id into grant_id;
  end if;
  update public.monetization_accounts set revision = revision + 1, updated_at = now()
    where user_id = p_user returning revision into rev;
  insert into monetization_private.entitlement_audit(user_id,action,source_key,reason)
    values(p_user,case when p_revoke then 'revoke_unit' else 'grant_unit' end,p_source_key,p_reason);
  insert into monetization_private.monetization_outbox(user_id,revision,event_type) values(p_user,rev,'course_access_changed');
  return grant_id;
end;
$$;

-- Caller must first verify Play; this RPC is inaccessible to user JWTs.
create function public.apply_verified_feature(p_user uuid, p_feature text, p_source_key text,
  p_state text, p_valid_until timestamptz, p_verified_at timestamptz)
returns bigint language plpgsql security definer set search_path = '' as $$
declare existing monetization_private.feature_entitlements; rev bigint;
begin
  if p_verified_at > now() + interval '5 minutes' or length(p_source_key) not between 1 and 200 then
    raise exception 'Invalid verification metadata' using errcode = '22023';
  end if;
  insert into public.monetization_accounts(user_id) values(p_user) on conflict do nothing;
  select revision into rev from public.monetization_accounts where user_id = p_user for update;
  select * into existing from monetization_private.feature_entitlements
    where user_id = p_user and feature = p_feature and source_key = p_source_key;
  if found then
    if p_verified_at < existing.verified_at then return rev; end if;
    if p_verified_at = existing.verified_at then
      if p_state = existing.state and p_valid_until = existing.valid_until then return rev; end if;
      raise exception 'Conflicting verification at same timestamp' using errcode = '22023';
    end if;
  end if;
  insert into monetization_private.feature_entitlements values(p_user,p_feature,p_source_key,p_state,p_valid_until,p_verified_at)
    on conflict (user_id,feature,source_key) do update set state = excluded.state,
      valid_until = excluded.valid_until, verified_at = excluded.verified_at;
  update public.monetization_accounts set revision = revision + 1, updated_at = now()
    where user_id = p_user returning revision into rev;
  insert into monetization_private.entitlement_audit(user_id,action,source_key,reason)
    values(p_user,'verify_feature',p_source_key,p_state);
  insert into monetization_private.monetization_outbox(user_id,revision,event_type) values(p_user,rev,'feature_access_changed');
  return rev;
end;
$$;

create function public.get_monetization_snapshot(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'schema_version',1, 'user_id', p_user, 'revision', coalesce(a.revision,0),
    'issued_at', now(), 'verified_at', now(), 'policy_version','course-access-v1',
    'campaign_id','a1-referral-v1', 'manifest_revision',25,
    'features', (select jsonb_object_agg(f.feature, jsonb_build_object(
      'state', case when b.valid_until is null then 'inactive' else 'active' end,
      'valid_until',b.valid_until,'offline_valid_until',b.offline_valid_until))
      from (values ('core'),('ai_chat')) f(feature)
      left join lateral (select max(e.valid_until) valid_until,
        max(least(e.valid_until, e.verified_at + interval '7 days')) offline_valid_until
        from monetization_private.feature_entitlements e where e.user_id = p_user
        and e.feature = f.feature and e.state in ('active','in_grace_period','canceled')
        and e.valid_until > now()) b on true),
    'permanent_unit_grants', (select coalesce(jsonb_agg(jsonb_build_object(
      'grant_id',g.id,'unit_id',g.unit_id,'source',g.source) order by g.unit_id,g.id),'[]'::jsonb)
      from public.course_unit_grants g where g.user_id = p_user and g.revoked_at is null),
    'migration_grace_until',(select max(w.ends_at) from public.course_access_windows w
      where w.user_id = p_user and w.starts_at <= now() and w.ends_at > now()),
    'staff_course_until',case when c.unlock_all and c.expires_at > now() then c.expires_at else null end,
    'staff_course_unlimited',coalesce(c.unlock_all and c.expires_at is null,false))
  from auth.users u left join public.monetization_accounts a on a.user_id = u.id
    left join public.curriculum_entitlements c on c.user_id = u.id where u.id = p_user;
$$;
revoke all on function public.set_course_unit_grant(uuid,integer,text,text,text,boolean,text),
  public.apply_verified_feature(uuid,text,text,text,timestamptz,timestamptz),
  public.get_monetization_snapshot(uuid) from public, anon, authenticated;
grant execute on function public.set_course_unit_grant(uuid,integer,text,text,text,boolean,text),
  public.apply_verified_feature(uuid,text,text,text,timestamptz,timestamptz),
  public.get_monetization_snapshot(uuid) to service_role;
commit;
