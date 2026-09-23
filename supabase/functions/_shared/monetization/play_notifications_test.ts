import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  createLocalJWKSet,
  exportJWK,
  generateKeyPair,
  type JWTPayload,
  SignJWT,
} from "npm:jose@6.2.12";
import {
  parsePushBody,
  UnusableNotification,
  verifyPushToken,
} from "./play_notifications.ts";

const expected = {
  audience:
    "https://example.supabase.co/functions/v1/play-billing-notifications",
  email: "play-push@example.iam.gserviceaccount.com",
};

async function keys() {
  const google = await generateKeyPair("RS256", { extractable: true });
  const attacker = await generateKeyPair("RS256", { extractable: true });
  const jwk = { ...await exportJWK(google.publicKey), kid: "g1", alg: "RS256" };
  const jwks = createLocalJWKSet({ keys: [jwk] });
  const sign = (claims: JWTPayload, key = google.privateKey) =>
    new SignJWT(claims)
      .setProtectedHeader({ alg: "RS256", kid: "g1" })
      .setIssuedAt()
      .setExpirationTime("5m")
      .sign(key);
  return { jwks, sign, attacker };
}
const good = {
  iss: "https://accounts.google.com",
  aud: expected.audience,
  email: expected.email,
  email_verified: true,
};

Deno.test("only Google's push token for this audience and account is accepted", async () => {
  const { jwks, sign, attacker } = await keys();
  const check = async (token: string) =>
    await verifyPushToken(`Bearer ${token}`, expected, jwks);
  assertEquals(await check(await sign(good)), true);
  assertEquals(
    await check(await sign({ ...good, iss: "accounts.google.com" })),
    true,
  );
  for (
    const claims of [
      { ...good, iss: "https://evil.example.com" },
      { ...good, aud: "https://other.example.com" },
      { ...good, email: "someone@example.com" },
      { ...good, email_verified: false },
      { ...good, email_verified: "true" },
    ]
  ) {
    assertEquals(await check(await sign(claims)), false);
  }
  assertEquals(await check(await sign(good, attacker.privateKey)), false);
  assertEquals(await verifyPushToken(null, expected, jwks), false);
  assertEquals(await verifyPushToken("Basic abc", expected, jwks), false);
});

const push = (data: unknown, overrides: Record<string, unknown> = {}) => ({
  subscription: "projects/p/subscriptions/play",
  message: {
    data: btoa(JSON.stringify(data)),
    messageId: "m-1",
    ...overrides,
  },
});
const pkg = "com.czechify.app";

Deno.test("subscription and voided notifications carry their token", () => {
  const sub = parsePushBody(
    push({
      packageName: pkg,
      eventTimeMillis: "1790000000000",
      subscriptionNotification: { notificationType: 2, purchaseToken: "t" },
    }),
    pkg,
  );
  assertEquals(sub, {
    subscription: "projects/p/subscriptions/play",
    messageId: "m-1",
    eventTime: new Date(1790000000000).toISOString(),
    kind: "subscription",
    type: 2,
    purchaseToken: "t",
  });
  const voided = parsePushBody(
    push({
      packageName: pkg,
      voidedPurchaseNotification: { purchaseToken: "v", productType: 1 },
    }),
    pkg,
  );
  assertEquals([voided.kind, voided.purchaseToken], ["voided", "v"]);
});

Deno.test("test, one-time and unknown notifications carry no token", () => {
  for (
    const [data, kind] of [
      [{ packageName: pkg, testNotification: { version: "1.0" } }, "test"],
      [{
        packageName: pkg,
        voidedPurchaseNotification: { purchaseToken: "v", productType: 2 },
      }, "other"],
      [{ packageName: pkg, oneTimeProductNotification: {} }, "other"],
    ] as const
  ) {
    const parsed = parsePushBody(push(data), pkg);
    assertEquals([parsed.kind, parsed.purchaseToken], [kind, null]);
  }
});

Deno.test("another app's or a malformed message is unusable", () => {
  const sub = {
    subscriptionNotification: { notificationType: 2, purchaseToken: "t" },
  };
  for (
    const body of [
      push({ ...sub, packageName: "com.other.app" }),
      push({
        packageName: pkg,
        subscriptionNotification: { notificationType: 2 },
      }),
      push(sub, { messageId: undefined }),
      { message: { data: "!!!", messageId: "m" }, subscription: "s" },
      { subscription: "s" },
      null,
    ]
  ) {
    assertThrows(() => parsePushBody(body, pkg), UnusableNotification);
  }
});
