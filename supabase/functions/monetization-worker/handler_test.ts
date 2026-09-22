import { assertEquals } from "jsr:@std/assert@1";
import type { JobContext } from "../_shared/monetization/purchase_jobs.ts";
import {
  type BillingWork,
  createHandler,
  type Dependencies,
  type ReferralWork,
} from "./handler.ts";

const secret = "s".repeat(40);
function context(log: string[]): JobContext {
  return {
    owner: "worker",
    cipher: {
      encrypt: (t) => Promise.resolve(t),
      decrypt: (t) => Promise.resolve(t),
    },
    play: {
      getSubscription: () => Promise.reject(new Error("unused")),
      acknowledge: () => {
        log.push("play-ack");
        return Promise.resolve();
      },
    },
    store: {
      claim: (job) => {
        log.push(`claim:${job}`);
        return Promise.resolve(1);
      },
      jobPurchase: () =>
        Promise.resolve({
          operation: "acknowledge",
          product_id: "czechify_core",
          encrypted_token: "t",
        }),
      apply: () => Promise.resolve({}),
      completeAcknowledgement: () => Promise.resolve(true),
      fail: () => Promise.resolve(true),
    },
  };
}
function billing(log: string[], overrides: Partial<BillingWork> = {}) {
  return {
    jobs: () => Promise.resolve(context(log)),
    enqueueReconciliation: (limit: number) => {
      log.push(`reconcile:${limit}`);
      return Promise.resolve(2);
    },
    dueJobs: () => Promise.resolve(["a", "b"]),
    health: () => Promise.resolve({ unacknowledged_over_1h: 0, dead_jobs: 0 }),
    ...overrides,
  };
}
function referrals(log: string[], overrides: Partial<ReferralWork> = {}) {
  return {
    claimsToProcess: () => Promise.resolve(["c1", "c2"]),
    processClaim: (claim: string) => {
      log.push(`process:${claim}`);
      return Promise.resolve({});
    },
    cleanup: () => {
      log.push("cleanup");
      return Promise.resolve({ claim_attempts: 3, challenges: 1 });
    },
    ...overrides,
  };
}
function setup(
  overrides: (log: string[]) => Partial<Dependencies> = () => ({}),
) {
  const log: string[] = [];
  const handle = createHandler({
    secret,
    billing: billing(log),
    referrals: referrals(log),
    log: (event) => log.push(event),
    ...overrides(log),
  });
  return { handle, log };
}
const call = (given: string | null = secret, method = "POST") =>
  new Request("https://example.com/functions/v1/monetization-worker", {
    method,
    headers: given === null ? {} : { "x-worker-secret": given },
  });

Deno.test("the worker runs billing, then held referral claims, then retention", async () => {
  const { handle, log } = setup();
  const response = await handle(call());
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    reconciliation: 2,
    outcomes: { acknowledged: 2 },
    health: { unacknowledged_over_1h: 0, dead_jobs: 0 },
    referrals: {
      processed: 2,
      failed: 0,
      retention: { claim_attempts: 3, challenges: 1 },
    },
  });
  assertEquals(log, [
    "reconcile:100",
    "claim:a",
    "play-ack",
    "claim:b",
    "play-ack",
    "process:c1",
    "process:c2",
    "cleanup",
  ]);
});

Deno.test("referral work runs without billing secrets", async () => {
  const { handle, log } = setup(() => ({ billing: undefined }));
  const body = await (await handle(call())).json();
  assertEquals(body.referrals.processed, 2);
  assertEquals(log.some((l) => l.startsWith("reconcile")), false);
});

Deno.test("a failing claim is counted and retried next run", async () => {
  const { handle, log } = setup((log) => ({
    referrals: referrals(log, {
      processClaim: (claim) =>
        claim === "c1" ? Promise.reject(new Error("db")) : Promise.resolve({}),
    }),
  }));
  const body = await (await handle(call())).json();
  assertEquals(body.referrals.processed, 1);
  assertEquals(body.referrals.failed, 1);
  assertEquals(log.includes("referral_processing_failed"), true);
});

