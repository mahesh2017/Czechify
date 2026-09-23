// Scheduled monetization worker. Billing: queues reconciliation, runs due
// verification and acknowledgement jobs within a time budget, and finds the
// owner of purchases Google notified before the app sent them in. Referrals:
// moves forward claims that were waiting on account linking or paused
// processing, then applies retention. AI: clears expired chat replay and
// tombstones. Reports health counts. The scheduler
// authenticates with a shared secret; gateway JWT verification is off for
// this function (config.toml).

import {
  type DiscoveryOutcome,
  type DiscoveryStore,
  runDiscovery,
} from "../_shared/monetization/play_discovery.ts";
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
  /** Purchases Google notified before the app sent them in. */
  discoveries?: DiscoveryStore;
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
  /** Clears expired AI chat replay content and request tombstones. */
  aiRetention?: () => Promise<unknown>;
  /** Deletes monetization records past their retention period. */
  privacyRetention?: () => Promise<unknown>;
  /** The operations report; each crossed threshold is logged as an alert. */
  operations?: () => Promise<Record<string, unknown>>;
  /**
   * Sends crossed alerts to the operator's webhook, throttled in the
   * database. Absent when no webhook is configured.
   */
  notify?: (alerts: { alert: string; level: string }[]) => Promise<void>;
  now?: () => number;
  log?: (event: string, detail: Record<string, unknown>) => void;
}

const budgetMs = 40_000;
const batch = 50;
const discoveryBatch = 20;

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
        if (deps.billing.discoveries) {
          const found: Record<string, number> = {};
          const store = deps.billing.discoveries;
          for (const discovery of await store.due(discoveryBatch)) {
            if (now() - started > budgetMs) break;
            let outcome: DiscoveryOutcome;
            try {
              outcome = await runDiscovery(ctx, store, discovery);
            } catch {
              // Registered or not, it is retried from where it stopped.
              outcome = "retry";
            }
            found[outcome] = (found[outcome] ?? 0) + 1;
          }
          report.discoveries = found;
        }
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
      if (deps.aiRetention) {
        report.ai = { retention: await deps.aiRetention() };
      }
      if (deps.privacyRetention) {
        report.privacy = { retention: await deps.privacyRetention() };
      }
      if (deps.operations) {
        const operations = await deps.operations();
        report.operations = operations;
        const alerts = Array.isArray(operations.alerts)
          ? operations.alerts
          : [];
        const crossed = alerts.map((alert) => ({
          alert: String(
            (alert as Record<string, unknown>)?.alert ?? "unknown",
          ),
          level: String((alert as Record<string, unknown>)?.level ?? ""),
        }));
        // A log line per alert, for log drains and alerting rules.
        for (const alert of crossed) log("monetization_alert", alert);
        if (deps.notify && crossed.length > 0) {
          try {
            await deps.notify(crossed);
          } catch {
            // Delivery never fails the run; the log lines remain.
            log("monetization_alert_delivery_failed", {});
          }
        }
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

/**
 * The webhook body: a `text` line that Slack, Discord (as `content`) and most
 * chat or paging webhooks display, plus the structured alerts. Carries no
 * account, purchase or learner data.
 */
export function alertMessage(alerts: { alert: string; level: string }[]) {
  const pause = alerts.some((a) => a.level === "pause");
  const text = `${pause ? "PAUSE — " : ""}Czechify monetization alerts: ${
    alerts.map((a) => `${a.alert} (${a.level})`).join(", ")
  }. See docs/monetization/SUPPORT_AND_OPERATIONS.md.`;
  return { text, content: text, alerts };
}
