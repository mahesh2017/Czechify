import { assertEquals } from "jsr:@std/assert@1";
import type { JobContext } from "../_shared/monetization/purchase_jobs.ts";
import { createHandler, type Dependencies } from "./handler.ts";

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
function setup(overrides: Partial<Dependencies> = {}) {
  const log: string[] = [];
  const handle = createHandler({
    secret,
    jobs: () => Promise.resolve(context(log)),
    enqueueReconciliation: (limit) => {
      log.push(`reconcile:${limit}`);
      return Promise.resolve(2);
    },
    dueJobs: () => Promise.resolve(["a", "b"]),
    health: () => Promise.resolve({ unacknowledged_over_1h: 0, dead_jobs: 0 }),
    log: (event) => log.push(event),
    ...overrides,
  });
  return { handle, log };
}
const call = (given: string | null = secret, method = "POST") =>
  new Request("https://example.com/functions/v1/monetization-worker", {
    method,
    headers: given === null ? {} : { "x-worker-secret": given },
  });

Deno.test("the worker queues reconciliation, then runs due jobs", async () => {
  const { handle, log } = setup();
  const response = await handle(call());
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    reconciliation: 2,
    outcomes: { acknowledged: 2 },
    health: { unacknowledged_over_1h: 0, dead_jobs: 0 },
  });
  assertEquals(log, [
    "reconcile:100",
    "claim:a",
    "play-ack",
    "claim:b",
    "play-ack",
  ]);
});

Deno.test("a wrong, missing or unconfigured secret runs nothing", async () => {
  const { handle, log } = setup();
  assertEquals((await handle(call("wrong"))).status, 401);
  assertEquals((await handle(call(null))).status, 401);
  assertEquals((await handle(call(secret, "GET"))).status, 405);
  const unconfigured = setup({ secret: "" });
  assertEquals((await unconfigured.handle(call(""))).status, 401);
  assertEquals((await unconfigured.handle(call("short"))).status, 401);
  assertEquals(log, []);
});

Deno.test("the time budget stops the batch; the rest stays due", async () => {
  let clock = 0;
  const { handle, log } = setup({
    now: () => (clock += 30_000),
  });
  const body = await (await handle(call())).json();
  assertEquals(body.outcomes, { acknowledged: 1 });
  assertEquals(log.filter((l) => l.startsWith("claim")), ["claim:a"]);
});

Deno.test("backlogs raise an attention log; failures answer 503", async () => {
  const { handle, log } = setup({
    health: () => Promise.resolve({ unacknowledged_over_1h: 1, dead_jobs: 0 }),
  });
  await handle(call());
  assertEquals(log.includes("billing_attention_required"), true);
  const broken = setup({ dueJobs: () => Promise.reject(new Error("db")) });
  assertEquals((await broken.handle(call())).status, 503);
});
