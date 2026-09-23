import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  canonicalJson,
  integrityRequestHash,
  InvalidReceipt,
  normalizeReceipt,
  receiptDigest,
} from "./referral_receipt.ts";

// Generated with Python's json module, independently of this implementation;
// the Flutter client must reproduce the same bytes. A module import needs no
// read permission, which CI's `deno test --allow-env` does not grant.
import fixture from "../../../../test/fixtures/monetization/referral_receipt.v1.json" with {
  type: "json",
};

Deno.test("canonical bytes and digest match the cross-language fixture", async () => {
  const receipt = normalizeReceipt(fixture.receipt_as_sent);
  assertEquals(canonicalJson(receipt), fixture.canonical);
  assertEquals(await receiptDigest(receipt), fixture.receipt_digest);
});

Deno.test("the Integrity request hash matches the fixture", async () => {
  assertEquals(
    canonicalJson(fixture.integrity_binding),
    fixture.integrity_binding_canonical,
  );
  assertEquals(
    await integrityRequestHash(fixture.integrity_binding),
    fixture.integrity_request_hash,
  );
});

Deno.test("coverage order and key order do not change the digest", async () => {
  const sent = structuredClone(fixture.receipt_as_sent);
  const reordered = Object.fromEntries(Object.entries(sent).reverse());
  assertEquals(
    await receiptDigest(normalizeReceipt(reordered)),
    fixture.receipt_digest,
  );
});

Deno.test("values two JSON libraries could encode differently are refused", () => {
  const base = fixture.receipt_as_sent;
  const cases: Record<string, unknown>[] = [
    { ...base, extra: 1 },
    { ...base, schema_version: 2 },
    { ...base, lesson_id: 100.5 },
    { ...base, lesson_id: "100" },
    { ...base, claim_id: "not-a-uuid" },
    { ...base, attempt_id: base.attempt_id.toUpperCase() },
    { ...base, campaign_id: "Ä-campaign" },
    { ...base, started_at_client: "2026-10-01T11:40:00+02:00" },
    { ...base, completed_at_client: "2026-10-01T11:52:30.25Z" },
    { ...base, initial_coverage: [] },
    {
      ...base,
      initial_coverage: [{ exercise_id: 898, interaction: "guessed" }],
    },
    {
      ...base,
      initial_coverage: [{ exercise_id: 898, interaction: "skipped", x: 1 }],
    },
  ];
  for (const receipt of cases) {
    assertThrows(() => normalizeReceipt(receipt), InvalidReceipt);
  }
  assertThrows(() => canonicalJson({ a: 1.5 }), InvalidReceipt);
  assertThrows(() => canonicalJson({ a: "č" }), InvalidReceipt);
  assertThrows(() => canonicalJson({ A: 1 }), InvalidReceipt);
});
