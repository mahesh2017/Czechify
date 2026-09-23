// Referral routes of monetization-api. The account always comes from the
// verified JWT. Anonymous learners may claim and submit evidence (their
// rewards wait for linking in the database); only linked accounts get a code.

import { GoogleApiError } from "../_shared/monetization/google_auth.ts";
import {
  IntegrityRejected,
  type IntegrityVerifier,
} from "../_shared/monetization/play_integrity.ts";
import {
  integrityRequestHash,
  InvalidReceipt,
  normalizeReceipt,
  receiptDigest,
} from "../_shared/monetization/referral_receipt.ts";

type Json = Record<string, unknown>;
type Respond = (body: Json, status?: number) => Response;

export interface ReferralDependencies {
  code(actor: string, campaign: string): Promise<Json>;
  claim(actor: string, campaign: string, code: string): Promise<Json>;
  challenge(actor: string, claim: string, digest: string): Promise<Json>;
  findReceipt(
    actor: string,
    claim: string,
    attempt: string,
    digest: string,
  ): Promise<Json | null>;
  submit(
    actor: string,
    claim: string,
    nonce: string,
    receipt: Json,
    digest: string,
    integrity: "verified" | "needs_review",
  ): Promise<Json>;
  status(actor: string, after: number, limit: number): Promise<Json>;
  /** Null until Integrity is configured; tokens then cannot be checked. */
  integrity: IntegrityVerifier | null;
}

export const referralRoutes: Record<string, string> = {
  "referrals/code": "POST",
  "referrals/claim": "POST",
  "referrals/challenges": "POST",
  "referrals/receipts": "POST",
  "referrals/status": "GET",
};

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const hex64 = /^[0-9a-f]{64}$/;
const campaignPattern = /^[a-z0-9-]{1,64}$/;

/** Stable API codes for each database outcome. */
const statusFor: Record<string, number> = {
  authentication_required: 401,
  linked_account_required: 403,
  integrity_rejected: 403,
  referral_unavailable: 404,
  referral_already_claimed: 409,
  campaign_unavailable: 409,
  challenge_invalid: 409,
  content_update_required: 409,
  idempotency_conflict: 409,
  referral_ineligible: 422,
  invalid_receipt: 422,
  invalid_request: 400,
  rate_limited: 429,
};

const refused = (result: Json, respond: Respond) => {
  const code = typeof result.code === "string" ? result.code : "";
  return respond(
    { code: code in statusFor ? code : "verification_unavailable" },
    statusFor[code] ?? 503,
  );
};

export async function handleReferralRoute(
  name: string,
  actor: string,
  url: URL,
  body: Json | null,
  deps: ReferralDependencies,
  respond: Respond,
): Promise<Response> {
  if (name === "referrals/status") {
    const cursor = Number(url.searchParams.get("cursor") ?? "0");
    const limit = Number(url.searchParams.get("limit") ?? "20");
    if (
      !Number.isSafeInteger(cursor) || cursor < 0 ||
      !Number.isSafeInteger(limit) || limit < 1 || limit > 100
    ) {
      return respond({ code: "invalid_request" }, 400);
    }
    return respond(await deps.status(actor, cursor, limit));
  }
  if (!body) return respond({ code: "invalid_request" }, 400);

  if (name === "referrals/code") {
    if (!exact(body, ["campaign_id"]) || !isCampaign(body.campaign_id)) {
      return respond({ code: "invalid_request" }, 400);
    }
    const result = await deps.code(actor, body.campaign_id);
    return typeof result.referral_code === "string"
      ? respond({ referral_code: result.referral_code })
      : refused(result, respond);
  }

  if (name === "referrals/claim") {
    if (
      !exact(body, ["campaign_id", "code", "attribution_source"]) ||
      !isCampaign(body.campaign_id) || typeof body.code !== "string" ||
      body.code.length === 0 || body.code.length > 64 ||
      body.attribution_source !== "manual"
    ) {
      return respond({ code: "invalid_request" }, 400);
    }
    const result = await deps.claim(actor, body.campaign_id, body.code);
    return typeof result.claim_id === "string"
      ? respond({
        claim_id: result.claim_id,
        status: result.status,
        required_units: [1, 2],
      }, 201)
      : refused(result, respond);
  }

  if (name === "referrals/challenges") {
    if (
      !exact(body, ["claim_id", "receipt_digest"]) ||
      typeof body.claim_id !== "string" || !uuid.test(body.claim_id) ||
      typeof body.receipt_digest !== "string" ||
      !hex64.test(body.receipt_digest)
    ) {
      return respond({ code: "invalid_request" }, 400);
    }
    const result = await deps.challenge(
      actor,
      body.claim_id,
      body.receipt_digest,
    );
    return typeof result.nonce === "string"
      ? respond({ nonce: result.nonce, expires_at: result.expires_at }, 201)
      : refused(result, respond);
  }

  // referrals/receipts
  const unavailable = body.integrity_unavailable === true;
  if (
    !exact(body, ["receipt", "nonce"], [
      "integrity_token",
      "integrity_unavailable",
    ]) ||
    typeof body.nonce !== "string" || !hex64.test(body.nonce) ||
    (unavailable
      ? body.integrity_token !== undefined
      : body.integrity_unavailable !== undefined ||
        typeof body.integrity_token !== "string" ||
        body.integrity_token.length === 0 ||
        body.integrity_token.length > 16384)
  ) {
    return respond({ code: "invalid_request" }, 400);
  }
  let receipt;
  try {
    receipt = normalizeReceipt(body.receipt);
  } catch (error) {
    if (error instanceof InvalidReceipt) {
      return respond({ code: "invalid_receipt" }, 422);
    }
    throw error;
  }
  const digest = await receiptDigest(receipt);
  // A committed receipt answers before any challenge or token is needed.
  const replay = await deps.findReceipt(
    actor,
    receipt.claim_id,
    receipt.attempt_id,
    digest,
  );
  if (replay) {
    return typeof replay.receipt_id === "string"
      ? respond({ receipt_id: replay.receipt_id, status: replay.status }, 202)
      : refused(replay, respond);
  }
  let integrity: "verified" | "needs_review";
  if (unavailable) {
    // Devices without Play Integrity have an explicit, human-reviewed route.
    integrity = "needs_review";
  } else {
    if (!deps.integrity) {
      return respond({ code: "verification_unavailable" }, 503);
    }
    try {
      integrity = await deps.integrity.verify(
        body.integrity_token as string,
        await integrityRequestHash({
          account_id: actor,
          campaign_id: receipt.campaign_id,
          claim_id: receipt.claim_id,
          nonce: body.nonce,
          receipt_digest: digest,
        }),
      );
    } catch (error) {
      if (error instanceof IntegrityRejected) {
        return respond({ code: "integrity_rejected" }, 403);
      }
      if (error instanceof GoogleApiError) {
        return respond({ code: "verification_unavailable" }, 503);
      }
      throw error;
    }
  }
  const result = await deps.submit(
    actor,
    receipt.claim_id,
    body.nonce,
    receipt as unknown as Json,
    digest,
    integrity,
  );
  return typeof result.receipt_id === "string"
    ? respond({ receipt_id: result.receipt_id, status: result.status }, 202)
    : refused(result, respond);
}

function exact(body: Json, required: string[], optional: string[] = []) {
  const keys = Object.keys(body);
  return required.every((k) => keys.includes(k)) &&
    keys.every((k) => required.includes(k) || optional.includes(k));
}

const isCampaign = (value: unknown): value is string =>
  typeof value === "string" && campaignPattern.test(value);
