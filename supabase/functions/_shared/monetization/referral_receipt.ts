// Canonical referral receipts, shared byte-for-byte with the Flutter client.
//
// Canonical JSON here: object keys sorted by code point at every level, no
// whitespace, integers only, ASCII-only strings. Every value in a receipt is
// an ASCII identifier, timestamp or enum, so a value outside that profile is
// refused rather than escaped differently by two JSON libraries. The fixture
// test/fixtures/monetization/referral_receipt.v1.json pins the exact bytes.

import { sha256Hex } from "./billing_crypto.ts";

export class InvalidReceipt extends Error {}

type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

export function canonicalJson(value: unknown): string {
  if (value === null || typeof value === "boolean") {
    return JSON.stringify(value);
  }
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) throw new InvalidReceipt("number");
    return String(value);
  }
  if (typeof value === "string") {
    if (!/^[\x20-\x7e]*$/.test(value)) throw new InvalidReceipt("string");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (typeof value === "object") {
    const entries = Object.keys(value as object).sort().map((key) => {
      if (!/^[a-z_]+$/.test(key)) throw new InvalidReceipt("key");
      return `${JSON.stringify(key)}:${
        canonicalJson((value as Record<string, unknown>)[key])
      }`;
    });
    return `{${entries.join(",")}}`;
  }
  throw new InvalidReceipt("type");
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
// UTC, second or millisecond precision, as Dart's toIso8601String() on a UTC
// DateTime truncated to milliseconds produces.
const timestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$/;
const interactions = new Set([
  "teaching_acknowledged",
  "answered_correctly",
  "answered_incorrectly",
  "skipped",
]);
const receiptKeys = [
  "attempt_id",
  "campaign_id",
  "claim_id",
  "completed_at_client",
  "content_revision",
  "initial_coverage",
  "lesson_id",
  "schema_version",
  "started_at_client",
];

export interface ReferralReceipt {
  schema_version: 1;
  claim_id: string;
  campaign_id: string;
  content_revision: number;
  lesson_id: number;
  attempt_id: string;
  started_at_client: string;
  completed_at_client: string;
  initial_coverage: { exercise_id: number; interaction: string }[];
}

const isObject = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);

/**
 * Checks the receipt's shape and returns it with coverage sorted by exercise.
 * Manifest membership and ownership are the database's to decide.
 */
export function normalizeReceipt(raw: unknown): ReferralReceipt {
  if (
    !isObject(raw) ||
    Object.keys(raw).sort().join() !== receiptKeys.join() ||
    raw.schema_version !== 1 ||
    typeof raw.claim_id !== "string" || !uuid.test(raw.claim_id) ||
    typeof raw.attempt_id !== "string" || !uuid.test(raw.attempt_id) ||
    typeof raw.campaign_id !== "string" ||
    !/^[a-z0-9-]{1,64}$/.test(raw.campaign_id) ||
    !Number.isSafeInteger(raw.content_revision) ||
    !Number.isSafeInteger(raw.lesson_id) ||
    typeof raw.started_at_client !== "string" ||
    !timestamp.test(raw.started_at_client) ||
    typeof raw.completed_at_client !== "string" ||
    !timestamp.test(raw.completed_at_client) ||
    !Array.isArray(raw.initial_coverage) ||
    raw.initial_coverage.length === 0 || raw.initial_coverage.length > 200
  ) {
    throw new InvalidReceipt("shape");
  }
  const coverage = raw.initial_coverage.map((item) => {
    if (
      !isObject(item) || Object.keys(item).sort().join() !==
        "exercise_id,interaction" ||
      !Number.isSafeInteger(item.exercise_id) ||
      typeof item.interaction !== "string" ||
      !interactions.has(item.interaction)
    ) {
      throw new InvalidReceipt("coverage");
    }
    return {
      exercise_id: item.exercise_id as number,
      interaction: item.interaction,
    };
  }).sort((a, b) => a.exercise_id - b.exercise_id);
  return { ...(raw as unknown as ReferralReceipt), initial_coverage: coverage };
}

export const receiptDigest = (receipt: ReferralReceipt) =>
  sha256Hex(canonicalJson(receipt as unknown as Json));

/**
 * Play Integrity `requestHash`: binds the token to this account, claim,
 * campaign, receipt and single-use nonce. 64 hex characters, well inside
 * Play's 500-byte limit.
 */
export const integrityRequestHash = (input: {
  account_id: string;
  campaign_id: string;
  claim_id: string;
  nonce: string;
  receipt_digest: string;
}) => sha256Hex(canonicalJson(input));
