import { assertEquals } from "jsr:@std/assert@1";
import { PlayApiError, type PlayClient } from "./play_client.ts";
import {
  backoffSeconds,
  type BillingStore,
  maxAttempts,
  runBillingJob,
} from "./purchase_jobs.ts";

const active = {
  subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  externalAccountIdentifiers: { obfuscatedExternalAccountId: "binding" },
  lineItems: [{
    productId: "czechify_core",
    expiryTime: "2026-10-22T10:00:00Z",
    offerDetails: { basePlanId: "monthly" },
  }],
};

function setup(options: {
  operation?: string;
  fence?: number | null;
  play?: Partial<PlayClient>;
  applied?: Record<string, unknown>;
} = {}) {
  const log: string[] = [];
  const store: BillingStore = {
    claim: () =>
      Promise.resolve(options.fence === undefined ? 1 : options.fence),
    jobPurchase: () =>
      Promise.resolve({
        operation: options.operation ?? "verify",
        product_id: "czechify_core",
        encrypted_token: "sealed",
      }),
    apply: (_job, _fence, _owner, result) => {
      log.push(`apply:${result.state}`);
      return Promise.resolve(
        options.applied ??
          {
            status: "provisioned",
            access: true,
            revision: 3,
            ack_job_id: "ack-1",
          },
      );
    },
    completeAcknowledgement: () => {
      log.push("complete-ack");
      return Promise.resolve(true);
    },
    fail: (_job, _fence, _owner, code, retry, dead) => {
      log.push(`fail:${code}:${retry}:${dead}`);
      return Promise.resolve(true);
    },
  };
  const play: PlayClient = {
    getSubscription: () =>
      Promise.resolve({ body: active, text: JSON.stringify(active) }),
    acknowledge: () => {
      log.push("play-ack");
      return Promise.resolve();
    },
    ...options.play,
  };
  return {
    log,
    ctx: {
      store,
      play,
      cipher: {
        encrypt: (t: string) => Promise.resolve(t),
        decrypt: (t: string) => Promise.resolve(`plain-${t}`),
      },
      owner: "test",
      now: () => new Date("2026-09-22T10:00:00Z"),
      random: () => 1,
    },
  };
}

Deno.test("verification applies Play's state and reports the acknowledgement job", async () => {
  const { ctx, log } = setup();
  assertEquals(await runBillingJob(ctx, "job"), {
    status: "provisioned",
    state: "active",
    access: true,
    revision: 3,
    ackJobId: "ack-1",
  });
  assertEquals(log, ["apply:active"]);
});

Deno.test("acknowledgement calls Play before completing the job", async () => {
  const { ctx, log } = setup({ operation: "acknowledge" });
  assertEquals(await runBillingJob(ctx, "job"), { status: "acknowledged" });
  assertEquals(log, ["play-ack", "complete-ack"]);
});

Deno.test("an unclaimed or stale job does nothing", async () => {
  const unclaimed = setup({ fence: null });
  assertEquals(await runBillingJob(unclaimed.ctx, "job"), {
    status: "not_claimed",
  });
  assertEquals(unclaimed.log, []);
  const stale = setup({ applied: { status: "stale_lease" } });
  assertEquals(await runBillingJob(stale.ctx, "job"), {
    status: "not_claimed",
  });
});

Deno.test("mismatches are reported, not retried", async () => {
  const { ctx } = setup({ applied: { status: "account_binding_mismatch" } });
  assertEquals(await runBillingJob(ctx, "job"), {
    status: "account_binding_mismatch",
  });
});

Deno.test("a binding mismatch carries its support case", async () => {
  const { ctx } = setup({
    applied: { status: "account_binding_mismatch", recovery_case_id: "case-1" },
  });
  assertEquals(await runBillingJob(ctx, "job"), {
    status: "account_binding_mismatch",
    recoveryCaseId: "case-1",
  });
});

Deno.test("Play outages back off; unreadable or unknown purchases end the job", async () => {
  const outage = setup({
    play: {
      getSubscription: () =>
        Promise.reject(new PlayApiError("play_verification_failed", true, 30)),
    },
  });
  assertEquals(await runBillingJob(outage.ctx, "job"), {
    status: "retry",
    code: "play_verification_failed",
  });
  assertEquals(outage.log, ["fail:play_verification_failed:30:false"]);

  const unknown = setup({
    play: {
      getSubscription: () =>
        Promise.resolve({ body: { subscriptionState: "X" }, text: "{}" }),
    },
  });
  assertEquals(await runBillingJob(unknown.ctx, "job"), {
    status: "dead",
    code: "unexpected_play_response",
  });
  assertEquals(unknown.log, ["fail:unexpected_play_response:5:true"]);

  const gone = setup({
    play: {
      getSubscription: () =>
        Promise.reject(new PlayApiError("purchase_not_found", false)),
    },
  });
  assertEquals(await runBillingJob(gone.ctx, "job"), {
    status: "dead",
    code: "purchase_not_found",
  });
});

Deno.test("a failed acknowledgement retries without touching access", async () => {
  const { ctx, log } = setup({
    operation: "acknowledge",
    play: {
      acknowledge: () =>
        Promise.reject(new PlayApiError("play_acknowledge_failed", true)),
    },
  });
  assertEquals(await runBillingJob(ctx, "job"), {
    status: "retry",
    code: "play_acknowledge_failed",
  });
  assertEquals(log, ["fail:play_acknowledge_failed:5:false"]);
});

Deno.test("backoff doubles from 5 s to an hour, with jitter and Retry-After", () => {
  assertEquals(backoffSeconds(1, null, () => 1), 5);
  assertEquals(backoffSeconds(3, null, () => 1), 20);
  assertEquals(backoffSeconds(3, null, () => 0), 10);
  assertEquals(backoffSeconds(40, null, () => 1), 3600);
  assertEquals(backoffSeconds(1, 90, () => 0), 90);
  assertEquals(backoffSeconds(1, 99999, () => 0), 3600);
});

Deno.test("a job stops retrying after the attempt cap", async () => {
  const failing = {
    getSubscription: () =>
      Promise.reject(new PlayApiError("play_verification_failed", true)),
  };
  const before = setup({ fence: maxAttempts - 1, play: failing });
  assertEquals((await runBillingJob(before.ctx, "job")).status, "retry");
  const last = setup({ fence: maxAttempts, play: failing });
  assertEquals(await runBillingJob(last.ctx, "job"), {
    status: "dead",
    code: "play_verification_failed",
  });
  assertEquals(last.log, ["fail:play_verification_failed:3600:true"]);
});
