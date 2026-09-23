-- Add owner-only access history to the existing account export.
-- One SQL statement reads every table from the same MVCC snapshot. JSON
-- aggregation also avoids PostgREST's row cap. Concurrent sync cannot move a
-- row between pages because the export no longer makes separate page reads.
begin;

create or replace function public.export_account_snapshot(target_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'course_unit_grants', (select coalesce(jsonb_agg(jsonb_build_object(
      'id',g.id,'unit_id',g.unit_id,'source',g.source,'created_at',g.created_at,'revoked_at',g.revoked_at)), '[]'::jsonb)
      from public.course_unit_grants g where g.user_id = target_user_id),
    'course_access_windows', (select coalesce(jsonb_agg(jsonb_build_object(
      'kind',w.kind,'starts_at',w.starts_at,'ends_at',w.ends_at)), '[]'::jsonb)
      from public.course_access_windows w where w.user_id = target_user_id),
    'feature_access', (select coalesce(jsonb_agg(jsonb_build_object(
      'feature',f.feature,'state',f.state,'valid_until',f.valid_until,'verified_at',f.verified_at)), '[]'::jsonb)
      from monetization_private.feature_entitlements f where f.user_id = target_user_id),
    'lesson_progress', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.lesson_progress t where t.user_id = target_user_id),
    'earned_badges', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.earned_badges t where t.user_id = target_user_id),
    'user_progress', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.user_progress t where t.user_id = target_user_id),
    'srs_cards', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.srs_cards t where t.user_id = target_user_id),
    'custom_cards', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.custom_cards t where t.user_id = target_user_id),
    'gamification_state', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.gamification_state t where t.user_id = target_user_id),
    'learner_profiles', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.learner_profiles t where t.user_id = target_user_id),
    'reminder_preferences', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.reminder_preferences t where t.user_id = target_user_id),
    'placement_profiles', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.placement_profiles t where t.user_id = target_user_id),
    'ai_daily_usage', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.ai_daily_usage t where t.user_id = target_user_id),
    'ai_service_daily_usage', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.ai_service_daily_usage t where t.user_id = target_user_id),
    'curriculum_entitlements', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.curriculum_entitlements t where t.user_id = target_user_id),
    'tutor_reply_reports', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.tutor_reply_reports t where t.user_id = target_user_id),
    'learning_evidence_events', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.learning_evidence_events t where t.user_id = target_user_id),
    'delayed_transfer_assignments', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      from public.delayed_transfer_assignments t where t.user_id = target_user_id)
  );
$$;

-- The edge function verifies the caller's JWT and supplies that user's id.
-- Clients must never be able to choose another account through this RPC.
revoke all on function public.export_account_snapshot(uuid)
  from public, anon, authenticated;
grant execute on function public.export_account_snapshot(uuid) to service_role;

commit;
