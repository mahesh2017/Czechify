-- Run against a migrated local database; all fixtures roll back.
begin;
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path = public;
select public.no_plan();

insert into auth.users(id) values
 ('40000000-0000-0000-0000-000000000001'),
 ('40000000-0000-0000-0000-000000000002');
set local role authenticated;
set local request.jwt.claim.sub = '40000000-0000-0000-0000-000000000001';
set local request.jwt.claims = '{"sub":"40000000-0000-0000-0000-000000000001","role":"authenticated"}';

insert into public.tutor_reply_reports
 (user_id, report_id, reason, reply_text, reported_at, status, created_at)
values ('40000000-0000-0000-0000-000000000001', 'audit-report', 'dangerous',
 'Unsafe reply', '2026-09-01', 'actioned', '2000-01-01');
select public.is((select status from public.tutor_reply_reports where report_id='audit-report'),
 'new', 'a learner cannot pre-triage a new report');
select public.ok((select created_at >= now() - interval '1 minute'
 from public.tutor_reply_reports where report_id='audit-report'),
 'the server timestamps receipt of a learner report');

reset role;
set local role service_role;
update public.tutor_reply_reports set status='reviewing' where report_id='audit-report';
select public.is((select status from public.tutor_reply_reports where report_id='audit-report'),
 'reviewing', 'staff can change triage status');
reset role;
set local role authenticated;
-- The real transport uses INSERT ON CONFLICT DO UPDATE, not a plain UPDATE.
insert into public.tutor_reply_reports
 (user_id, report_id, reason, reply_text, reported_at, status, created_at)
values ('40000000-0000-0000-0000-000000000001', 'audit-report', 'dangerous',
 'Unsafe reply', '2026-09-02', 'dismissed', '2000-01-01')
on conflict (user_id,report_id) do update set
 status=excluded.status, reported_at=excluded.reported_at, created_at=excluded.created_at;
select public.is((select status from public.tutor_reply_reports where report_id='audit-report'),
 'reviewing', 'a learner re-push cannot reset staff triage');
select public.is((select reported_at from public.tutor_reply_reports where report_id='audit-report'),
 '2026-09-01'::timestamptz, 'a re-push preserves the original reported time');

insert into public.delayed_transfer_assignments
 (user_id,assignment_id,source_attempt_id,lesson_id,source_exercise_id,due_at,status,
  completed_evidence_id,created_at,completed_at,updated_at,device_id)
values ('40000000-0000-0000-0000-000000000001','transfer:complete','a',1,1,'2026-09-01',
 'completed','evidence-complete','2026-08-01','2026-09-02','2026-09-02','device-a');
-- An offline v8 migration gives stale pending data a fresh timestamp.
insert into public.delayed_transfer_assignments
 (user_id,assignment_id,source_attempt_id,lesson_id,source_exercise_id,due_at,status,
  created_at,updated_at,device_id)
values ('40000000-0000-0000-0000-000000000001','transfer:complete','a',1,1,'2026-09-01',
 'pending','2026-08-01','2099-01-01','device-b')
on conflict (user_id,assignment_id) do update set status=excluded.status,
 completed_evidence_id=excluded.completed_evidence_id, completed_at=excluded.completed_at,
 updated_at=excluded.updated_at,device_id=excluded.device_id;
select public.is((select status from public.delayed_transfer_assignments where assignment_id='transfer:complete'),
 'completed','a newly timestamped stale backfill cannot undo a cloud completion');
select public.is((select completed_evidence_id from public.delayed_transfer_assignments where assignment_id='transfer:complete'),
 'evidence-complete','the cloud retains the evidence that completed the assignment');

insert into public.delayed_transfer_assignments
 (user_id,assignment_id,source_attempt_id,lesson_id,source_exercise_id,due_at,status,created_at,updated_at,device_id)
values ('40000000-0000-0000-0000-000000000001','transfer:pending','b',1,2,'2026-09-01',
 'pending','2026-08-01','2099-01-01','device-b');
