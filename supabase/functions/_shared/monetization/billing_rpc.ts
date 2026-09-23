import type { SupabaseClient } from "npm:@supabase/supabase-js@2.110.7";
import {
  createTokenCipher,
  deriveObfuscatedAccountId,
} from "./billing_crypto.ts";
import {
  createPlayClient,
  parseServiceAccount,
  type PlayClient,
} from "./play_client.ts";
import type { Discovery } from "./play_discovery.ts";
import type { BillingStore, JobContext } from "./purchase_jobs.ts";

type Json = Record<string, unknown>;

export interface BillingDependencies {
  /** HMAC-derived candidate; the database freezes the first one per user. */
  obfuscatedAccountId(
    userId: string,
  ): Promise<{ id: string; keyVersion: number }>;
  bindAccount(
    userId: string,
    candidate: string,
    keyVersion: number,
  ): Promise<string>;
  createIntent(
    userId: string,
    productId: string,
    basePlanId: string,
    idempotencyKey: string,
  ): Promise<Json>;
  register(
    userId: string,
    tokenDigest: string,
    encryptedToken: string,
    productId: string,
    intentId: string | null,
  ): Promise<Json>;
  status(userId: string, purchaseId: string): Promise<Json | null>;
  jobs: JobContext;
}

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

async function call<T>(
  admin: () => SupabaseClient,
  name: string,
  args: Record<string, unknown> = {},
): Promise<T> {
  const { data, error } = await admin().rpc(name, args);
  if (error) throw new Error(`${name} failed`);
  return data as T;
}

/** Records one authenticated Play notification; returns its outcome. */
export const recordPlayNotification = (admin: () => SupabaseClient) =>
(
  subscription: string,
  messageId: string,
  kind: string,
  type: number | null,
  tokenDigest: string | null,
  eventTime: string | null,
) =>
  call<string>(admin, "record_play_notification", {
    p_subscription: subscription,
    p_message_id: messageId,
    p_kind: kind,
    p_type: type,
    p_token_digest: tokenDigest,
    p_event_time: eventTime,
  });

/** Scheduler-side queries for the billing worker. */
export const workerQueries = (admin: () => SupabaseClient) => ({
  enqueueReconciliation: (limit: number) =>
    call<number>(admin, "enqueue_billing_reconciliation", { p_limit: limit }),
  dueJobs: (limit: number) =>
    call<string[]>(admin, "due_billing_jobs", { p_limit: limit }),
  health: () => call<Record<string, number>>(admin, "billing_health"),
  discoveries: {
    due: (limit: number) =>
      call<Discovery[]>(admin, "due_play_discoveries", { p_limit: limit }),
    resolve: (digest: string, obfuscated: string | null) =>
      call<Record<string, unknown>>(admin, "resolve_play_discovery", {
        p_token_digest: digest,
        p_obfuscated_id: obfuscated,
      }),
    fail: (digest: string, retrySeconds: number, final: boolean) =>
      call<boolean>(admin, "fail_play_discovery", {
        p_token_digest: digest,
        p_retry_seconds: retrySeconds,
        p_final: final,
      }),
  },
});
