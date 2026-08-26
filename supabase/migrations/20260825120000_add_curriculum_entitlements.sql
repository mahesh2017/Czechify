-- Server-managed curriculum access for reviewers and support cases.
--
-- The client may read only its own row. It receives no write privileges:
-- hiding an ordinary client-writable flag in the UI would not prevent a user
-- from granting it to themselves with the public API and their auth token.
create table if not exists public.curriculum_entitlements (
  user_id     uuid        primary key references auth.users (id) on delete cascade,
  unlock_all  boolean     not null default false,
  expires_at  timestamptz,
  reason      text,
  updated_at  timestamptz not null default now(),
  constraint curriculum_entitlements_reason_length
    check (reason is null or length(reason) <= 200)
);

alter table public.curriculum_entitlements enable row level security;

drop policy if exists curriculum_entitlements_owner_read
  on public.curriculum_entitlements;
create policy curriculum_entitlements_owner_read
on public.curriculum_entitlements
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on table public.curriculum_entitlements from public, anon, authenticated;
grant select on table public.curriculum_entitlements to authenticated;

-- The service role bypasses RLS, but explicit privileges keep this migration
-- compatible with projects whose public-schema defaults were tightened.
grant select, insert, update, delete on table public.curriculum_entitlements
  to service_role;
