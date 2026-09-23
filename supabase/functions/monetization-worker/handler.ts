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
    const failed: string[] = [];
    // Every stage runs even when an earlier one failed: a billing outage must
    // not also stop referral processing, retention, or the alerts that would
    // report it.
    const stage = async (name: string, work: () => Promise<void>) => {
      try {
        await work();
      } catch {
        failed.push(name);
        log("monetization_worker_stage_failed", { stage: name });
      }
    };
    const billing = deps.billing;
    const shared: { ctx?: JobContext } = {};
    if (billing) {
      await stage("billing", async () => {
        const ctx = shared.ctx = await billing.jobs();
        report.reconciliation = await billing.enqueueReconciliation(100);
        const outcomes: Record<string, number> = {};
        for (const job of await billing.dueJobs(batch)) {
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
        const health = await billing.health();
        report.health = health;
        if (health.unacknowledged_over_1h > 0 || health.dead_jobs > 0) {
          log("billing_attention_required", health);
        }
      });
      const store = billing.discoveries;
      if (store) {
        await stage("discoveries", async () => {
          const ctx = shared.ctx ?? await billing.jobs();
          const found: Record<string, number> = {};
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
        });
      }
    }
    const referrals = deps.referrals;
    if (referrals) {
      await stage("referrals", async () => {
        let processed = 0;
        let failures = 0;
        for (const claim of await referrals.claimsToProcess(batch)) {
          if (now() - started > budgetMs) break;
          try {
            await referrals.processClaim(claim);
            processed++;
          } catch {
            // Processing is idempotent; the claim is selected again next run.
            failures++;
          }
        }
        report.referrals = {
          processed,
          failed: failures,
          retention: await referrals.cleanup(),
        };
        if (failures > 0) {
          log("referral_processing_failed", { failed: failures });
        }
      });
    }
    const aiRetention = deps.aiRetention;
    if (aiRetention) {
      await stage("ai_retention", async () => {
        report.ai = { retention: await aiRetention() };
      });
    }
    const privacyRetention = deps.privacyRetention;
    if (privacyRetention) {
      await stage("privacy_retention", async () => {
        report.privacy = { retention: await privacyRetention() };
      });
    }
    const alerts: { alert: string; level: string }[] = [];
    const operations = deps.operations;
    if (operations) {
      await stage("operations", async () => {
        const result = await operations();
        report.operations = result;
        for (const alert of Array.isArray(result.alerts) ? result.alerts : []) {
          alerts.push({
            alert: String(
              (alert as Record<string, unknown>)?.alert ?? "unknown",
            ),
            level: String((alert as Record<string, unknown>)?.level ?? ""),
          });
        }
      });
    }
    // A stage that failed is an alert of its own, so the webhook hears of a
    // billing outage even though billing's own numbers could not be read.
    for (const name of failed) {
      alerts.push({ alert: `worker_${name}_failed`, level: "investigate" });
    }
    // A log line per alert, for log drains and alerting rules.
    for (const alert of alerts) log("monetization_alert", alert);
    if (deps.notify && alerts.length > 0) {
      try {
        await deps.notify(alerts);
      } catch {
        // Delivery never fails the run; the log lines remain.
        log("monetization_alert_delivery_failed", {});
      }
    }
    if (failed.length > 0) {
      report.failed = failed;
      return Response.json(report, { status: 503 });
    }
    return Response.json(report);
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
