import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { compactVerify, exportJWK, generateKeyPair } from "npm:jose@6.2.12";
import {
  type BillingDependencies,
  createHandler,
  type Dependencies,
} from "./handler.ts";
import { PlayApiError } from "../_shared/monetization/play_client.ts";
import { createSnapshotSigner } from "./signing.ts";

const user = "00000000-0000-0000-0000-000000000001";
function setup(overrides: Partial<Dependencies> = {}) {
  const calls: string[] = [];
  return {
    calls,
    handle: createHandler({
      authenticate: (token) =>
        Promise.resolve(token === "valid" ? { id: user } : null),
      snapshot: (id) => {
        calls.push(id);
        return Promise.resolve({ user_id: id, schema_version: 1 });
      },
      sign: () => Promise.resolve("signed-document"),
      ...overrides,
    }),
  };
}
const req = (path = "entitlements", token = "valid", method = "GET") =>
  new Request(`https://example.com/functions/v1/monetization-api/${path}`, {
    method,
    headers: { authorization: `Bearer ${token}` },
  });

Deno.test("snapshot derives account from verified JWT and disables HTTP caching", async () => {
  const { handle, calls } = setup();
  const response = await handle(req());
  assertEquals(response.status, 200);
  assertEquals(calls, [user]);
  assertEquals((await response.json()).snapshot_jws, "signed-document");
  assertEquals(response.headers.get("Cache-Control"), "private, no-store");
});
Deno.test("invalid auth and supplied target account cannot fetch data", async () => {
  const { handle, calls } = setup();
  assertEquals((await handle(req("entitlements", "bad"))).status, 401);
  assertEquals((await handle(req(`entitlements?user_id=${user}`))).status, 400);
  assertEquals(
    (await handle(req("entitlements", "valid", "POST"))).status,
    405,
  );
  assertEquals(calls, []);
});
Deno.test("backend failure, wrong owner and missing signer fail closed", async () => {
  for (
    const deps of [
      {
        snapshot: () => Promise.reject(new Error("private database contents")),
      },
      {
        snapshot: () =>
          Promise.resolve({ user_id: "other", schema_version: 1 }),
      },
      { sign: () => Promise.reject(new Error("private key contents")) },
    ]
  ) {
    const response = await setup(deps).handle(req());
    assertEquals(response.status, 503);
    assertEquals((await response.json()).code, "verification_unavailable");
  }
});
Deno.test("configuration keeps all activation switches disabled", async () => {
  const response = await setup().handle(req("configuration"));
  const body = await response.json();
  assertEquals(body.course_paywall_enabled, false);
  assertEquals(body.play_checkout_enabled, false);
  assertEquals(body.referral_claims_enabled, false);
  assertEquals(body.paid_chat_required, false);
});
Deno.test("paid chat is required only where the proxy switch and the cohort agree", async () => {
  for (
    const [env, cohort, expected] of [
      [true, true, true],
      [true, false, false],
      [false, true, false],
    ] as const
  ) {
    const response = await setup({
      paidChatRequired: env,
      rollout: () => Promise.resolve({ paid_chat: cohort }),
    }).handle(req("configuration"));
    const body = await response.json();
    assertEquals(body.paid_chat_required, expected, `${env}/${cohort}`);
    assertEquals(body.ai_daily_turn_limit, 20);
  }
});
Deno.test("configuration turns on only what the account's cohort has", async () => {
  const on = {
    course_paywall: true,
    play_checkout: true,
    referral_claims: true,
    paid_chat: "yes",
  };
  const withBilling = setup({
    rollout: () => Promise.resolve(on),
    billing: () => Promise.reject(new Error("unused")),
  });
  const body = await (await withBilling.handle(req("configuration"))).json();
  assertEquals(
    [
      body.course_paywall_enabled,
      body.play_checkout_enabled,
      body.referral_claims_enabled,
    ],
    [true, true, true],
  );
  // Checkout needs billing configured on this server as well.
  const noBilling = setup({ rollout: () => Promise.resolve(on) });
  assertEquals(
    (await (await noBilling.handle(req("configuration"))).json())
      .play_checkout_enabled,
    false,
  );
  // A failed cohort lookup fails closed.
  const broken = setup({ rollout: () => Promise.reject(new Error("db")) });
  assertEquals((await broken.handle(req("configuration"))).status, 503);
});
Deno.test("Ed25519 compact JWS interoperates with JOSE verifier and rejects tampering", async () => {
  const { publicKey, privateKey } = await generateKeyPair("EdDSA", {
    extractable: true,
  });
  const sign = await createSnapshotSigner(
    await exportJWK(privateKey),
    "test-key",
  );
  const jws = await sign({ user_id: user, revision: 7 });
  const result = await compactVerify(jws, publicKey, { algorithms: ["EdDSA"] });
  assertEquals(result.protectedHeader.typ, "czechify-entitlements+jws");
  assertEquals(
    JSON.parse(new TextDecoder().decode(result.payload)).revision,
    7,
  );
  const pieces = jws.split(".");
  pieces[1] = btoa('{"revision":999}').replaceAll("=", "");
  await assertRejects(() => compactVerify(pieces.join("."), publicKey));
  await assertRejects(() =>
    createSnapshotSigner({ kty: "oct", k: "AAAA" }, "test")
  );
});

