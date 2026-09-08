-- Portable learning history: the two tables worth carrying across devices.
--
-- Account recovery restored headline progress — lesson completion, SRS cards,
-- placement, gamification — but not the evidence behind it. A restored learner
-- kept their level and lost the reasoning: the record of what they had shown
-- they could do, and the practice already scheduled for them.
--
-- Only two of the six unsynced tables are here, deliberately.
--
-- * learning_evidence_events is what placement and recommendations read. It is
--   the diagnosis, not the telemetry.
-- * delayed_transfer_assignments is practice already promised to the learner
--   for a future date. Losing it silently breaks a commitment the app made.
--
-- exercise_attempts, review_attempts, lesson_attempts and reward_ledger stay
-- local. They are raw telemetry: the state a learner actually experiences is
-- derived from them and already syncs, so carrying them would multiply row
-- count for retrospective analytics nobody restores. What does not transfer is
-- said plainly in the account screen rather than left to be discovered.
--
-- Both carry client-generated ids, so pushes are idempotent and two devices
-- cannot collide.
--
-- Rollback (reverse order):
--   drop table public.delayed_transfer_assignments;
--   drop table public.learning_evidence_events;
--   drop sequence public.delayed_transfer_assignments_revision_seq;
--   drop sequence public.learning_evidence_events_revision_seq;

begin;

create sequence public.learning_evidence_events_revision_seq;

create table public.learning_evidence_events (
  user_id             uuid        not null references auth.users(id) on delete cascade,
  evidence_id         text        not null,
  lesson_id           integer     not null,
  exercise_id         integer,
  skill               text        not null,
  phase               text        not null,
  correct             boolean     not null,
  novel_task          boolean     not null,
  supports            jsonb       not null default '[]'::jsonb,
  concept_keys        jsonb       not null default '[]'::jsonb,
  response_latency_ms integer     not null default 0,
  observed_at         timestamptz not null,
  device_id           text        not null default '',
  updated_at          timestamptz not null default now(),
  revision            bigint      not null
                      default nextval('public.learning_evidence_events_revision_seq'),

  primary key (user_id, evidence_id),

  constraint learning_evidence_events_id_valid
    check (length(evidence_id) between 1 and 128),
  constraint learning_evidence_events_latency_sane
    check (response_latency_ms between 0 and 3600000)
);

create index learning_evidence_events_revision_pull_idx
  on public.learning_evidence_events (user_id, revision);

create trigger learning_evidence_events_stamp_revision
  before insert or update on public.learning_evidence_events
  for each row
  execute function public.stamp_sync_revision(
    'public.learning_evidence_events_revision_seq'
  );

alter table public.learning_evidence_events enable row level security;

create policy learning_evidence_events_owner
on public.learning_evidence_events
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on table public.learning_evidence_events from anon, authenticated;
grant select, insert, update, delete
  on table public.learning_evidence_events to authenticated;

create sequence public.delayed_transfer_assignments_revision_seq;

create table public.delayed_transfer_assignments (
  user_id               uuid        not null references auth.users(id) on delete cascade,
  assignment_id         text        not null,
  source_attempt_id     text        not null,
  lesson_id             integer     not null,
  source_exercise_id    integer     not null,
  due_at                timestamptz not null,
  status                text        not null default 'pending',
  completed_evidence_id text,
  created_at            timestamptz not null,
  completed_at          timestamptz,
  device_id             text        not null default '',
  updated_at            timestamptz not null default now(),
  revision              bigint      not null
                        default nextval('public.delayed_transfer_assignments_revision_seq'),

  primary key (user_id, assignment_id),

  constraint delayed_transfer_assignments_id_valid
    check (length(assignment_id) between 1 and 128),
  constraint delayed_transfer_assignments_status_valid
    check (status in ('pending', 'completed', 'expired'))
);

create index delayed_transfer_assignments_revision_pull_idx
  on public.delayed_transfer_assignments (user_id, revision);

create trigger delayed_transfer_assignments_stamp_revision
  before insert or update on public.delayed_transfer_assignments
  for each row
  execute function public.stamp_sync_revision(
    'public.delayed_transfer_assignments_revision_seq'
  );

-- Unlike the evidence log, an assignment mutates: pending becomes completed.
-- Last-write-wins across devices, consistent with the other mutable tables.
create trigger delayed_transfer_assignments_keep_newest
  before update on public.delayed_transfer_assignments
  for each row execute function private.keep_newest_sync_row();

alter table public.delayed_transfer_assignments enable row level security;

create policy delayed_transfer_assignments_owner
on public.delayed_transfer_assignments
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on table public.delayed_transfer_assignments from anon, authenticated;
grant select, insert, update, delete
  on table public.delayed_transfer_assignments to authenticated;

commit;
