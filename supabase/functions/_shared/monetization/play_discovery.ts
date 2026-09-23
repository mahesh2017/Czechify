// Purchases Google told us about before the app did. The notification
// endpoint keeps the encrypted token; this asks Play which account started
// the purchase (the obfuscated ID only this server hands out), registers it
// for that account and verifies it, which provisions access and queues the
// acknowledgement Play needs within three days.

import { PlayApiError } from "./play_client.ts";
import { normalizeSubscription, UnexpectedPlayResponse } from "./play_state.ts";
import {
  backoffSeconds,
  type JobContext,
  runBillingJob,
} from "./purchase_jobs.ts";

type Json = Record<string, unknown>;

export interface Discovery {
  token_digest: string;
  encrypted_token: string;
  product_id: string;
  attempts: number;
}

export interface DiscoveryStore {
  due(limit: number): Promise<Discovery[]>;
  /** Registers the purchase for the account with this obfuscated ID. */
  resolve(tokenDigest: string, obfuscatedId: string | null): Promise<Json>;
  fail(
    tokenDigest: string,
    retrySeconds: number,
    final: boolean,
  ): Promise<boolean>;
}

export type DiscoveryOutcome =
  | "provisioned"
  | "registered"
  | "no_owner"
  | "retry"
  | "failed";

/** Play answers within a day or so; after this many tries it is given up. */
export const maxDiscoveryAttempts = 30;

export async function runDiscovery(
  ctx: JobContext,
  store: DiscoveryStore,
  discovery: Discovery,
): Promise<DiscoveryOutcome> {
  let resolved: Json;
  try {
    const token = await ctx.cipher.decrypt(discovery.encrypted_token);
    const fetched = await ctx.play.getSubscription(discovery.product_id, token);
    const normalized = await normalizeSubscription(
      fetched.body,
      discovery.product_id,
      (ctx.now ?? (() => new Date()))(),
      fetched.text,
    );
    resolved = await store.resolve(
      discovery.token_digest,
      normalized.obfuscated_account_id,
    );
  } catch (error) {
    const attempt = discovery.attempts + 1;
    const final = error instanceof UnexpectedPlayResponse ||
      (error instanceof PlayApiError && !error.retryable) ||
      attempt >= maxDiscoveryAttempts;
    await store.fail(
      discovery.token_digest,
      backoffSeconds(
        attempt,
        error instanceof PlayApiError ? error.retryAfterSeconds : null,
        ctx.random,
      ),
      final,
    ).catch(() => {
      // Still due; the next run tries again.
    });
    return final ? "failed" : "retry";
  }
  if (resolved.status === "no_owner") return "no_owner";
  if (typeof resolved.job_id !== "string") return "registered";
  // Verify now rather than on the next run: the acknowledgement clock runs.
  const outcome = await runBillingJob(ctx, resolved.job_id);
  if (outcome.status !== "provisioned") return "registered";
  if (outcome.ackJobId) await runBillingJob(ctx, outcome.ackJobId);
  return "provisioned";
}
