// Scheduled monetization worker. Billing: queues reconciliation, runs due
// verification and acknowledgement jobs within a time budget. Referrals:
// moves forward claims that were waiting on account linking or paused
// processing, then applies retention. Reports health counts. The scheduler
// authenticates with a shared secret; gateway JWT verification is off for
// this function (config.toml).

import {
  type JobContext,
  type JobOutcome,
  runBillingJob,
} from "../_shared/monetization/purchase_jobs.ts";

export interface BillingWork {
  jobs: () => Promise<JobContext>;
  enqueueReconciliation(limit: number): Promise<number>;
  dueJobs(limit: number): Promise<string[]>;
  health(): Promise<Record<string, number>>;
}

export interface ReferralWork {
  claimsToProcess(limit: number): Promise<string[]>;
  processClaim(claim: string): Promise<unknown>;
  cleanup(): Promise<unknown>;
}

export interface Dependencies {
  secret: string;
  /** Absent until billing secrets are configured. */
  billing?: BillingWork;
  referrals?: ReferralWork;
  now?: () => number;
  log?: (event: string, detail: Record<string, unknown>) => void;
}

const budgetMs = 40_000;
const batch = 50;

export function createHandler(deps: Dependencies) {
  const now = deps.now ?? Date.now;
  const log = deps.log ?? ((event, detail) => console.warn(event, detail));
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") return new Response(null, { status: 405 });
    if (
      !await secretMatches(request.headers.get("x-worker-secret"), deps.secret)
    ) {
      return new Response(null, { status: 401 });
    }
    const started = now();
    const report: Record<string, unknown> = {};
    try {
      if (deps.billing) {
        const ctx = await deps.billing.jobs();
        report.reconciliation = await deps.billing.enqueueReconciliation(100);
        const outcomes: Record<string, number> = {};
        for (const job of await deps.billing.dueJobs(batch)) {
          if (now() - started > budgetMs) break;
          let outcome: JobOutcome["status"];
          try {
            outcome = (await runBillingJob(ctx, job)).status;
          } catch {
            // A store failure before the lease; the job stays due.
            outcome = "retry";
          }
          outcomes[outcome] = (outcomes[outcome] ?? 0) + 1;
        }
        report.outcomes = outcomes;
        const health = await deps.billing.health();
        report.health = health;
        if (health.unacknowledged_over_1h > 0 || health.dead_jobs > 0) {
          log("billing_attention_required", health);
        }
      }
      if (deps.referrals) {
        let processed = 0;
        let failed = 0;
        for (const claim of await deps.referrals.claimsToProcess(batch)) {
          if (now() - started > budgetMs) break;
          try {
            await deps.referrals.processClaim(claim);
            processed++;
          } catch {
            // Processing is idempotent; the claim is selected again next run.
            failed++;
          }
        }
        report.referrals = {
          processed,
          failed,
          retention: await deps.referrals.cleanup(),
        };
        if (failed > 0) log("referral_processing_failed", { failed });
      }
      return Response.json(report);
    } catch {
      log("monetization_worker_failed", {});
      return new Response(null, { status: 503 });
    }
  };
}

/** Constant-time comparison of SHA-256 digests; an empty secret never matches. */
async function secretMatches(given: string | null, secret: string) {
  if (!given || secret.length < 32) return false;
  const digest = async (value: string) =>
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
    );
  const [a, b] = await Promise.all([digest(given), digest(secret)]);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}
