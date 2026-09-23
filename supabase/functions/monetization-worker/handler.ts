// Scheduled billing worker: queues reconciliation, runs due verification and
// acknowledgement jobs within a time budget, and reports health counts. The
// scheduler authenticates with a shared secret; gateway JWT verification is
// off for this function (config.toml).

import {
  type JobContext,
  type JobOutcome,
  runBillingJob,
} from "../_shared/monetization/purchase_jobs.ts";

export interface Dependencies {
  secret: string;
  jobs: () => Promise<JobContext>;
  enqueueReconciliation(limit: number): Promise<number>;
  dueJobs(limit: number): Promise<string[]>;
  health(): Promise<Record<string, number>>;
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
    try {
      const ctx = await deps.jobs();
      const reconciliation = await deps.enqueueReconciliation(100);
      const outcomes: Record<string, number> = {};
      for (const job of await deps.dueJobs(batch)) {
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
      const health = await deps.health();
      if (health.unacknowledged_over_1h > 0 || health.dead_jobs > 0) {
        log("billing_attention_required", health);
      }
      return Response.json({ reconciliation, outcomes, health });
    } catch {
      log("billing_worker_failed", {});
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
