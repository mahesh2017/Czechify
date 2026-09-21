-- Referral persistence and allocation only. No client/HTTP route may call the
-- verified-receipt RPC until request-bound Integrity has been checked (4b).
begin;

create table monetization_private.referral_campaigns (
  id text primary key check (id = 'a1-referral-v1'),
  content_revision integer not null check (content_revision = 25),
  free_unit_ids integer[] not null check (free_unit_ids = array[1,2]),
  reward_unit_order integer[] not null check (reward_unit_order = array[3,4,5,6,7,8,9,10,11,12,13,14,15,28,30]),
  max_rewards_per_referee integer not null check (max_rewards_per_referee = 2),
  enabled boolean not null default false,
  processing_paused boolean not null default true,
  starts_at timestamptz,
  claim_closes_at timestamptz,
  ends_at timestamptz,
  check (not enabled or (starts_at is not null and claim_closes_at is not null and ends_at is not null)),
  check (starts_at < claim_closes_at and claim_closes_at <= ends_at)
);
insert into monetization_private.referral_campaigns
  (id,content_revision,free_unit_ids,reward_unit_order,max_rewards_per_referee)
values ('a1-referral-v1',25,array[1,2],array[3,4,5,6,7,8,9,10,11,12,13,14,15,28,30],2);

-- Immutable revision-25 manifest, pinned to the reviewed planning fixture and
-- the bundled lesson file hashes. Future content needs a new explicit mapping.
create table monetization_private.referral_manifest_lessons (
  campaign_id text not null references monetization_private.referral_campaigns(id),
  lesson_id integer not null,
  unit_id integer not null check (unit_id in (1,2)),
  lesson_hash text not null check (lesson_hash ~ '^[0-9a-f]{64}$'),
  exercise_ids integer[] not null,
  teaching_ids integer[] not null,
  primary key (campaign_id,lesson_id),
  check (cardinality(exercise_ids) > 0 and teaching_ids <@ exercise_ids)
);
insert into monetization_private.referral_manifest_lessons values
 ('a1-referral-v1',100,1,'1832921327bcfa26384ad2a4f8dffefe7a87f6548fc5fa0659c54be7263718ee',array[898,899,900,901,902,903,904,905,906,907],array[898,899]),
 ('a1-referral-v1',101,1,'0bbc4c57fea4e94033e7df163c1eb2a90f959b4ce72dd9c6b310a57cd640170d',array[1001,1002,1003,1004,1005,1006,1007,1008,1009,1010],array[1001]),
 ('a1-referral-v1',102,1,'9d0cfb6597a83159382202f3ae599cda665927912cba404de0e7db4a6c51b8f0',array[1101,1102,1103,1104,1105,1106,1107,1108,1109,1110,1111],array[1101,1111]),
 ('a1-referral-v1',103,1,'72fbfc913c1b9ccc9d549b30fa09800961104d0a437547d8e231a277be4c1575',array[1121,1122,1123,1124,1125,1126,1127,1128,1129,1130,1131,1132,1133],array[1121]),
 ('a1-referral-v1',201,2,'b408c6d9f556d44507c43d3c808391ef840c7e0703b84951a01e27207d18076d',array[2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011],array[2000]),
 ('a1-referral-v1',202,2,'046dd5d8b37e2a3603578cce47327d1b00a5d7832667ce20771d3998cd5705c0',array[2100,2101,2102,2103,2104,2105,2106,2107,2108,2109,2110,2111],array[2100]),
 ('a1-referral-v1',203,2,'af2136d483728ddb307a905ef8410b73bb3d4eb6847117dfdb90e3f7abec2176',array[2200,2201,2202,2203,2204,2205,2206,2207,2208,2209,2210,2211],array[2200]),
 ('a1-referral-v1',204,2,'7611cec14f67b9b2894afa56140794c850797b14fd89fecddd100e3f7d2cd3f2',array[2300,2301,2302,2303,2304,2305,2306,2307,2308,2309,2310,2311],array[2300]);

alter table monetization_private.referral_campaigns add column manifest_sha256 text;
-- Hash format: UTF-8 "25|" followed by lesson-id-sorted rows joined by "|";
-- each row is unit:lesson:file-sha256:comma-separated-exercises:teaching-ids.
update monetization_private.referral_campaigns set manifest_sha256=(select encode(extensions.digest('25|'||
  string_agg(unit_id::text||':'||lesson_id::text||':'||lesson_hash||':'||array_to_string(exercise_ids,',')||':'||array_to_string(teaching_ids,','),'|' order by lesson_id),'sha256'),'hex')
  from monetization_private.referral_manifest_lessons);
