// Runs one leased verification or acknowledgement job. The database decides
// ownership, fencing and access; this code only moves Play's answer across.
// Shared by the request path (inline attempt) and the retry worker.

import type { TokenCipher } from "./billing_crypto.ts";
import { PlayApiError, type PlayClient } from "./play_client.ts";
import { normalizeSubscription, UnexpectedPlayResponse } from "./play_state.ts";

type Json = Record<string, unknown>;

export interface BillingStore {
  claim(
    job: string,
    owner: string,
    leaseSeconds: number,
  ): Promise<number | null>;
  jobPurchase(
    job: string,
    fence: number,
    owner: string,
  ): Promise<
    { operation: string; product_id: string; encrypted_token: string } | null
  >;
  apply(job: string, fence: number, owner: string, result: Json): Promise<Json>;
  completeAcknowledgement(
    job: string,
    fence: number,
    owner: string,
  ): Promise<boolean>;
  fail(
    job: string,
    fence: number,
    owner: string,
    error: string,
    retrySeconds: number,
    dead: boolean,
  ): Promise<boolean>;
}

export interface JobContext {
  store: BillingStore;
  play: PlayClient;
  cipher: TokenCipher;
  owner: string;
  now?: () => Date;
  random?: () => number;
}

export type JobOutcome =
  | {
    status: "provisioned";
    state: string;
    access: boolean;
    revision: number;
    ackJobId: string | null;
    /**
     * Whose purchase it is after this check. Play can name another account
     * than the one that sent the token in; that account then owns it.
     */
    ownerId: string | null;
  }
  | { status: "acknowledged" }
  | { status: "account_binding_mismatch"; recoveryCaseId?: string }
  | { status: "product_mismatch" }
  | { status: "not_claimed" }
  | { status: "retry"; code: string }
  | { status: "dead"; code: string };

const leaseSeconds = 60;
/**
 * After this many attempts a job stops retrying and is counted by
 * `billing_health` as dead. With the one-hour backoff cap and jitter this
 * spans two to three days, inside Play's three-day acknowledgement deadline;
 * `unacknowledged_over_1h` alerts long before that.
 */
export const maxAttempts = 80;

/** 5 s doubling to one hour, with jitter; Play's Retry-After wins. */
export function backoffSeconds(
  attempt: number,
  retryAfter: number | null,
  random: () => number = Math.random,
): number {
  if (retryAfter !== null) return Math.min(3600, Math.ceil(retryAfter));
  const base = Math.min(3600, 5 * 2 ** Math.max(0, attempt - 1));
  return Math.ceil(base * (0.5 + random() / 2));
}

export async function runBillingJob(
  ctx: JobContext,
  job: string,
): Promise<JobOutcome> {
  const fence = await ctx.store.claim(job, ctx.owner, leaseSeconds);
  if (fence === null) return { status: "not_claimed" };
  try {
    const purchase = await ctx.store.jobPurchase(job, fence, ctx.owner);
    if (!purchase) return { status: "not_claimed" };
    const token = await ctx.cipher.decrypt(purchase.encrypted_token);
    if (purchase.operation === "acknowledge") {
      await ctx.play.acknowledge(purchase.product_id, token);
      return await ctx.store.completeAcknowledgement(job, fence, ctx.owner)
        ? { status: "acknowledged" }
        : { status: "not_claimed" };
    }
    const fetched = await ctx.play.getSubscription(purchase.product_id, token);
    const normalized = await normalizeSubscription(
      fetched.body,
      purchase.product_id,
      (ctx.now ?? (() => new Date()))(),
      fetched.text,
    );
    const applied = await ctx.store.apply(job, fence, ctx.owner, {
      ...normalized,
    });
    switch (applied.status) {
      case "provisioned":
        return {
          status: "provisioned",
          state: normalized.state,
          access: applied.access === true,
          revision: Number(applied.revision),
          ackJobId: typeof applied.ack_job_id === "string"
            ? applied.ack_job_id
            : null,
          ownerId: typeof applied.owner_id === "string"
            ? applied.owner_id
            : null,
        };
      case "account_binding_mismatch":
        // Support can move the purchase; the case is its reference.
        return typeof applied.recovery_case_id === "string"
          ? { status: applied.status, recoveryCaseId: applied.recovery_case_id }
          : { status: applied.status };
      case "product_mismatch":
        return { status: applied.status };
      default:
        return { status: "not_claimed" };
    }
  } catch (error) {
    const permanent = error instanceof UnexpectedPlayResponse ||
      (error instanceof PlayApiError && !error.retryable) ||
      fence >= maxAttempts;
    const code = error instanceof PlayApiError
      ? error.code
      : error instanceof UnexpectedPlayResponse
      ? "unexpected_play_response"
      : "billing_internal_error";
    const retryAfter = error instanceof PlayApiError
      ? error.retryAfterSeconds
      : null;
    try {
      await ctx.store.fail(
        job,
        fence,
        ctx.owner,
        code,
        backoffSeconds(fence, retryAfter, ctx.random),
        permanent,
      );
    } catch {
      // The lease expires on its own; the job becomes claimable again.
    }
    return permanent ? { status: "dead", code } : { status: "retry", code };
  }
}
