import {
  assert,
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert@1";
import { exportPKCS8, generateKeyPair } from "npm:jose@6.2.12";
import {
  createPlayClient,
  parseServiceAccount,
  PlayApiError,
} from "./play_client.ts";

async function setup(responses: Response[]) {
  const { privateKey } = await generateKeyPair("RS256", { extractable: true });
  const calls: Request[] = [];
  const client = createPlayClient({
    packageName: "com.czechify.app",
    account: {
      client_email: "billing@example.iam.gserviceaccount.com",
      private_key: await exportPKCS8(privateKey),
      token_uri: "https://oauth2.example.com/token",
    },
    fetch: (input, init) => {
      calls.push(new Request(input, init));
      return Promise.resolve(
        responses.shift() ?? new Response("", { status: 500 }),
      );
    },
    now: () => new Date("2026-09-22T10:00:00Z"),
  });
  return { client, calls };
}
const token = () =>
  new Response(JSON.stringify({ access_token: "access", expires_in: 3600 }));

Deno.test("verification exchanges a service-account JWT once and calls subscriptionsv2", async () => {
  const { client, calls } = await setup([
    token(),
    new Response('{"subscriptionState":"SUBSCRIPTION_STATE_ACTIVE"}'),
    new Response("{}"),
  ]);
  const result = await client.getSubscription("czechify_core", "tok/en+1");
  assertEquals(
    (result.body as Record<string, string>).subscriptionState,
    "SUBSCRIPTION_STATE_ACTIVE",
  );
  await client.getSubscription("czechify_core", "second");
  assertEquals(calls.length, 3, "access token is cached");
  const form = new URLSearchParams(await calls[0].text());
  assertEquals(
    form.get("grant_type"),
    "urn:ietf:params:oauth:grant-type:jwt-bearer",
  );
  assert(form.get("assertion")!.split(".").length === 3);
  assertEquals(
    calls[1].url,
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.czechify.app/purchases/subscriptionsv2/tokens/tok%2Fen%2B1",
  );
  assertEquals(calls[1].headers.get("Authorization"), "Bearer access");
});

Deno.test("acknowledgement posts to the product's token", async () => {
  const { client, calls } = await setup([
    token(),
    new Response(null, { status: 204 }),
  ]);
  await client.acknowledge("czechify_core", "abc");
  assertEquals(calls[1].method, "POST");
  assertEquals(
    calls[1].url,
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.czechify.app/purchases/subscriptions/czechify_core/tokens/abc:acknowledge",
  );
});

Deno.test("unknown tokens are permanent; outages and auth failures retry", async () => {
  const cases: [Response[], string, boolean, number | null][] = [
    [
      [token(), new Response("", { status: 404 })],
      "purchase_not_found",
      false,
      null,
    ],
    [
      [token(), new Response("", { status: 400 })],
      "play_rejected",
      false,
      null,
    ],
    [
      [
        token(),
        new Response("", { status: 503, headers: { "Retry-After": "30" } }),
      ],
      "play_verification_failed",
      true,
      30,
    ],
    [[new Response("", { status: 401 })], "play_auth_failed", true, null],
  ];
  for (const [responses, code, retryable, after] of cases) {
    const { client } = await setup(responses);
    const error = await assertRejects(
      () => client.getSubscription("czechify_core", "t"),
      PlayApiError,
    );
    assertEquals([error.code, error.retryable, error.retryAfterSeconds], [
      code,
      retryable,
      after,
    ]);
  }
});

Deno.test("configuration is validated before any call", () => {
  assertThrows(() => parseServiceAccount("{}"), PlayApiError);
  assertThrows(() => parseServiceAccount(undefined), PlayApiError);
  assertThrows(
    () =>
      createPlayClient({
        packageName: "not a package",
        account: { client_email: "a", private_key: "b", token_uri: "c" },
      }),
    PlayApiError,
  );
});
