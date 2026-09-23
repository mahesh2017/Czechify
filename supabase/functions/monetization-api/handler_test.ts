import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { compactVerify, exportJWK, generateKeyPair } from "npm:jose@6.2.12";
import { createHandler, type Dependencies } from "./handler.ts";
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
