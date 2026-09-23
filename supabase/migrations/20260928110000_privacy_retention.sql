-- Storage limitation (GDPR Art. 5(1)(e)) for monetization records, applied
-- to every account wherever it is. Each record is kept only while it does
-- its job, then deleted by the monetization worker.
--
-- - A deleted account's purchase stays ownerless only while Google Play could
--   still restore it, then 30 days. Google Play is the merchant of record;
--   the bookkeeping documents are Google's payout reports, kept outside this
--   database under Czech accounting and VAT law.
-- - Referral lesson summaries: 90 days after the invitation is decided, or
--   90 days after the campaign ends.
-- - The existing-user snapshot: 90 days after its claim window closes. The
--   granted units themselves stay.
-- - Operational rows (notification dedupe, intents, finished jobs, audit
--   rows of deleted accounts): 30 days.
begin;

create function public.cleanup_privacy_records()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare purchases integer; receipts integer; snapshot integer; inbox integer; intents integer;
  jobs integer; billing_audit integer; grant_audit integer;
begin
  delete from monetization_private.store_purchases p
    where p.user_id is null
      and ((p.state in ('expired','revoked') and coalesce(p.last_verified_at, p.created_at) < now() - interval '30 days')
        or ((p.state is null or p.state = 'pending') and p.created_at < now() - interval '30 days'));
  get diagnostics purchases = row_count;

  with decided as (
    select c.id,
      case
        when (select count(*) from monetization_private.referral_reward_events e where e.claim_id = c.id) = 2
          then (select max(e.created_at) from monetization_private.referral_reward_events e where e.claim_id = c.id)
        when c.risk_state = 'rejected'
          then coalesce((select r.resolved_at from monetization_private.referral_review_cases r where r.claim_id = c.id),
            (select max(x.received_at) from monetization_private.referral_receipts x where x.claim_id = c.id))
        -- A deleted referrer: nothing can be earned any more.
        when c.referrer_id is null
          then (select max(x.received_at) from monetization_private.referral_receipts x where x.claim_id = c.id)
      end decided_at,
      k.ends_at campaign_ends_at
    from monetization_private.referral_claims c
    join monetization_private.referral_campaigns k on k.id = c.campaign_id)
  delete from monetization_private.referral_receipts x using decided d
    where x.claim_id = d.id
      and (d.decided_at < now() - interval '90 days' or d.campaign_ends_at < now() - interval '90 days');
  get diagnostics receipts = row_count;

  delete from monetization_private.legacy_migration_snapshot s
    using monetization_private.legacy_migration_runs r
    where r.migration_id = s.migration_id and r.claim_window_ends_at < now() - interval '90 days';
  get diagnostics snapshot = row_count;

  delete from monetization_private.billing_notification_inbox where received_at < now() - interval '30 days';
  get diagnostics inbox = row_count;
  delete from monetization_private.purchase_intents where expires_at < now() - interval '30 days';
  get diagnostics intents = row_count;
  delete from monetization_private.billing_jobs
    where state in ('done','dead') and updated_at < now() - interval '30 days';
  get diagnostics jobs = row_count;
  delete from monetization_private.billing_audit_events
    where user_id is null and purchase_id is null and created_at < now() - interval '30 days';
  get diagnostics billing_audit = row_count;
  delete from monetization_private.entitlement_audit
    where user_id is null and created_at < now() - interval '30 days';
  get diagnostics grant_audit = row_count;

  return jsonb_build_object('ownerless_purchases', purchases, 'referral_receipts', receipts,
    'legacy_snapshot_rows', snapshot, 'notifications', inbox, 'purchase_intents', intents,
    'billing_jobs', jobs, 'billing_audit', billing_audit, 'grant_audit', grant_audit);
end $$;

revoke all on function public.cleanup_privacy_records() from public, anon, authenticated;
grant execute on function public.cleanup_privacy_records() to service_role;

commit;