alter table monetization_private.referral_campaigns alter column manifest_sha256 set not null;
alter table monetization_private.referral_campaigns add check (manifest_sha256 ~ '^[0-9a-f]{64}$');

create table monetization_private.referral_codes (
  code text primary key check (code ~ '^[A-F0-9]{24}$'),
  owner_id uuid not null references auth.users(id) on delete cascade,
  campaign_id text not null references monetization_private.referral_campaigns(id),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);
create unique index referral_active_code on monetization_private.referral_codes(owner_id,campaign_id) where revoked_at is null;

create table monetization_private.referral_claims (
  id uuid primary key default gen_random_uuid(),
  campaign_id text not null references monetization_private.referral_campaigns(id),
  -- Null references are deletion tombstones. The claim UUID remains solely
  -- for reward audit; another learner's grant never cascades with a referee.
  referrer_id uuid references auth.users(id) on delete set null,
  referee_id uuid references auth.users(id) on delete set null,
  attribution_source text not null check (attribution_source = 'manual'),
  risk_state text not null default 'pending' check (risk_state in ('pending','clear','needs_review','rejected')),
  created_at timestamptz not null default now(),
  unique (campaign_id,referee_id),
  check (referrer_id <> referee_id)
);
create index referral_claims_beneficiary on monetization_private.referral_claims(referrer_id,id);

create table monetization_private.referral_receipts (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references monetization_private.referral_claims(id),
  referee_id uuid not null references auth.users(id) on delete cascade,
  attempt_id uuid not null,
  lesson_id integer not null,
  content_revision integer not null,
  receipt_digest text not null check (receipt_digest ~ '^[0-9a-f]{64}$'),
  payload_hash text not null,
  initial_coverage jsonb not null,
  started_at_client timestamptz not null,
  completed_at_client timestamptz not null,
  received_at timestamptz not null default now(),
  evidence_state text not null check (evidence_state in ('accepted','nonqualifying')),
  integrity_state text not null check (integrity_state in ('verified','needs_review')),
  unique (referee_id,attempt_id)
);
create index referral_receipts_claim on monetization_private.referral_receipts(claim_id);

create table monetization_private.referral_lesson_qualifications (
  claim_id uuid not null references monetization_private.referral_claims(id),
  lesson_id integer not null,
  receipt_id uuid not null references monetization_private.referral_receipts(id) on delete cascade,
  qualified_at timestamptz not null default now(),
  primary key (claim_id,lesson_id)
);
create table monetization_private.referral_milestones (
  claim_id uuid not null references monetization_private.referral_claims(id),
  ordinal integer not null check (ordinal in (1,2)),
  status text not null check (status in ('waiting_identity','verification_pending','needs_review','granted','cap_reached','rejected')),
  qualified_at timestamptz not null default now(),
  primary key (claim_id,ordinal)
);
create table monetization_private.referral_reward_events (
  claim_id uuid not null references monetization_private.referral_claims(id),
  ordinal integer not null check (ordinal in (1,2)),
  beneficiary_id uuid references auth.users(id) on delete set null,
  -- Audit identifiers deliberately do not cascade on beneficiary deletion.
  grant_id uuid,
  unit_id integer,
  outcome text not null check (outcome in ('granted','cap_reached','rejected')),
  created_at timestamptz not null default now(),
  primary key (claim_id,ordinal),
  check ((outcome = 'granted') = (grant_id is not null and unit_id is not null))
);
create table monetization_private.referral_review_cases (
  claim_id uuid primary key references monetization_private.referral_claims(id),
  reason text not null check (reason in ('integrity_review','timing_anomaly','identity_conflict')),
  opened_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution text check (resolution in ('clear','rejected')),
  operator_reason text,
  check ((resolved_at is null) = (resolution is null))
);
-- Count failed claim attempts too; a code-guessing failure returns a safe
-- result rather than raising/rolling back its rate-limit record.
create table monetization_private.referral_claim_attempts (
  actor_id uuid not null references auth.users(id) on delete cascade,
  attempted_at timestamptz not null default now()
);
create index referral_claim_attempts_rate on monetization_private.referral_claim_attempts(actor_id,attempted_at);