// Purchase routes. The database is faked here; its rules have their own
// pgTAP suite (billing_verification.test.sql).
const intentKey = "10000000-0000-4000-8000-000000000001";
const purchaseId = "20000000-0000-4000-8000-000000000002";
const activePlay = {
  subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  externalAccountIdentifiers: { obfuscatedExternalAccountId: "binding" },
  lineItems: [{
    productId: "czechify_core",
    expiryTime: "2099-01-01T00:00:00Z",
    offerDetails: { basePlanId: "monthly" },
  }],
};
function billingSetup(options: {
  anonymous?: boolean;
  registered?: Record<string, unknown>;
  intent?: Record<string, unknown>;
  playFails?: boolean;
  status?: Record<string, unknown> | null;
  checkout?: boolean;
} = {}) {
  const log: string[] = [];
  const billing: BillingDependencies = {
    obfuscatedAccountId: (id) =>
      Promise.resolve({ id: `hmac-${id}`, keyVersion: 1 }),
    bindAccount: (_id, candidate) => {
      log.push(`bind:${candidate}`);
      return Promise.resolve(candidate);
    },
    createIntent: (_id, product, _plan, key) => {
      log.push(`intent:${product}:${key}`);
      return Promise.resolve(
        options.intent ??
          {
            status: "created",
            intent_id: "i",
            obfuscated_account_id: "binding",
          },
      );
    },
    register: (id, digest, encrypted, product) => {
      log.push(`register:${id}:${digest.length}:${encrypted}:${product}`);
      return Promise.resolve(
        options.registered ??
          { status: "queued", purchase_id: purchaseId, job_id: "verify-job" },
      );
    },
    status: (id) =>
      Promise.resolve(
        options.status === undefined
          ? (id === user ? { state: "active" } : null)
          : options.status,
      ),
    jobs: {
      owner: "test",
      cipher: {
        encrypt: () => Promise.resolve("sealed"),
        decrypt: () => Promise.resolve("token"),
      },
      play: {
        getSubscription: () =>
          options.playFails
            ? Promise.reject(new PlayApiError("play_verification_failed", true))
            : Promise.resolve({ body: activePlay, text: "{}" }),
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
            revision: 4,
            ack_job_id: "ack-job",
          }),
        completeAcknowledgement: () => Promise.resolve(true),
        fail: () => Promise.resolve(true),
      },
    },
  };
  return {
    log,
    handle: createHandler({
      authenticate: (token) =>
        Promise.resolve(
          token === "valid"
            ? { id: user, anonymous: options.anonymous ?? false }
            : null,
        ),
      snapshot: () => Promise.resolve(null),
      sign: () => Promise.resolve(""),
      billing: () => Promise.resolve(billing),
      rollout: () =>
        Promise.resolve({ play_checkout: options.checkout ?? true }),
    }),
  };
}
const post = (
  path: string,
  body: unknown,
  headers: Record<string, string> = {},
) =>
  new Request(`https://example.com/functions/v1/monetization-api/${path}`, {
    method: "POST",
    headers: { authorization: "Bearer valid", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
const verifyBody = {
  purchase_token: "play-token",
  product_id: "czechify_core",
  source: "purchase",
};

Deno.test("purchase routes are off without billing secrets and refuse anonymous accounts", async () => {
  const off = setup();
  assertEquals(
    (await off.handle(post("purchases/verify", verifyBody))).status,
    503,
  );
  const { handle, log } = billingSetup({ anonymous: true });
  const response = await handle(post("purchases/verify", verifyBody));
  assertEquals(response.status, 403);
  assertEquals((await response.json()).code, "linked_account_required");
  assertEquals(log, []);
});

Deno.test("purchase intent binds the account and requires an idempotency key", async () => {
  const { handle, log } = billingSetup();
  const body = {
    product_id: "czechify_core",
    base_plan_id: "monthly",
    platform: "android",
  };
  assertEquals((await handle(post("purchase-intents", body))).status, 400);
  assertEquals(
    (await handle(
      post("purchase-intents", { ...body, user_id: "x" }, {
        "Idempotency-Key": intentKey,
      }),
    )).status,
    400,
  );
  assertEquals(
    (await handle(
      post("purchase-intents", { ...body, platform: "ios" }, {
        "Idempotency-Key": intentKey,
      }),
    )).status,
    400,
  );
  const created = await handle(
    post("purchase-intents", body, { "Idempotency-Key": intentKey }),
  );
  assertEquals(created.status, 201);
  assertEquals((await created.json()).obfuscated_account_id, "binding");
  assertEquals(log, [`bind:hmac-${user}`, `intent:czechify_core:${intentKey}`]);
});

Deno.test("intent refusals map to stable errors", async () => {
  const body = {
    product_id: "czechify_core",
    base_plan_id: "monthly",
    platform: "android",
  };
  for (
    const [status, code] of [
      ["product_unavailable", 422],
      ["rate_limited", 429],
      ["idempotency_conflict", 409],
    ] as const
  ) {
    const { handle } = billingSetup({ intent: { status } });
    assertEquals(
      (await handle(
        post("purchase-intents", body, { "Idempotency-Key": intentKey }),
      )).status,
      code,
    );
  }
});

Deno.test("verification provisions, then acknowledges, and never echoes the token", async () => {
  const { handle, log } = billingSetup();
  const response = await handle(post("purchases/verify", verifyBody));
  const text = await response.text();
  assertEquals(response.status, 200);
  assertEquals(JSON.parse(text).status, "provisioned");
  assertEquals(JSON.parse(text).access, true);
  assertEquals(text.includes("play-token"), false);
  assertEquals(log, [
    `register:${user}:64:sealed:czechify_core`,
    "claim:verify-job",
    "claim:ack-job",
    "play-ack",
  ]);
});

Deno.test("a Play outage returns 202 with the verification ID to poll", async () => {
  const { handle } = billingSetup({ playFails: true });
  const response = await handle(post("purchases/verify", verifyBody));
  assertEquals(response.status, 202);
  const body = await response.json();
  assertEquals([body.status, body.verification_id], [
    "verification_pending",
    purchaseId,
  ]);
});

Deno.test("a token owned by another account is refused without detail", async () => {
  const { handle, log } = billingSetup({
    registered: { status: "account_binding_mismatch" },
  });
  const response = await handle(post("purchases/verify", verifyBody));
  assertEquals(response.status, 403);
  assertEquals(Object.keys(await response.json()).sort(), [
    "code",
    "policy_version",
    "request_id",
    "server_time",
  ]);
  assertEquals(log.some((l) => l.startsWith("claim")), false);
});

Deno.test("a restore of another account's purchase returns only a support reference", async () => {
  const caseId = "0b6f2c1e-4d3a-4f5b-9c8d-7e6f5a4b3c2d";
  const { handle } = billingSetup({
    registered: {
      status: "account_binding_mismatch",
      recovery_case_id: caseId,
    },
  });
  const response = await handle(post("purchases/verify", verifyBody));
  assertEquals(response.status, 403);
  const body = await response.json();
  assertEquals([body.code, body.recovery_case_id], [
    "account_binding_mismatch",
    caseId,
  ]);
  const odd = billingSetup({
    registered: {
      status: "account_binding_mismatch",
      recovery_case_id: "not-a-uuid",
    },
  });
  const plain = await (await odd.handle(post("purchases/verify", verifyBody)))
    .json();
  assertEquals("recovery_case_id" in plain, false);
});

Deno.test("verify rejects unknown fields, oversized tokens and bad sources", async () => {
  const { handle, log } = billingSetup();
  for (
    const body of [
      { ...verifyBody, user_id: user },
      { ...verifyBody, source: "gift" },
      { ...verifyBody, purchase_token: "x".repeat(16 * 1024 + 1) },
      { ...verifyBody, intent_id: "not-a-uuid" },
      { ...verifyBody, product_id: "Core Product" },
      "not json",
      "x".repeat(25 * 1024),
    ]
  ) {
    assertEquals((await handle(post("purchases/verify", body))).status, 400);
  }
  assertEquals(log, []);
});

Deno.test("purchase status is owner-scoped and path-validated", async () => {
  const own = billingSetup();
  assertEquals(
    (await own.handle(req(`purchases/status/${purchaseId}`))).status,
    200,
  );
  assertEquals(
    (await own.handle(req("purchases/status/not-a-uuid"))).status,
    404,
  );
  const other = billingSetup({ status: null });
  assertEquals(
    (await other.handle(req(`purchases/status/${purchaseId}`))).status,
    404,
  );
  assertEquals((await own.handle(req("purchases/verify"))).status, 405);
});

Deno.test("new purchases need the cohort; restores never do", async () => {
  const { handle, log } = billingSetup({ checkout: false });
  const intent = await handle(
    post("purchase-intents", {
      product_id: "czechify_core",
      base_plan_id: "monthly",
      platform: "android",
    }, { "Idempotency-Key": crypto.randomUUID() }),
  );
  assertEquals(intent.status, 422);
  assertEquals((await intent.json()).code, "product_unavailable");
  assertEquals(log.some((l) => l.startsWith("intent")), false);
  const restore = await handle(post("purchases/verify", verifyBody));
  assertEquals(restore.status, 200);
});
