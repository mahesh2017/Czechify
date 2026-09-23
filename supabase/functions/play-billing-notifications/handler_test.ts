import { assertEquals } from "jsr:@std/assert@1";
import { sha256Hex } from "../_shared/monetization/billing_crypto.ts";
import { createHandler, type Dependencies } from "./handler.ts";

const pkg = "com.czechify.app";
function setup(overrides: Partial<Dependencies> = {}) {
  const recorded: unknown[][] = [];
  const logged: string[] = [];
  const handle = createHandler({
    authenticate: (auth) => Promise.resolve(auth === "Bearer google"),
    packageName: pkg,
    record: (...args) => {
      recorded.push(args);
      return Promise.resolve("queued");
    },
    log: (event) => logged.push(event),
    ...overrides,
  });
  return { handle, recorded, logged };
}
const request = (data: unknown, auth = "Bearer google", method = "POST") =>
  new Request("https://example.com/functions/v1/play-billing-notifications", {
    method,
    headers: { Authorization: auth },
    body: method === "POST"
      ? JSON.stringify({
        subscription: "projects/p/subscriptions/play",
        message: { data: btoa(JSON.stringify(data)), messageId: "m-1" },
      })
      : undefined,
  });
const renewal = {
  packageName: pkg,
  subscriptionNotification: {
    notificationType: 2,
    purchaseToken: "secret-token",
  },
};

Deno.test("an authenticated notification is stored by token digest, then acknowledged", async () => {
  const { handle, recorded } = setup();
  const response = await handle(request(renewal));
  assertEquals(response.status, 204);
  assertEquals(recorded, [[
    "projects/p/subscriptions/play",
    "m-1",
    "subscription",
    2,
    await sha256Hex("secret-token"),
    null,
  ]]);
  assertEquals(JSON.stringify(recorded).includes("secret-token"), false);
});

Deno.test("unauthenticated pushes are refused before reading anything", async () => {
  const { handle, recorded, logged } = setup();
  assertEquals((await handle(request(renewal, "Bearer forged"))).status, 401);
  assertEquals(recorded, []);
  assertEquals(logged, ["play_notification_auth_failed"]);
  assertEquals(
    (await handle(request(renewal, "Bearer google", "GET"))).status,
    405,
  );
});

Deno.test("a storage failure is not acknowledged, so Pub/Sub redelivers", async () => {
  const { handle } = setup({
    record: () => Promise.reject(new Error("db down")),
  });
  assertEquals((await handle(request(renewal))).status, 500);
});

Deno.test("unusable messages are acknowledged without storing a token", async () => {
  const { handle, recorded, logged } = setup();
  const other = { ...renewal, packageName: "com.other.app" };
  assertEquals((await handle(request(other))).status, 204);
  assertEquals(recorded, []);
  assertEquals(logged, ["play_notification_unusable"]);
});

Deno.test("duplicates and unmatched tokens are still acknowledged", async () => {
  for (const outcome of ["duplicate", "unmatched", "ignored"]) {
    const { handle, logged } = setup({
      record: () => Promise.resolve(outcome),
    });
    assertEquals((await handle(request(renewal))).status, 204);
    assertEquals(
      logged.includes("play_notification_unmatched"),
      outcome === "unmatched",
    );
  }
});

const purchased = {
  packageName: pkg,
  subscriptionNotification: {
    notificationType: 4,
    purchaseToken: "secret-token",
    subscriptionId: "czechify_core",
  },
};

Deno.test("an unknown subscription token is handed on so the worker can find its buyer", async () => {
  const found: unknown[][] = [];
  for (const outcome of ["unmatched", "duplicate"]) {
    const { handle } = setup({
      record: () => Promise.resolve(outcome),
      discover: (...args) => {
        found.push(args);
        return Promise.resolve("queued");
      },
    });
    assertEquals((await handle(request(purchased))).status, 204);
  }
  const digest = await sha256Hex("secret-token");
  assertEquals(found, [
    [digest, "secret-token", "czechify_core"],
    [digest, "secret-token", "czechify_core"],
  ]);
});

Deno.test("a known purchase, a voided one or one without a product is not handed on", async () => {
  const found: unknown[] = [];
  const discover = () => {
    found.push(1);
    return Promise.resolve("queued");
  };
  const known = setup({ discover });
  assertEquals((await known.handle(request(purchased))).status, 204);
  const unmatched = setup({
    record: () => Promise.resolve("unmatched"),
    discover,
  });
  await unmatched.handle(request(renewal));
  await unmatched.handle(request({
    packageName: pkg,
    voidedPurchaseNotification: { purchaseToken: "v", productType: 1 },
  }));
  assertEquals(found, []);
});

Deno.test("a failed discovery is not acknowledged, so Pub/Sub redelivers", async () => {
  const { handle, logged } = setup({
    record: () => Promise.resolve("unmatched"),
    discover: () => Promise.reject(new Error("db down")),
  });
  assertEquals((await handle(request(purchased))).status, 500);
  assertEquals(logged.includes("play_notification_discovery_failed"), true);
});
