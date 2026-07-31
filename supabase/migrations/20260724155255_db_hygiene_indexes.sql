-- Timestamp matches the migration version already applied to production.
begin;

-- Advisor 0001 (unindexed FK): ai_service_daily_usage's PK leads with
-- `service`, so the user_id FK used by the ON DELETE CASCADE from auth.users
-- has no covering index.
create index if not exists ai_service_daily_usage_user_idx
  on public.ai_service_daily_usage (user_id);

-- Advisor 0001 + 0005: the existing 2-column pack index only prefixes the
-- 3-column FK (pack_key, pack_version, checksum), so the FK reads uncovered
-- AND the partial index reports unused. Replace it with the exact covering
-- index for the FK.
drop index if exists public.content_release_items_pack_idx;
create index if not exists content_release_items_pack_fk_idx
  on public.content_release_items (pack_key, pack_version, checksum);

-- Advisor 0008 (RLS enabled, no policy): these are service-role-only counter
-- tables. RLS-on with no policy is the intended, most-restrictive state — it
-- denies anon/authenticated entirely while service_role bypasses RLS. Document
-- the intent so the informational lint is understood, not "fixed" by adding a
-- client policy that would weaken them.
comment on table public.ai_daily_usage is
  'AI daily usage counters. Service-role only by design: RLS enabled with no '
  'policy denies all client access; consume_ai_quota (SECURITY DEFINER) writes.';
comment on table public.ai_service_daily_usage is
  'Per-service AI daily usage counters. Service-role only by design: RLS '
  'enabled with no policy denies all client access; '
  'consume_service_daily_quota (SECURITY DEFINER) writes.';

commit;
