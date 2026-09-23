import type { SupabaseClient } from "npm:@supabase/supabase-js@2.110.7";
import type { BillingDependencies } from "./handler.ts";
import {
  createTokenCipher,
  deriveObfuscatedAccountId,
} from "../_shared/monetization/billing_crypto.ts";
import {
  createPlayClient,
  parseServiceAccount,
  type PlayClient,
} from "../_shared/monetization/play_client.ts";
import type { BillingStore } from "../_shared/monetization/purchase_jobs.ts";

// Every billing secret must be present, or the purchase routes stay off.
export const billingSecrets = [
  "MONETIZATION_TOKEN_KEY",
  "BILLING_ACCOUNT_HMAC_KEY",
  "BILLING_ACCOUNT_HMAC_VERSION",
  "PLAY_PACKAGE_NAME",
  "PLAY_SERVICE_ACCOUNT_JSON",
];

/** Maps the billing dependencies onto the service-role RPCs. */
export async function createBilling(
  env: (name: string) => string,
  admin: () => SupabaseClient,
  play?: PlayClient,
): Promise<BillingDependencies> {
  const hmacVersion = Number(env("BILLING_ACCOUNT_HMAC_VERSION"));
  if (!Number.isInteger(hmacVersion) || hmacVersion < 1) {
    throw new Error("Invalid HMAC key version");
  }
  const cipher = await createTokenCipher(env("MONETIZATION_TOKEN_KEY"));
  play ??= createPlayClient({
    packageName: env("PLAY_PACKAGE_NAME"),
    account: parseServiceAccount(env("PLAY_SERVICE_ACCOUNT_JSON")),
  });
  const rpc = async <T>(name: string, args: Record<string, unknown>) => {
    const { data, error } = await admin().rpc(name, args);
    if (error) throw new Error(`${name} failed`);
    return data as T;
  };
  const store: BillingStore = {
    claim: (job, owner, lease) =>
      rpc("claim_billing_job", {
        p_job: job,
        p_owner: owner,
        p_lease_seconds: lease,
      }),
    jobPurchase: (job, fence, owner) =>
      rpc("get_billing_job_purchase", {
        p_job: job,
        p_fence: fence,
        p_owner: owner,
      }),
    apply: (job, fence, owner, result) =>
      rpc("apply_play_verification", {
        p_job: job,
        p_fence: fence,
        p_owner: owner,
        p_result: result,
      }),
    completeAcknowledgement: (job, fence, owner) =>
      rpc("complete_billing_acknowledgement", {
        p_job: job,
        p_fence: fence,
        p_owner: owner,
      }),
    fail: (job, fence, owner, code, retrySeconds, dead) =>
      rpc("fail_billing_job", {
        p_job: job,
        p_fence: fence,
        p_owner: owner,
        p_error: code,
        p_retry_seconds: retrySeconds,
        p_dead: dead,
      }),
  };
  return {
    obfuscatedAccountId: async (userId) => ({
      id: await deriveObfuscatedAccountId(
        env("BILLING_ACCOUNT_HMAC_KEY"),
        userId,
      ),
      keyVersion: hmacVersion,
    }),
    bindAccount: (userId, candidate, keyVersion) =>
      rpc("billing_bind_account", {
        p_user: userId,
        p_candidate: candidate,
        p_key_version: keyVersion,
      }),
    createIntent: (userId, productId, basePlanId, key) =>
      rpc("create_purchase_intent", {
        p_user: userId,
        p_product: productId,
        p_base_plan: basePlanId,
        p_idempotency_key: key,
      }),
    register: (userId, digest, encrypted, productId, intentId) =>
      rpc("register_purchase_verification", {
        p_user: userId,
        p_token_digest: digest,
        p_encrypted_token: encrypted,
        p_product: productId,
        p_intent: intentId,
      }),
    status: (userId, purchaseId) =>
      rpc("get_purchase_verification_status", {
        p_user: userId,
        p_purchase: purchaseId,
      }),
    jobs: {
      store,
      play,
      cipher,
      owner: `monetization-api:${crypto.randomUUID()}`,
    },
  };
}
