import {
  assertEquals,
  assertNotEquals,
  assertRejects,
} from "jsr:@std/assert@1";
import {
  createTokenCipher,
  deriveObfuscatedAccountId,
  sha256Hex,
} from "./billing_crypto.ts";

const key = btoa(String.fromCharCode(...new Uint8Array(32).fill(7)));
const otherKey = btoa(String.fromCharCode(...new Uint8Array(32).fill(9)));

Deno.test("token digest is lowercase SHA-256 hex", async () => {
  assertEquals(
    await sha256Hex("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

Deno.test("tokens round-trip, use a fresh IV and reject tampering or another key", async () => {
  const cipher = await createTokenCipher(key);
  const a = await cipher.encrypt("purchase-token");
  const b = await cipher.encrypt("purchase-token");
  assertNotEquals(a, b);
  assertEquals(await cipher.decrypt(a), "purchase-token");
  const [v, iv, body] = a.split(".");
  const flipped = (body[0] === "A" ? "B" : "A") + body.slice(1);
  await assertRejects(() => cipher.decrypt(`${v}.${iv}.${flipped}`));
  await assertRejects(() => cipher.decrypt(`v2.${iv}.${body}`));
  await assertRejects(async () =>
    (await createTokenCipher(otherKey)).decrypt(a)
  );
  await assertRejects(() => createTokenCipher(btoa("short")));
});

Deno.test("Play account reference is stable, opaque and per user", async () => {
  const a = await deriveObfuscatedAccountId(key, "user-a");
  assertEquals(a, await deriveObfuscatedAccountId(key, "user-a"));
  assertEquals(a.length, 43);
  assertEquals(/^[A-Za-z0-9_-]+$/.test(a), true);
  assertNotEquals(a, await deriveObfuscatedAccountId(key, "user-b"));
  assertNotEquals(a, await deriveObfuscatedAccountId(otherKey, "user-a"));
});