do $$
declare tab text;
begin
  foreach tab in array array['referral_campaigns','referral_manifest_lessons','referral_codes','referral_claims',
    'referral_receipts','referral_lesson_qualifications','referral_milestones','referral_reward_events',
    'referral_review_cases','referral_claim_attempts'] loop
    execute format('alter table monetization_private.%I enable row level security',tab);
    execute format('revoke all on monetization_private.%I from public, anon, authenticated, service_role',tab);
  end loop;
end $$;

create function private.referral_linked(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from auth.users u where u.id=p_user and u.is_anonymous is false
    and exists(select 1 from auth.identities i where i.user_id=u.id));
$$;
create function private.referral_same_identity(p_a uuid,p_b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_a=p_b or exists(select 1 from auth.identities a join auth.identities b
    on a.provider=b.provider and a.provider_id=b.provider_id where a.user_id=p_a and b.user_id=p_b);
$$;

-- No campaign mutation RPC in 4a: all dates remain unset and flags off.
-- A later audited rollout operation will set dates without changing manifest.
create function public.get_or_create_referral_code(p_actor uuid,p_campaign text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare code_value text; c monetization_private.referral_campaigns;
begin
  if not private.referral_linked(p_actor) then return jsonb_build_object('code','linked_account_required'); end if;
  select * into c from monetization_private.referral_campaigns where id=p_campaign;
  if not found or not c.enabled or now()<c.starts_at or now()>=c.claim_closes_at then
    return jsonb_build_object('code','campaign_unavailable');
  end if;
  insert into public.monetization_accounts(user_id) values(p_actor) on conflict do nothing;
  perform 1 from public.monetization_accounts where user_id=p_actor for update;
  select code into code_value from monetization_private.referral_codes
    where owner_id=p_actor and campaign_id=p_campaign and revoked_at is null;
  if code_value is not null then return jsonb_build_object('referral_code',code_value); end if;
  if (select count(*) from monetization_private.referral_codes where owner_id=p_actor and created_at>now()-interval '1 day')>=5 then
    return jsonb_build_object('code','rate_limited');
  end if;
  loop
    code_value := upper(encode(extensions.gen_random_bytes(12),'hex'));
    insert into monetization_private.referral_codes(code,owner_id,campaign_id) values(code_value,p_actor,p_campaign)
      on conflict (code) do nothing;
    exit when found;
  end loop;
  return jsonb_build_object('referral_code',code_value);
end $$;

create function public.claim_referral(p_actor uuid,p_campaign text,p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c monetization_private.referral_campaigns; owner uuid; existing monetization_private.referral_claims;
  claim_id uuid; joined_at timestamptz;
begin
  select created_at into joined_at from auth.users where id=p_actor;
  if not found then return jsonb_build_object('code','authentication_required'); end if;
  insert into public.monetization_accounts(user_id) values(p_actor) on conflict do nothing;
  perform 1 from public.monetization_accounts where user_id=p_actor for update;
  select * into c from monetization_private.referral_campaigns where id=p_campaign;
  -- Replays return the original claim even if enrollment has since closed.
  select * into existing from monetization_private.referral_claims where campaign_id=p_campaign and referee_id=p_actor;
  if found then
    select owner_id into owner from monetization_private.referral_codes where code=upper(trim(p_code)) and campaign_id=p_campaign;
    if owner=existing.referrer_id then return jsonb_build_object('claim_id',existing.id,'status','claimed'); end if;
    return jsonb_build_object('code','referral_already_claimed');
  end if;
  if c.id is null or not c.enabled or now()<c.starts_at or now()>=c.claim_closes_at then
    return jsonb_build_object('code','campaign_unavailable');
  end if;
  if (select count(*) from monetization_private.referral_claim_attempts where actor_id=p_actor and attempted_at>now()-interval '1 hour')>=10 then
    return jsonb_build_object('code','rate_limited');
  end if;
  insert into monetization_private.referral_claim_attempts(actor_id) values(p_actor);
  select owner_id into owner from monetization_private.referral_codes where code=upper(trim(p_code))
    and campaign_id=p_campaign and revoked_at is null;
  if owner is null or not private.referral_linked(owner) then return jsonb_build_object('code','referral_ineligible'); end if;
  if joined_at is null or joined_at<=now()-interval '7 days' or private.referral_same_identity(owner,p_actor) then
    return jsonb_build_object('code','referral_ineligible');
  end if;
  if not exists(select 1 from monetization_private.referral_manifest_lessons m where m.campaign_id=p_campaign and m.unit_id=1
    and not exists(select 1 from public.lesson_progress p where p.user_id=p_actor and p.lesson_id=m.lesson_id and p.is_completed)) then
    return jsonb_build_object('code','referral_ineligible');
  end if;
  insert into monetization_private.referral_claims(campaign_id,referrer_id,referee_id,attribution_source)
    values(p_campaign,owner,p_actor,'manual') returning id into claim_id;
  return jsonb_build_object('claim_id',claim_id,'status','claimed','required_units',jsonb_build_array(1,2));
end $$;

-- Lock order for EVERY receipt/review/allocation: beneficiary account, claim.
-- That is the same first lock as legacy/support grant writers. No client can
-- request an ordinal or destination unit; both are derived from qualifications.
create function public.process_referral_claim(p_claim uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cl monetization_private.referral_claims; c monetization_private.referral_campaigns;
  beneficiary uuid; next_unit integer; grant_value uuid; status_value text;
begin
  select referrer_id into beneficiary from monetization_private.referral_claims where id=p_claim;
  if beneficiary is null then return jsonb_build_object('code','referral_unavailable'); end if;
  perform 1 from public.monetization_accounts where user_id=beneficiary for update;
  if not found then return jsonb_build_object('code','referral_unavailable'); end if;
  select * into cl from monetization_private.referral_claims where id=p_claim for update;
  if cl.referrer_id is null or cl.referee_id is null then return jsonb_build_object('code','referral_unavailable'); end if;
  select * into c from monetization_private.referral_campaigns where id=cl.campaign_id;
  for ordinal_value in 1..2 loop
    -- Ordinal two requires both units, regardless of receipt arrival order.
    if exists(select 1 from monetization_private.referral_manifest_lessons m
      where m.campaign_id=cl.campaign_id and m.unit_id<=ordinal_value
      and not exists(select 1 from monetization_private.referral_lesson_qualifications q
        where q.claim_id=cl.id and q.lesson_id=m.lesson_id)) then continue; end if;
    if exists(select 1 from monetization_private.referral_reward_events where claim_id=cl.id and ordinal=ordinal_value) then continue; end if;
    status_value := case
      when cl.risk_state='rejected' then 'rejected'
      when cl.risk_state='needs_review' or private.referral_same_identity(cl.referrer_id,cl.referee_id) then 'needs_review'
      when not private.referral_linked(cl.referrer_id) or not private.referral_linked(cl.referee_id) then 'waiting_identity'
      when c.processing_paused or cl.risk_state<>'clear' then 'verification_pending'
      else 'granted' end;
    insert into monetization_private.referral_milestones(claim_id,ordinal,status) values(cl.id,ordinal_value,status_value)
      on conflict (claim_id,ordinal) do update set status=excluded.status;
    if status_value in ('waiting_identity','verification_pending','needs_review') then continue; end if;
    next_unit := null; grant_value := null;
    if status_value='granted' then
      select r.unit_id into next_unit from unnest(c.reward_unit_order) with ordinality r(unit_id,position)
        where not exists(select 1 from public.course_unit_grants g where g.user_id=beneficiary
          and g.unit_id=r.unit_id and g.revoked_at is null) order by r.position limit 1;
      if next_unit is null then status_value := 'cap_reached';
      else
        grant_value := public.set_course_unit_grant(beneficiary,next_unit,'referral',cl.id::text||':'||ordinal_value,
          cl.campaign_id,false,'qualified_referral_milestone');
      end if;
    end if;
    insert into monetization_private.referral_reward_events(claim_id,ordinal,beneficiary_id,grant_id,unit_id,outcome)
      values(cl.id,ordinal_value,beneficiary,grant_value,next_unit,status_value);
    update monetization_private.referral_milestones set status=status_value where claim_id=cl.id and ordinal=ordinal_value;
  end loop;
  return jsonb_build_object('claim_id',cl.id,'milestones',coalesce((select jsonb_agg(jsonb_build_object(
    'ordinal',m.ordinal,'status',m.status) order by m.ordinal) from monetization_private.referral_milestones m where m.claim_id=cl.id),'[]'::jsonb));
end $$;

-- TRUSTED worker boundary, like apply_play_verification: p_integrity must come
-- from server verification, never a client assertion. 4b will bind nonce,
-- account, claim and canonical digest before calling this RPC. Even here we
-- independently validate exact manifest coverage and ownership.
create function public.accept_verified_referral_receipt(p_actor uuid,p_claim uuid,p_receipt jsonb,p_digest text,p_integrity text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cl monetization_private.referral_claims; c monetization_private.referral_campaigns;
  m monetization_private.referral_manifest_lessons; old monetization_private.referral_receipts;
  beneficiary uuid; attempt uuid; lesson integer; started timestamptz; completed timestamptz;
  coverage jsonb; ids integer[]; receipt_id uuid; evidence text; item jsonb; exercise integer; interaction text;
begin
  if p_integrity is null or p_integrity not in ('verified','needs_review') then
    return jsonb_build_object('code','integrity_rejected');
  end if;
  if p_digest is null or p_digest !~ '^[0-9a-f]{64}$' or p_receipt is null or jsonb_typeof(p_receipt)<>'object'
    or octet_length(p_receipt::text)>65536 then return jsonb_build_object('code','invalid_receipt'); end if;
  if not (p_receipt ?& array['schema_version','claim_id','campaign_id','content_revision','lesson_id','attempt_id','started_at_client','completed_at_client','initial_coverage'])
    or exists(select 1 from jsonb_object_keys(p_receipt) k where k not in
      ('schema_version','claim_id','campaign_id','content_revision','lesson_id','attempt_id','started_at_client','completed_at_client','initial_coverage'))
    or p_receipt->'schema_version' is distinct from '1'::jsonb or p_receipt->>'claim_id' is distinct from p_claim::text
    or jsonb_typeof(p_receipt->'initial_coverage') is distinct from 'array'
    or jsonb_typeof(p_receipt->'lesson_id') is distinct from 'number'
    or jsonb_typeof(p_receipt->'attempt_id') is distinct from 'string'
    or jsonb_typeof(p_receipt->'started_at_client') is distinct from 'string'
    or jsonb_typeof(p_receipt->'completed_at_client') is distinct from 'string' then return jsonb_build_object('code','invalid_receipt'); end if;
  begin
    attempt := (p_receipt->>'attempt_id')::uuid; lesson := (p_receipt->>'lesson_id')::integer;
    started := (p_receipt->>'started_at_client')::timestamptz; completed := (p_receipt->>'completed_at_client')::timestamptz;
  exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then
    return jsonb_build_object('code','invalid_receipt');
  end;
  if attempt is null or lesson is null or started is null or completed is null or not isfinite(started) or not isfinite(completed)
    or started>completed then return jsonb_build_object('code','invalid_receipt'); end if;
  select referrer_id into beneficiary from monetization_private.referral_claims where id=p_claim and referee_id=p_actor;
  if beneficiary is null then return jsonb_build_object('code','referral_unavailable'); end if;
  perform 1 from public.monetization_accounts where user_id=beneficiary for update;
  select * into cl from monetization_private.referral_claims where id=p_claim for update;
  if cl.referee_id is distinct from p_actor or cl.referrer_id is null then return jsonb_build_object('code','referral_unavailable'); end if;
  select * into old from monetization_private.referral_receipts where referee_id=p_actor and attempt_id=attempt;
  if found then
    if old.claim_id<>p_claim or old.receipt_digest<>p_digest or old.payload_hash<>encode(extensions.digest(p_receipt::text,'sha256'),'hex') then
      return jsonb_build_object('code','idempotency_conflict'); end if;
    return jsonb_build_object('receipt_id',old.id,'status',old.evidence_state);
  end if;
  select * into c from monetization_private.referral_campaigns where id=cl.campaign_id;
  if p_receipt->>'campaign_id' is distinct from cl.campaign_id or p_receipt->'content_revision' is distinct from to_jsonb(c.content_revision) then
    return jsonb_build_object('code','content_update_required');
  end if;
  -- Disabling new claims does not stop existing receipts. Campaign expiry does.
  if c.ends_at is null or now()>=c.ends_at then return jsonb_build_object('code','campaign_unavailable'); end if;
  if (select count(*) from monetization_private.referral_receipts where referee_id=p_actor and received_at>now()-interval '1 hour')>=120 then
    return jsonb_build_object('code','rate_limited'); end if;
  select * into m from monetization_private.referral_manifest_lessons where campaign_id=cl.campaign_id and lesson_id=lesson;
  if not found then return jsonb_build_object('code','invalid_receipt'); end if;
  coverage := p_receipt->'initial_coverage'; ids := array[]::integer[]; evidence := 'accepted';
  if jsonb_array_length(coverage)<>cardinality(m.exercise_ids) then return jsonb_build_object('code','invalid_receipt'); end if;
  for item in select value from jsonb_array_elements(coverage) loop
    if jsonb_typeof(item) is distinct from 'object' then return jsonb_build_object('code','invalid_receipt'); end if;
    if not (item ?& array['exercise_id','interaction'])
      or (select count(*) from jsonb_object_keys(item))<>2 or jsonb_typeof(item->'exercise_id')<>'number' then
      return jsonb_build_object('code','invalid_receipt');
    end if;
    begin exercise := (item->>'exercise_id')::integer;
    exception when invalid_text_representation or numeric_value_out_of_range then return jsonb_build_object('code','invalid_receipt'); end;
    interaction := item->>'interaction';
    if exercise is null or not (exercise=any(m.exercise_ids)) or exercise=any(ids) or interaction is null then
      return jsonb_build_object('code','invalid_receipt'); end if;
    if interaction='skipped' then evidence := 'nonqualifying';
    elsif exercise=any(m.teaching_ids) then
      if interaction<>'teaching_acknowledged' then return jsonb_build_object('code','invalid_receipt'); end if;
    elsif interaction not in ('answered_correctly','answered_incorrectly') then return jsonb_build_object('code','invalid_receipt'); end if;
    ids := array_append(ids,exercise);
  end loop;
  if started<cl.created_at or completed>now()+interval '5 minutes' then
    update monetization_private.referral_claims set risk_state='needs_review' where id=cl.id and risk_state<>'rejected';
    insert into monetization_private.referral_review_cases(claim_id,reason) values(cl.id,'timing_anomaly')
      on conflict (claim_id) do update set reason=excluded.reason,resolved_at=null,resolution=null,operator_reason=null;
  elsif p_integrity='needs_review' then
    update monetization_private.referral_claims set risk_state='needs_review' where id=cl.id and risk_state<>'rejected';
    insert into monetization_private.referral_review_cases(claim_id,reason) values(cl.id,'integrity_review')
      on conflict (claim_id) do update set reason=excluded.reason,resolved_at=null,resolution=null,operator_reason=null;
  else
    update monetization_private.referral_claims set risk_state='clear' where id=cl.id and risk_state='pending';
  end if;
  insert into monetization_private.referral_receipts(claim_id,referee_id,attempt_id,lesson_id,content_revision,receipt_digest,payload_hash,
    initial_coverage,started_at_client,completed_at_client,evidence_state,integrity_state)
    values(cl.id,p_actor,attempt,lesson,c.content_revision,p_digest,encode(extensions.digest(p_receipt::text,'sha256'),'hex'),coverage,started,completed,evidence,p_integrity)
    returning id into receipt_id;
  if evidence='accepted' then
    insert into monetization_private.referral_lesson_qualifications(claim_id,lesson_id,receipt_id) values(cl.id,lesson,receipt_id)
      on conflict do nothing;
  end if;
  perform public.process_referral_claim(cl.id);
  return jsonb_build_object('receipt_id',receipt_id,'status',evidence);
end $$;

create function public.resolve_referral_review(p_claim uuid,p_resolution text,p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare beneficiary uuid;
begin
  if p_resolution is null or p_resolution not in ('clear','rejected') or p_reason is null or length(trim(p_reason)) not between 1 and 200 then
    raise exception 'Invalid review decision' using errcode='22023'; end if;
  select referrer_id into beneficiary from monetization_private.referral_claims where id=p_claim;
  perform 1 from public.monetization_accounts where user_id=beneficiary for update;
  perform 1 from monetization_private.referral_claims where id=p_claim for update;
  update monetization_private.referral_review_cases set resolved_at=now(),resolution=p_resolution,operator_reason=p_reason
    where claim_id=p_claim and resolved_at is null;
  if not found then return jsonb_build_object('code','review_unavailable'); end if;
  update monetization_private.referral_claims set risk_state=p_resolution where id=p_claim;
  return public.process_referral_claim(p_claim);
end $$;

revoke all on function private.referral_linked(uuid),private.referral_same_identity(uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.get_or_create_referral_code(uuid,text),public.claim_referral(uuid,text,text),
  public.process_referral_claim(uuid),public.accept_verified_referral_receipt(uuid,uuid,jsonb,text,text),
  public.resolve_referral_review(uuid,text,text) from public,anon,authenticated;
grant execute on function public.get_or_create_referral_code(uuid,text),public.claim_referral(uuid,text,text),
  public.process_referral_claim(uuid),public.accept_verified_referral_receipt(uuid,uuid,jsonb,text,text),
  public.resolve_referral_review(uuid,text,text) to service_role;
commit;
