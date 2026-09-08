-- In-app reporting for AI tutor replies.
--
-- Google Play's generative-AI policy requires that a reader can report
-- offensive generated output *without leaving the app*. Reporting handed off
-- to a `mailto:` draft, which left the app and left no record — nothing could
-- say a report had been received, let alone answered.
--
-- Written by the client through the ordinary sync outbox rather than an edge
-- function: the caller is already authenticated, the payload carries no
-- secrets, and RLS is the right control. A function would add a hop and a
-- second code path for the offline case the outbox already handles.
--
-- Rollback:
--   drop trigger tutor_reply_reports_stamp_revision on public.tutor_reply_reports;
--   drop table public.tutor_reply_reports;
--   drop sequence public.tutor_reply_reports_revision_seq;

begin;

-- Created before the table so the column can default from it, matching
-- custom_cards. The trigger below still stamps every UPDATE.
create sequence public.tutor_reply_reports_revision_seq;

create table public.tutor_reply_reports (
  user_id         uuid        not null references auth.users(id) on delete cascade,
  report_id       text        not null,
  message_id      text,
  conversation_id text,
  scenario_id     text        not null default '',
  reason          text        not null,
  reply_text      text        not null,
  learner_note    text        not null default '',
  app_version     text        not null default '',
  reported_at     timestamptz not null,

  -- Triage state. Owned by us, never written by the client: the RLS policies
  -- below allow insert and select only, so a learner cannot mark their own
  -- report resolved.
  status          text        not null default 'new',

  created_at      timestamptz not null default now(),
  revision        bigint      not null
                  default nextval('public.tutor_reply_reports_revision_seq'),

  primary key (user_id, report_id),

  constraint tutor_reply_reports_reason_valid check (
    reason in ('offensive', 'sexual', 'dangerous', 'wrong_czech', 'other')
  ),
  constraint tutor_reply_reports_status_valid check (
    status in ('new', 'reviewing', 'actioned', 'dismissed')
  ),
  -- Bounded so a report cannot be used to store arbitrary volume. The tutor
  -- reply is capped by the proxy at 4,000 characters; the note is the
  -- learner's own words and needs far less.
  constraint tutor_reply_reports_reply_length check (
    char_length(reply_text) <= 4000
  ),
  constraint tutor_reply_reports_note_length check (
    char_length(learner_note) <= 2000
  )
);

-- One report per reply. This is the rate limit: without it a learner could
-- file the same reply repeatedly, and a retried push would duplicate rows.
-- Partial, because a report may have no message id.
create unique index tutor_reply_reports_one_per_message
  on public.tutor_reply_reports (user_id, message_id)
  where message_id is not null;

alter table public.tutor_reply_reports enable row level security;
revoke all on table public.tutor_reply_reports from public, anon, authenticated;
grant select, insert on table public.tutor_reply_reports to authenticated;

-- A learner may file a report and read their own back. They may not update or
-- delete one: a report is a record of something that happened, and its triage
-- state is not theirs to set.
create policy tutor_reply_reports_owner_insert
on public.tutor_reply_reports
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy tutor_reply_reports_owner_read
on public.tutor_reply_reports
for select
to authenticated
using ((select auth.uid()) = user_id);

-- Pull cursor, matching every other synced table: a server-owned monotonic
-- revision that no client clock can perturb.
create trigger tutor_reply_reports_stamp_revision
  before insert or update on public.tutor_reply_reports
  for each row
  execute function public.stamp_sync_revision(
    'public.tutor_reply_reports_revision_seq'
  );

create index tutor_reply_reports_revision_pull_idx
  on public.tutor_reply_reports (user_id, revision);

-- Triage view. Deliberately not an admin UI: reports need a person to read
-- them, and a saved query is enough to start.
comment on table public.tutor_reply_reports is
  'Learner reports about AI tutor replies. Review with: select reported_at, '
  'reason, scenario_id, reply_text, learner_note from tutor_reply_reports '
  'where status = ''new'' order by reported_at;';

commit;
