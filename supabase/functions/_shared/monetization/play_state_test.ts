import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { sha256Hex } from "./billing_crypto.ts";
import { normalizeSubscription, UnexpectedPlayResponse } from "./play_state.ts";

const verifiedAt = new Date("2026-09-22T10:00:00Z");
const response = (overrides: Record<string, unknown> = {}) => ({
  subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
  externalAccountIdentifiers: { obfuscatedExternalAccountId: "binding-a" },
  lineItems: [{
    productId: "czechify_core",
    expiryTime: "2026-10-22T10:00:00Z",
    autoRenewingPlan: { autoRenewEnabled: true },
    offerDetails: { basePlanId: "monthly" },
  }],
  ...overrides,
});
const normalize = (body: unknown, product = "czechify_core") =>
  normalizeSubscription(body, product, verifiedAt, JSON.stringify(body));

Deno.test("an active purchase keeps its line-item expiry and binding", async () => {
  const n = await normalize(response());
  assertEquals(n.state, "active");
  assertEquals(n.valid_until, "2026-10-22T10:00:00.000Z");
  assertEquals(n.verified_at, "2026-09-22T10:00:00.000Z");
  assertEquals(n.base_plan_id, "monthly");
  assertEquals(n.obfuscated_account_id, "binding-a");
  assertEquals(n.auto_renewing, true);
  assertEquals(n.acknowledged, false);
  assertEquals(n.linked_token_digest, null);
});

Deno.test("every Play state maps; abandoned pending grants nothing", async () => {
  const expected: Record<string, string> = {
    SUBSCRIPTION_STATE_PENDING: "pending",
    SUBSCRIPTION_STATE_ACTIVE: "active",
    SUBSCRIPTION_STATE_IN_GRACE_PERIOD: "in_grace_period",
    SUBSCRIPTION_STATE_CANCELED: "canceled",
    SUBSCRIPTION_STATE_ON_HOLD: "on_hold",
    SUBSCRIPTION_STATE_PAUSED: "paused",
    SUBSCRIPTION_STATE_EXPIRED: "expired",
    SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED: "expired",
  };
  for (const [raw, state] of Object.entries(expected)) {
    const n = await normalize(response({ subscriptionState: raw }));
    assertEquals([n.state, n.raw_state], [state, raw]);
  }
});

Deno.test("pending without expiry is allowed; other states need one", async () => {
  const noExpiry = [{ productId: "czechify_core" }];
  const pending = await normalize(
    response({
      subscriptionState: "SUBSCRIPTION_STATE_PENDING",
      lineItems: noExpiry,
    }),
  );
  assertEquals(pending.valid_until, verifiedAt.toISOString());
  await assertRejects(
    () => normalize(response({ lineItems: noExpiry })),
    UnexpectedPlayResponse,
  );
});

Deno.test("unknown states, foreign products and malformed bodies are refused", async () => {
  for (
    const body of [
      response({ subscriptionState: "SUBSCRIPTION_STATE_UNSPECIFIED" }),
      response({ subscriptionState: "SUBSCRIPTION_STATE_FUTURE" }),
      response({ lineItems: [] }),
      response({
        lineItems: [{ productId: "czechify_core", expiryTime: "soon" }],
      }),
      [],
      null,
    ]
  ) {
    await assertRejects(() => normalize(body), UnexpectedPlayResponse);
  }
  await assertRejects(
    () => normalize(response(), "czechify_ai"),
    UnexpectedPlayResponse,
  );
});

Deno.test("acknowledgement, missing binding and linked token are carried", async () => {
  const n = await normalize(response({
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    externalAccountIdentifiers: undefined,
    linkedPurchaseToken: "old-token",
  }));
  assertEquals(n.acknowledged, true);
  assertEquals(n.obfuscated_account_id, null);
  assertEquals(n.linked_token_digest, await sha256Hex("old-token"));
});