update public.delayed_transfer_assignments set status='completed', completed_evidence_id='older-clock',
 completed_at='2026-09-02',updated_at='2026-09-02',device_id='device-a' where assignment_id='transfer:pending';
select public.is((select status from public.delayed_transfer_assignments where assignment_id='transfer:pending'),
 'completed','completion wins even when its device clock is older');
update public.delayed_transfer_assignments set status='expired',updated_at='2099-01-02' where assignment_id='transfer:pending';
select public.is((select status from public.delayed_transfer_assignments where assignment_id='transfer:pending'),
 'completed','expiry cannot undo completion');
update public.delayed_transfer_assignments set completed_evidence_id='replacement',updated_at='2099-01-03'
 where assignment_id='transfer:pending';
select public.is((select completed_evidence_id from public.delayed_transfer_assignments where assignment_id='transfer:pending'),
 'older-clock','equal terminal states preserve the accepted completion evidence');

-- More than the default REST row cap. The scalar snapshot must include all.
insert into public.learning_evidence_events
 (user_id,evidence_id,lesson_id,skill,phase,correct,novel_task,observed_at)
select '40000000-0000-0000-0000-000000000001'::uuid,'audit-'||n,1,'vocabulary',
 'retrieve',true,false,now() from generate_series(1,1501) n;
select public.ok(not has_function_privilege('authenticated','public.export_account_snapshot(uuid)','EXECUTE'),
 'learners cannot invoke arbitrary-account exports');
select public.ok(not has_function_privilege('anon','public.export_account_snapshot(uuid)','EXECUTE'),
 'anonymous API callers cannot invoke account exports');
select public.throws_ok(
 $$select public.export_account_snapshot('40000000-0000-0000-0000-000000000002')$$,
 '42501', 'permission denied for function export_account_snapshot',
 'an authenticated direct RPC cannot export another account');

set local request.jwt.claim.sub = '40000000-0000-0000-0000-000000000002';
set local request.jwt.claims = '{"sub":"40000000-0000-0000-0000-000000000002","role":"authenticated"}';
select public.is((select count(*) from public.tutor_reply_reports where report_id='audit-report'),
 0::bigint,'another learner cannot read the report');
insert into public.learning_evidence_events
 (user_id,evidence_id,lesson_id,skill,phase,correct,novel_task,observed_at)
values ('40000000-0000-0000-0000-000000000002','other-account',1,'vocabulary','retrieve',true,false,now());
reset role;
set local role service_role;
select public.is(jsonb_array_length(public.export_account_snapshot('40000000-0000-0000-0000-000000000001')->'learning_evidence_events'),
 1501,'the export includes every row beyond the API cap and excludes other accounts');
select public.is(jsonb_array_length(public.export_account_snapshot('40000000-0000-0000-0000-000000000002')->'learning_evidence_events'),
 1,'the second account receives only its own evidence');
select public.is((select count(*) from jsonb_object_keys(public.export_account_snapshot('40000000-0000-0000-0000-000000000001'))),
 15::bigint,'every declared cloud table is included, including empty tables');
select public.is(jsonb_array_length(public.export_account_snapshot('40000000-0000-0000-0000-000000000001')->'tutor_reply_reports'),
 1,'reports are included in the snapshot');

-- STABLE SQL functions retain the calling statement's snapshot, even when
-- this same statement changes a row before reading the exported data.
with changed as (
 update public.learning_evidence_events set correct=false
 where user_id='40000000-0000-0000-0000-000000000001' and evidence_id='audit-1'
 returning evidence_id
)
select public.is((select (e->>'correct')::boolean from
 jsonb_array_elements(public.export_account_snapshot('40000000-0000-0000-0000-000000000001')->'learning_evidence_events') e
 where e->>'evidence_id'='audit-1'), true,
 'the export uses one snapshot rather than observing writes between table reads')
from changed;
select public.is((select correct from public.learning_evidence_events
 where user_id='40000000-0000-0000-0000-000000000001' and evidence_id='audit-1'), false,
 'the concurrent-statement test really changed the underlying row');

reset role;
select * from public.finish();
rollback;
