import { assertEquals } from "jsr:@std/assert@1";
import { PlayApiError, type PlayClient } from "./play_client.ts";
import {
  type Discovery,
  type DiscoveryStore,
  maxDiscoveryAttempts,
  runDiscovery,
} from "./play_discovery.ts";
import type { BillingStore, JobContext } from "./purchase_jobs.ts";

const bought = {
  subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  externalAccountIdentifiers: { obfuscatedExternalAccountId: "buyer-binding" },
  lineItems: [{
    productId: "czechify_core",
    expiryTime: "2026-10-22T10:00:00Z",
    offerDetails: { basePlanId: "monthly" },
  }],
};
const discovery: Discovery = {
  token_digest: "d".repeat(64),
  encrypted_token: "sealed",
  product_id: "czechify_core",
  attempts: 0,
};

function setup(options: {
  play?: Partial<PlayClient>;
  resolved?: Record<string, unknown>;
  body?: unknown;
} = {}) {
  const log: string[] = [];
  const store: DiscoveryStore = {
    due: () => Promise.resolve([discovery]),
    resolve: (digest, obfuscated) => {
      log.push(`resolve:${digest.slice(0, 2)}:${obfuscated}`);
      return Promise.resolve(
        options.resolved ??
          { status: "queued", purchase_id: "p", job_id: "verify-job" },
      );
    },
    fail: (_digest, retry, final) => {
      log.push(`fail:${retry}:${final}`);
      return Promise.resolve(true);
    },
  };
  const jobs: BillingStore = {
    claim: (job) => {
      log.push(`claim:${job}`);
      return Promise.resolve(1);
    },
    jobPurchase: (job) =>
      Promise.resolve({
        operation: job === "ack-job" ? "acknowledge" : "verify",
        product_id: "czechify_core",
        encrypted_token: "sealed",
      }),
    apply: () =>
      Promise.resolve({
        status: "provisioned",
        access: true,
        revision: 2,
        ack_job_id: "ack-job",
        owner_id: "buyer",
      }),
    completeAcknowledgement: () => Promise.resolve(true),
    fail: () => Promise.resolve(true),
  };
  const body = options.body ?? bought;
  const ctx: JobContext = {
    store: jobs,
    owner: "worker",
    cipher: {
      encrypt: (t) => Promise.resolve(t),
      decrypt: (t) => Promise.resolve(`plain-${t}`),
    },
    play: {
      getSubscription: (_product, token) => {
        log.push(`play:${token}`);
        return Promise.resolve({ body, text: JSON.stringify(body) });
      },
      acknowledge: () => {
        log.push("play-ack");
        return Promise.resolve();
      },
      ...options.play,
    },
    now: () => new Date("2026-09-23T10:00:00Z"),
    random: () => 1,
  };
  return { ctx, store, log };
}

Deno.test("the buyer Play names gets the purchase, verified and acknowledged", async () => {
  const { ctx, store, log } = setup();
  assertEquals(await runDiscovery(ctx, store, discovery), "provisioned");
  assertEquals(log, [
    "play:plain-sealed",
    "resolve:dd:buyer-binding",
    "claim:verify-job",
    "play:plain-sealed",
    "claim:ack-job",
    "play-ack",
  ]);
});

Deno.test("a purchase that names no Czechify account is left alone", async () => {
  const { ctx, store, log } = setup({ resolved: { status: "no_owner" } });
  assertEquals(await runDiscovery(ctx, store, discovery), "no_owner");
  assertEquals(log.some((l) => l.startsWith("claim")), false);
  const unnamed = setup({
    body: { ...bought, externalAccountIdentifiers: undefined },
    resolved: { status: "no_owner" },
  });
  assertEquals(
    await runDiscovery(unnamed.ctx, unnamed.store, discovery),
    "no_owner",
  );
  assertEquals(unnamed.log.includes("resolve:dd:null"), true);
});

Deno.test("a registration without a job to run counts as registered", async () => {
  const { ctx, store } = setup({
    resolved: { status: "account_binding_mismatch" },
  });
  assertEquals(await runDiscovery(ctx, store, discovery), "registered");
});

Deno.test("a Play outage backs off; an unknown token or answer gives up", async () => {
  const outage = setup({
    play: {
      getSubscription: () =>
        Promise.reject(new PlayApiError("play_verification_failed", true, 30)),
    },
  });
  assertEquals(
    await runDiscovery(outage.ctx, outage.store, discovery),
    "retry",
  );
  assertEquals(outage.log, ["fail:30:false"]);

  const gone = setup({
    play: {
      getSubscription: () =>
        Promise.reject(new PlayApiError("purchase_not_found", false)),
    },
  });
  assertEquals(await runDiscovery(gone.ctx, gone.store, discovery), "failed");
  assertEquals(gone.log, ["fail:5:true"]);

  const odd = setup({ body: { subscriptionState: "SOMETHING_NEW" } });
  assertEquals(await runDiscovery(odd.ctx, odd.store, discovery), "failed");
});

Deno.test("a discovery stops after the attempt cap", async () => {
  const { ctx, store, log } = setup({
    play: {
      getSubscription: () =>
        Promise.reject(new PlayApiError("play_verification_failed", true)),
    },
  });
  assertEquals(
    await runDiscovery(ctx, store, {
      ...discovery,
      attempts: maxDiscoveryAttempts - 1,
    }),
    "failed",
  );
  assertEquals(log[0].endsWith(":true"), true);
});

Deno.test("a failed database write still reports the outcome", async () => {
  const { ctx, store } = setup({
    play: {
      getSubscription: () =>
        Promise.reject(new PlayApiError("play_verification_failed", true)),
    },
  });
  store.fail = () => Promise.reject(new Error("db down"));
  assertEquals(await runDiscovery(ctx, store, discovery), "retry");
});
