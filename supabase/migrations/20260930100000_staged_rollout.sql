-- PR 8: staged activation. Each commercial feature turns on for a stable
-- cohort of accounts: named testers first, then a percentage of accounts.
-- An account keeps its bucket for good, so it never flips between cohorts,
-- and every feature uses the same bucket, so the cohort that has a paywall
-- is also the cohort that can buy. Everything starts at zero.
begin;

create table monetization_private.rollout_features (
  feature text primary key check (feature in ('play_checkout','course_paywall','referral_claims','paid_chat')),
  percent integer not null default 0 check (percent between 0 and 100),
  -- Internal testers and closed-cohort accounts, on whatever the percentage.
  allowlist uuid[] not null default '{}' check (cardinality(allowlist) <= 1000),
  updated_at timestamptz not null default now(),
  updated_by text not null default 'migration'
);
insert into monetization_private.rollout_features(feature) values
  ('play_checkout'), ('course_paywall'), ('referral_claims'), ('paid_chat');

create table monetization_private.rollout_changes (
  id bigint generated always as identity primary key,
  feature text not null,
  percent integer not null,
  allowlist_size integer not null,
  operator text not null,
  reason text not null,
  changed_at timestamptz not null default now()
);
alter table monetization_private.rollout_features enable row level security;
alter table monetization_private.rollout_changes enable row level security;
revoke all on monetization_private.rollout_features, monetization_private.rollout_changes
  from public, anon, authenticated, service_role;

-- 0–99, fixed per account.
create function private.rollout_bucket(p_user uuid)
returns integer language sql immutable set search_path = '' as $$
  select (('x' || substr(md5('czechify-rollout-v1:' || p_user::text), 1, 8))::bit(32)::bigint % 100)::integer;
$$;

-- Which features are on for this account.
create function public.rollout_for(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(f.feature,
      p_user = any(f.allowlist) or private.rollout_bucket(p_user) < f.percent), '{}'::jsonb)
  from monetization_private.rollout_features f;
$$;

-- The operator's control. Refuses a paywall or paid chat for anyone who
-- could not also buy: no learner is locked out of something they cannot
-- purchase.
create function public.set_rollout(p_feature text, p_percent integer, p_allowlist uuid[], p_operator text,
  p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare checkout monetization_private.rollout_features; gated monetization_private.rollout_features;
begin
  if p_operator is null or length(trim(p_operator)) not between 1 and 200
     or p_reason is null or length(trim(p_reason)) not between 1 and 500 then
    raise exception 'An operator and a reason are required' using errcode = '22023';
  end if;
  update monetization_private.rollout_features
    set percent = p_percent, allowlist = coalesce(p_allowlist, '{}'), updated_at = now(), updated_by = p_operator
    where feature = p_feature;
  if not found then raise exception 'Unknown feature' using errcode = '22023'; end if;
  select * into checkout from monetization_private.rollout_features where feature = 'play_checkout';
  for gated in select * from monetization_private.rollout_features
      where feature in ('course_paywall','paid_chat') loop
    if gated.percent > checkout.percent or not gated.allowlist <@ checkout.allowlist then
      raise exception '% would reach accounts that cannot buy', gated.feature using errcode = '22023';
    end if;
  end loop;
  insert into monetization_private.rollout_changes(feature, percent, allowlist_size, operator, reason)
    values (p_feature, p_percent, cardinality(coalesce(p_allowlist, '{}')), p_operator, p_reason);
  return (select jsonb_object_agg(feature, jsonb_build_object('percent', percent,
      'allowlist_size', cardinality(allowlist))) from monetization_private.rollout_features);
end $$;

-- Alert delivery: the worker runs every few minutes, so each alert is sent
-- at most once per p_minutes while it stays crossed.
create table monetization_private.alert_deliveries (
  alert text primary key check (alert ~ '^[a-z_]{1,64}$'),
  last_sent_at timestamptz not null
);
alter table monetization_private.alert_deliveries enable row level security;
revoke all on monetization_private.alert_deliveries from public, anon, authenticated, service_role;

create function public.claim_alert_deliveries(p_alerts text[], p_minutes integer)
returns text[] language plpgsql security definer set search_path = '' as $$
declare due text[];
begin
  with wanted as (select distinct a from unnest(coalesce(p_alerts, '{}')) a where a ~ '^[a-z_]{1,64}$'),
  claimed as (
    insert into monetization_private.alert_deliveries(alert, last_sent_at)
      select a, now() from wanted
    on conflict (alert) do update set last_sent_at = now()
      where monetization_private.alert_deliveries.last_sent_at
        < now() - make_interval(mins => greatest(p_minutes, 1))
    returning alert)
  select coalesce(array_agg(alert order by alert), '{}') into due from claimed;
  return due;
end $$;

revoke all on function private.rollout_bucket(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rollout_for(uuid), public.set_rollout(text, integer, uuid[], text, text),
  public.claim_alert_deliveries(text[], integer) from public, anon, authenticated;
grant execute on function public.rollout_for(uuid), public.set_rollout(text, integer, uuid[], text, text),
  public.claim_alert_deliveries(text[], integer) to service_role;

commit;
