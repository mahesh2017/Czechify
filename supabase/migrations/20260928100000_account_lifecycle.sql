-- Phase 7b: what a learner sees about the existing-user migration, their
-- offline claim, and an export that covers the monetization records without
-- secrets or anyone else's identity.
begin;

-- The migration the app talks about: the most recently applied run. Returns
-- available=false until an operator has applied one.
create function public.legacy_claim_status(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((
    select jsonb_build_object(
      'available', true,
      'migration_id', r.migration_id,
      'cutoff_at', r.cutoff_at,
      'grace_ends_at', r.grace_ends_at,
      'claim_window_ends_at', r.claim_window_ends_at,
      'eligible', exists (select 1 from auth.users u where u.id = p_user and u.created_at < r.cutoff_at),
      'claim_window_open', now() < r.claim_window_ends_at,
      'legacy_unit_ids', (select coalesce(jsonb_agg(g.unit_id order by g.unit_id), '[]'::jsonb)
        from public.course_unit_grants g
        where g.user_id = p_user and g.source = 'legacy' and g.revoked_at is null),
      'claim', (select jsonb_build_object('status', c.status, 'unit_ids', to_jsonb(c.resolved_unit_ids))
        from monetization_private.legacy_migration_claims c
        where c.migration_id = r.migration_id and c.user_id = p_user and c.source = 'offline_claim'))
    from monetization_private.legacy_migration_runs r
    where r.applied_at is not null
    order by r.applied_at desc, r.migration_id
    limit 1), jsonb_build_object('available', false));
$$;

-- The account export, extended with the monetization records the learner
-- owns. Left out on purpose: purchase tokens and their digests, encrypted
-- replays, internal source keys, fraud signals, and the other side of a
-- referral (no referrer or invitee IDs, no claim IDs on rewards).
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
    'store_purchases', (select coalesce(jsonb_agg(jsonb_build_object(
      'product_id',p.product_id,'base_plan_id',p.base_plan_id,'state',p.state,'valid_until',p.valid_until,
      'auto_renewing',p.auto_renewing,'created_at',p.created_at,'last_verified_at',p.last_verified_at)
      order by p.created_at), '[]'::jsonb)
      from monetization_private.store_purchases p where p.user_id = target_user_id),
    'referral_codes', (select coalesce(jsonb_agg(jsonb_build_object(
      'code',c.code,'campaign_id',c.campaign_id,'created_at',c.created_at,'revoked_at',c.revoked_at)
      order by c.created_at), '[]'::jsonb)
      from monetization_private.referral_codes c where c.owner_id = target_user_id),
    'referral_claims', (select coalesce(jsonb_agg(jsonb_build_object(
      'campaign_id',c.campaign_id,'created_at',c.created_at) order by c.created_at), '[]'::jsonb)
      from monetization_private.referral_claims c where c.referee_id = target_user_id),
    'referral_receipts', (select coalesce(jsonb_agg(jsonb_build_object(
      'lesson_id',r.lesson_id,'attempt_id',r.attempt_id,'started_at',r.started_at_client,
      'completed_at',r.completed_at_client,'received_at',r.received_at,'evidence_state',r.evidence_state)
      order by r.received_at), '[]'::jsonb)
      from monetization_private.referral_receipts r where r.referee_id = target_user_id),
    'referral_rewards', (select coalesce(jsonb_agg(jsonb_build_object(
      'unit_id',e.unit_id,'outcome',e.outcome,'created_at',e.created_at) order by e.created_at), '[]'::jsonb)
      from monetization_private.referral_reward_events e where e.beneficiary_id = target_user_id),
    'ai_daily_allowance', (select coalesce(jsonb_agg(jsonb_build_object(
      'day',a.quota_day,'conversation_turns',a.conversation_count,'summaries',a.summary_count,
      'course_feedback',a.feedback_count) order by a.quota_day), '[]'::jsonb)
      from monetization_private.ai_daily_allowance a where a.user_id = target_user_id),
    'ai_chat_sessions', (select coalesce(jsonb_agg(jsonb_build_object(
      'session_id',s.session_id,'turns',s.turns,'created_at',s.created_at,'updated_at',s.updated_at)
      order by s.created_at), '[]'::jsonb)
      from monetization_private.ai_chat_sessions s where s.user_id = target_user_id),
    'legacy_migration_claims', (select coalesce(jsonb_agg(jsonb_build_object(
      'migration_id',c.migration_id,'source',c.source,'unit_ids',to_jsonb(c.resolved_unit_ids),
      'status',c.status,'received_at',c.received_at,'decided_at',c.decided_at) order by c.received_at), '[]'::jsonb)
      from monetization_private.legacy_migration_claims c where c.user_id = target_user_id),
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

-- Whether deleting this account leaves a Store subscription renewing. The
-- deletion route warns first: deleting Czechify data is not a Play
-- cancellation.
create function public.account_deletion_notice(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('renewing_subscriptions', count(*))
  from monetization_private.store_purchases p
  where p.user_id = p_user and p.auto_renewing is true
    and p.state in ('active','in_grace_period','on_hold','paused');
$$;

revoke all on function public.export_account_snapshot(uuid),
  public.legacy_claim_status(uuid),
  public.account_deletion_notice(uuid) from public, anon, authenticated;
grant execute on function public.export_account_snapshot(uuid),
  public.legacy_claim_status(uuid),
  public.account_deletion_notice(uuid) to service_role;

commit;