Deno.test("a wrong, missing or unconfigured secret runs nothing", async () => {
  const { handle, log } = setup();
  assertEquals((await handle(call("wrong"))).status, 401);
  assertEquals((await handle(call(null))).status, 401);
  assertEquals((await handle(call(secret, "GET"))).status, 405);
  const unconfigured = setup(() => ({ secret: "" }));
  assertEquals((await unconfigured.handle(call(""))).status, 401);
  assertEquals((await unconfigured.handle(call("short"))).status, 401);
  assertEquals(log, []);
  assertEquals(unconfigured.log, []);
});

Deno.test("the time budget stops the batch; the rest stays due", async () => {
  let clock = 0;
  const { handle, log } = setup(() => ({ now: () => (clock += 30_000) }));
  const body = await (await handle(call())).json();
  assertEquals(body.outcomes, { acknowledged: 1 });
  assertEquals(log.filter((l) => l.startsWith("claim")), ["claim:a"]);
  assertEquals(log.filter((l) => l.startsWith("process")), []);
});

Deno.test("backlogs raise an attention log; failures answer 503", async () => {
  const { handle, log } = setup((log) => ({
    billing: billing(log, {
      health: () =>
        Promise.resolve({ unacknowledged_over_1h: 1, dead_jobs: 0 }),
    }),
  }));
  await handle(call());
  assertEquals(log.includes("billing_attention_required"), true);
  const broken = setup((log) => ({
    billing: billing(log, { dueJobs: () => Promise.reject(new Error("db")) }),
  }));
  assertEquals((await broken.handle(call())).status, 503);
});

Deno.test("AI retention runs after referrals and is reported", async () => {
  const { handle, log } = setup((log) => ({
    aiRetention: () => {
      log.push("ai-retention");
      return Promise.resolve({ replay_cleared: 4, tombstones_removed: 1 });
    },
  }));
  const body = await (await handle(call())).json();
  assertEquals(body.ai, {
    retention: { replay_cleared: 4, tombstones_removed: 1 },
  });
  assertEquals(log.at(-1), "ai-retention");
});

Deno.test("privacy retention runs last and is reported", async () => {
  const { handle, log } = setup((log) => ({
    aiRetention: () => {
      log.push("ai-retention");
      return Promise.resolve({});
    },
    privacyRetention: () => {
      log.push("privacy-retention");
      return Promise.resolve({ ownerless_purchases: 1, referral_receipts: 8 });
    },
  }));
  const body = await (await handle(call())).json();
  assertEquals(body.privacy, {
    retention: { ownerless_purchases: 1, referral_receipts: 8 },
  });
  assertEquals(log.slice(-2), ["ai-retention", "privacy-retention"]);
});

Deno.test("each crossed threshold is logged as an alert", async () => {
  const events: [string, Record<string, unknown>][] = [];
  const { handle } = setup(() => ({
    operations: () =>
      Promise.resolve({
        verify_p95_seconds: 42,
        alerts: [
          { alert: "verification_slow", level: "investigate" },
          { alert: "acknowledged_without_access", level: "pause" },
        ],
      }),
    log: (event: string, detail: Record<string, unknown>) =>
      events.push([event, detail]),
  }));
  const body = await (await handle(call())).json();
  assertEquals(body.operations.verify_p95_seconds, 42);
  assertEquals(events.filter(([e]) => e === "monetization_alert"), [
    ["monetization_alert", {
      alert: "verification_slow",
      level: "investigate",
    }],
    ["monetization_alert", {
      alert: "acknowledged_without_access",
      level: "pause",
    }],
  ]);
});

Deno.test("a quiet report logs nothing", async () => {
  const events: string[] = [];
  const { handle } = setup(() => ({
    operations: () => Promise.resolve({ alerts: "none" }),
    log: (event: string) => events.push(event),
  }));
  assertEquals((await handle(call())).status, 200);
  assertEquals(events.includes("monetization_alert"), false);
});
