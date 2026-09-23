import type { SupabaseClient } from "npm:@supabase/supabase-js@2.110.7";
import { parseServiceAccount } from "./google_auth.ts";
import {
  createIntegrityVerifier,
  type IntegrityVerifier,
} from "./play_integrity.ts";
import type { ReferralDependencies } from "../../monetization-api/referrals.ts";

type Json = Record<string, unknown>;

async function call<T>(
  admin: () => SupabaseClient,
  name: string,
  args: Record<string, unknown> = {},
): Promise<T> {
  const { data, error } = await admin().rpc(name, args);
  if (error) throw new Error(`${name} failed`);
  return data as T;
}

/**
 * Integrity needs the package, the app's signing-certificate digests (as Play
 * reports them, comma-separated) and a service account with Play Integrity
 * access. Missing any of them leaves the verifier off: token submissions then
 * answer 503, and only the explicit review route remains.
 */
export function integrityFromEnv(
  env: (name: string) => string | undefined,
): IntegrityVerifier | null {
  const packageName = env("PLAY_PACKAGE_NAME");
  const digests = (env("PLAY_INTEGRITY_CERT_DIGESTS") ?? "").split(",")
    .map((d) => d.trim()).filter(Boolean);
  const account = env("PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON") ??
    env("PLAY_SERVICE_ACCOUNT_JSON");
  if (!packageName || digests.length === 0 || !account) return null;
  return createIntegrityVerifier({
    packageName,
    certificateDigests: digests,
    account: parseServiceAccount(account, "integrity_not_configured"),
  });
}

export function createReferrals(
  admin: () => SupabaseClient,
  integrity: IntegrityVerifier | null,
): ReferralDependencies {
  return {
    code: (actor, campaign) =>
      call<Json>(admin, "get_or_create_referral_code", {
        p_actor: actor,
        p_campaign: campaign,
      }),
    claim: (actor, campaign, code) =>
      call<Json>(admin, "claim_referral", {
        p_actor: actor,
        p_campaign: campaign,
        p_code: code,
      }),
    challenge: (actor, claim, digest) =>
      call<Json>(admin, "issue_referral_challenge", {
        p_actor: actor,
        p_claim: claim,
        p_receipt_digest: digest,
      }),
    findReceipt: (actor, claim, attempt, digest) =>
      call<Json | null>(admin, "find_referral_receipt", {
        p_actor: actor,
        p_claim: claim,
        p_attempt: attempt,
        p_digest: digest,
      }),
    submit: (actor, claim, nonce, receipt, digest, verdict) =>
      call<Json>(admin, "submit_referral_receipt", {
        p_actor: actor,
        p_claim: claim,
        p_nonce: nonce,
        p_receipt: receipt,
        p_digest: digest,
        p_integrity: verdict,
      }),
    status: (actor, after, limit) =>
      call<Json>(admin, "get_referral_status", {
        p_actor: actor,
        p_after: after,
        p_limit: limit,
      }),
    integrity,
  };
}

/** Scheduler-side referral work for the monetization worker. */
export const referralWorkerQueries = (admin: () => SupabaseClient) => ({
  claimsToProcess: (limit: number) =>
    call<string[]>(admin, "referral_claims_to_process", { p_limit: limit }),
  processClaim: (claim: string) =>
    call<Json>(admin, "process_referral_claim", { p_claim: claim }),
  cleanup: () => call<Json>(admin, "cleanup_referral_records"),
});
