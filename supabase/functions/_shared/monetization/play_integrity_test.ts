import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import { exportPKCS8, generateKeyPair } from "npm:jose@6.2.12";
import { GoogleApiError } from "./google_auth.ts";
import {
  createIntegrityVerifier,
  evaluateIntegrityPayload,
  IntegrityRejected,
} from "./play_integrity.ts";

const now = Date.parse("2026-09-23T10:00:00Z");
const expected = {
  packageName: "com.czechify.app",
  requestHash: "a".repeat(64),
  certificateDigests: ["cert-digest-1"],
  now,
};
const payload = (overrides: Record<string, unknown> = {}) => ({
  requestDetails: {
    requestPackageName: "com.czechify.app",
    requestHash: "a".repeat(64),
    timestampMillis: String(now - 30_000),
  },
  appIntegrity: {
    appRecognitionVerdict: "PLAY_RECOGNIZED",
    packageName: "com.czechify.app",
    certificateSha256Digest: ["cert-digest-1"],
  },
  deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_DEVICE_INTEGRITY"] },
  accountDetails: { appLicensingVerdict: "LICENSED" },
  ...overrides,
});

Deno.test("a recognized app on a certified device with a licence is verified", () => {
  assertEquals(evaluateIntegrityPayload(payload(), expected), "verified");
});

Deno.test("tokens not made for this request are rejected", () => {
  const request = payload().requestDetails;
  for (
    const bad of [
      payload({ requestDetails: { ...request, requestPackageName: "x.y" } }),
      payload({ requestDetails: { ...request, requestHash: "b".repeat(64) } }),
      payload({
        requestDetails: {
          ...request,
          timestampMillis: String(now - 11 * 60_000),
        },
      }),
      payload({
        requestDetails: {
          ...request,
          timestampMillis: String(now + 5 * 60_000),
        },
      }),
      payload({
        appIntegrity: {
          ...payload().appIntegrity,
          certificateSha256Digest: ["someone-else"],
        },
      }),
      payload({
        appIntegrity: { ...payload().appIntegrity, packageName: "x.y" },
      }),
      null,
    ]
  ) {
    assertThrows(
      () => evaluateIntegrityPayload(bad, expected),
      IntegrityRejected,
    );
  }
});

Deno.test("verdicts Play cannot vouch for go to review, not rejection", () => {
  for (
    const weak of [
      payload({
        appIntegrity: {
          appRecognitionVerdict: "UNEVALUATED",
        },
      }),
      payload({
        appIntegrity: {
          ...payload().appIntegrity,
          appRecognitionVerdict: "UNRECOGNIZED_VERSION",
        },
      }),
      payload({ deviceIntegrity: { deviceRecognitionVerdict: [] } }),
      payload({ accountDetails: { appLicensingVerdict: "UNLICENSED" } }),
      payload({ accountDetails: { appLicensingVerdict: "UNEVALUATED" } }),
    ]
  ) {
    assertEquals(evaluateIntegrityPayload(weak, expected), "needs_review");
  }
});

async function verifier(responses: Response[]) {
  const { privateKey } = await generateKeyPair("RS256", { extractable: true });
  const calls: Request[] = [];
  const v = createIntegrityVerifier({
    packageName: "com.czechify.app",
    certificateDigests: ["cert-digest-1"],
    account: {
      client_email: "integrity@example.iam.gserviceaccount.com",
      private_key: await exportPKCS8(privateKey),
      token_uri: "https://oauth2.example.com/token",
    },
    fetch: (input, init) => {
      calls.push(new Request(input, init));
      return Promise.resolve(
        responses.shift() ?? new Response("", { status: 500 }),
      );
    },
    now: () => new Date(now),
  });
  return { v, calls };
}
const oauth = () =>
  new Response(JSON.stringify({ access_token: "access", expires_in: 3600 }));

Deno.test("the verifier decodes through Play and applies the policy", async () => {
  const { v, calls } = await verifier([
    oauth(),
    new Response(JSON.stringify({ tokenPayloadExternal: payload() })),
  ]);
  assertEquals(await v.verify("token", "a".repeat(64)), "verified");
  assertEquals(
    calls[1].url,
    "https://playintegrity.googleapis.com/v1/com.czechify.app:decodeIntegrityToken",
  );
  assertEquals(await calls[1].json(), { integrity_token: "token" });
  const scope = JSON.parse(
    atob(
      new URLSearchParams(await calls[0].text()).get("assertion")!.split(".")[1]
        .replaceAll("-", "+").replaceAll("_", "/"),
    ),
  ).scope;
  assertEquals(scope, "https://www.googleapis.com/auth/playintegrity");
});

Deno.test("an undecodable token is rejected; an outage is retryable", async () => {
  const bad = await verifier([oauth(), new Response("", { status: 400 })]);
  await assertRejects(
    () => bad.v.verify("t", "a".repeat(64)),
    IntegrityRejected,
  );
  const down = await verifier([oauth(), new Response("", { status: 503 })]);
  const error = await assertRejects(
    () => down.v.verify("t", "a".repeat(64)),
    GoogleApiError,
  );
  assertEquals(error.retryable, true);
});

Deno.test("configuration is required up front", () => {
  const account = { client_email: "a", private_key: "b", token_uri: "c" };
  assertThrows(
    () =>
      createIntegrityVerifier({
        packageName: "com.czechify.app",
        certificateDigests: [],
        account,
      }),
    GoogleApiError,
  );
  assertThrows(
    () =>
      createIntegrityVerifier({
        packageName: "bad name",
        certificateDigests: ["x"],
        account,
      }),
    GoogleApiError,
  );
});
