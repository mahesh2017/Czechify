import {
  corsHeaders,
  type CorsPolicy,
  preflightResponse,
} from "../_shared/cors.ts";
import { sha256Hex } from "../_shared/monetization/billing_crypto.ts";
import type { BillingDependencies } from "../_shared/monetization/billing_rpc.ts";
import { runBillingJob } from "../_shared/monetization/purchase_jobs.ts";
import {
  handleLegacyRoute,
  type LegacyDependencies,
  legacyRoutes,
} from "./legacy.ts";
import {
  handleReferralRoute,
  type ReferralDependencies,
  referralRoutes,
} from "./referrals.ts";

export type { BillingDependencies, LegacyDependencies, ReferralDependencies };

type Json = Record<string, unknown>;

export interface Dependencies {
  authenticate(
    token: string,
  ): Promise<{ id: string; anonymous?: boolean } | null>;
  snapshot(userId: string): Promise<Record<string, unknown> | null>;
  sign(payload: Record<string, unknown>): Promise<string>;
  /** Absent until billing secrets are configured; purchase routes then 503. */
  billing?: () => Promise<BillingDependencies>;
  /** Absent when the backend cannot reach the database; routes then 503. */
  referrals?: () => Promise<ReferralDependencies>;
  /** The existing-user migration's status and offline claim. */
  legacy?: LegacyDependencies;
  /**
   * Whether the AI tutor proxy requires the AI subscription for chat. The
   * proxy reads the same AI_PAID_CHAT_REQUIRED switch, so the app is told
   * exactly what the server enforces.
   */
  paidChatRequired?: boolean;
  /** Tutor turns per day, from the proxy's AI_DAILY_REQUEST_LIMIT. */
  aiDailyTurnLimit?: number;
  /**
   * The account's staged-rollout cohort ({feature: boolean}). Absent means
   * nothing is switched on.
   */
  rollout?: (userId: string) => Promise<Record<string, unknown>>;
}
const cors: CorsPolicy = {
  allowedOrigins: [],
  allowedHeaders:
    "authorization, apikey, content-type, x-client-info, idempotency-key",
  allowedMethods: "GET, POST, OPTIONS",
};
const routes: Record<string, string> = {
  "configuration": "GET",
  "entitlements": "GET",
  "purchase-intents": "POST",
  "purchases/verify": "POST",
  "purchases/status": "GET",
  ...referralRoutes,
  ...legacyRoutes,
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const productPattern = /^[a-z0-9_.]{1,100}$/;
const maxBody = 24 * 1024;
// Receipts carry full lesson coverage; the contract allows 64 KiB.
const maxReceiptBody = 64 * 1024;
const maxToken = 16 * 1024;

export function createHandler(deps: Dependencies) {
  return async (request: Request): Promise<Response> => {
    const origin = request.headers.get("origin");
    if (request.method === "OPTIONS") return preflightResponse(origin, cors);
    const requestId = crypto.randomUUID();
    const response = (body: Record<string, unknown>, status = 200) =>
      new Response(
        JSON.stringify({
          ...body,
          request_id: requestId,
          server_time: new Date().toISOString(),
          policy_version: "course-access-v1",
        }),
        {
          status,
          headers: {
            ...corsHeaders(origin, cors),
            "Content-Type": "application/json",
            "Cache-Control": "private, no-store",
          },
        },
      );
    const url = new URL(request.url);
    const segments = url.pathname.split("/").filter(Boolean);
    const route = segments.slice(segments.indexOf("monetization-api") + 1);
    const statusId = route.length === 3 && route[0] === "purchases" &&
        route[1] === "status"
      ? route[2]
      : null;
    const name = statusId === null ? route.join("/") : "purchases/status";
    if (!(name in routes) || (statusId !== null && !uuid.test(statusId))) {
      return response({ code: "not_found" }, 404);
    }
    if (routes[name] !== request.method) {
      return response({ code: "method_not_allowed" }, 405);
    }
    // Only referral status pages; nothing else takes query parameters.
    const allowedParams = name === "referrals/status"
      ? ["cursor", "limit"]
      : [];
    if ([...url.searchParams.keys()].some((k) => !allowedParams.includes(k))) {
      return response({ code: "unexpected_parameters" }, 400);
    }
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ") || authorization.length > 16384) {
      return response({ code: "authentication_required" }, 401);
    }
    try {
      const user = await deps.authenticate(authorization.slice(7));
      if (!user) return response({ code: "authentication_required" }, 401);
      // Only an explicit true from the account's cohort turns a feature on.
      const cohort = async () =>
        deps.rollout ? await deps.rollout(user.id) : {};
      if (name === "configuration") {
        const on = await cohort();
        return response({
          schema_version: 1,
          minimum_protocol_version: 1,
          campaign_id: "a1-referral-v1",
          free_unit_ids: [1, 2],
          course_paywall_enabled: on.course_paywall === true,
          play_checkout_enabled: on.play_checkout === true &&
            deps.billing !== undefined,
          referral_claims_enabled: on.referral_claims === true,
          paid_chat_required: deps.paidChatRequired === true &&
            on.paid_chat === true,
          ai_daily_turn_limit: deps.aiDailyTurnLimit ?? 20,
          product_ids: [],
        });
      }
      if (name === "entitlements") {
        const snapshot = await deps.snapshot(user.id);
        if (
          !snapshot || snapshot.user_id !== user.id ||
          snapshot.schema_version !== 1
        ) {
          return response({ code: "verification_unavailable" }, 503);
        }
        return response({ snapshot_jws: await deps.sign(snapshot) });
      }
      if (name.startsWith("referrals/")) {
        if (!deps.referrals) {
          return response({ code: "verification_unavailable" }, 503);
        }
        // New codes and claims only in the cohort; evidence and status for
        // claims already made keep working.
        if (
          (name === "referrals/code" || name === "referrals/claim") &&
          (await cohort()).referral_claims !== true
        ) {
          return response({ code: "campaign_unavailable" }, 409);
        }
        return await handleReferralRoute(
          name,
          user.id,
          url,
          request.method === "POST"
            ? await readJson(request, maxReceiptBody)
            : null,
          await deps.referrals(),
          response,
        );
      }
      if (name.startsWith("legacy/")) {
        if (!deps.legacy) {
          return response({ code: "verification_unavailable" }, 503);
        }
        return await handleLegacyRoute(
          name,
          user.id,
          request.method === "POST" ? await readJson(request, maxBody) : null,
          deps.legacy,
          response,
        );
      }
      if (!deps.billing) {
        return response({ code: "verification_unavailable" }, 503);
      }
      // Purchases belong to a linked identity so they survive reinstalls.
      if (user.anonymous !== false) {
        return response({ code: "linked_account_required" }, 403);
      }
      const billing = await deps.billing();
      if (statusId !== null) {
        const status = await billing.status(user.id, statusId);
        return status ? response(status) : response({ code: "not_found" }, 404);
      }
      const body = await readJson(request, maxBody);
      if (!body) return response({ code: "invalid_request" }, 400);
      if (name === "purchase-intents") {
        // Restores stay open to everyone; new purchases only in the cohort.
        if ((await cohort()).play_checkout !== true) {
          return response({ code: "product_unavailable" }, 422);
        }
        return await createIntent(request, body, user.id, billing, response);
      }
      return await verify(body, user.id, billing, response);
    } catch {
      // Do not log tokens, private keys or the database's raw error payload.
      return response({ code: "verification_unavailable" }, 503);
    }
  };
}

type Respond = (body: Json, status?: number) => Response;

async function createIntent(
  request: Request,
  body: Json,
  userId: string,
  billing: BillingDependencies,
  response: Respond,
): Promise<Response> {
  const idempotencyKey = request.headers.get("Idempotency-Key") ?? "";
  if (
    !uuid.test(idempotencyKey) ||
    !exactKeys(body, ["product_id", "base_plan_id", "platform"], []) ||
    body.platform !== "android" || !isProduct(body.product_id) ||
    !isProduct(body.base_plan_id)
  ) {
    return response({ code: "invalid_request" }, 400);
  }
  const candidate = await billing.obfuscatedAccountId(userId);
  await billing.bindAccount(userId, candidate.id, candidate.keyVersion);
  const { status, ...intent } = await billing.createIntent(
    userId,
    body.product_id,
    body.base_plan_id,
    idempotencyKey,
  );
  switch (status) {
    case "created":
      return response(intent, 201);
    case "idempotency_conflict":
      return response({ code: "idempotency_conflict" }, 409);
    case "rate_limited":
      return response(
        { code: "rate_limited", retry_after_seconds: 3600 },
        429,
      );
    default:
      return response({ code: "product_unavailable" }, 422);
  }
}

async function verify(
  body: Json,
  userId: string,
  billing: BillingDependencies,
  response: Respond,
): Promise<Response> {
  const token = body.purchase_token;
  const intent = body.intent_id;
  if (
    !exactKeys(body, ["purchase_token", "product_id", "source"], [
      "intent_id",
    ]) ||
    typeof token !== "string" || token.length === 0 ||
    token.length > maxToken || !isProduct(body.product_id) ||
    (body.source !== "purchase" && body.source !== "restore") ||
    (intent !== undefined &&
      (typeof intent !== "string" || !uuid.test(intent)))
  ) {
    return response({ code: "invalid_request" }, 400);
  }
  const registered = await billing.register(
    userId,
    await sha256Hex(token),
    await billing.jobs.cipher.encrypt(token),
    body.product_id,
    (intent as string | undefined) ?? null,
  );
  if (registered.status === "account_binding_mismatch") {
    return mismatch(registered.recovery_case_id, response);
  }
  if (registered.status !== "queued") {
    return response({ code: "product_unavailable" }, 422);
  }
  const verificationId = registered.purchase_id;
  const pending = () =>
    response({
      status: "verification_pending",
      verification_id: verificationId,
      retry_after_seconds: 5,
    }, 202);
  if (typeof registered.job_id !== "string") return pending();
  const outcome = await runBillingJob(billing.jobs, registered.job_id);
  if (outcome.status === "account_binding_mismatch") {
    return mismatch(outcome.recoveryCaseId, response);
  }
  if (outcome.status === "product_mismatch") {
    return response({ code: "product_unavailable" }, 422);
  }
  if (outcome.status !== "provisioned") return pending();
  // Access is already committed. A failed acknowledgement stays queued for
  // retry and never undoes it.
  if (outcome.ackJobId) await runBillingJob(billing.jobs, outcome.ackJobId);
  return response({
    status: "provisioned",
    verification_id: verificationId,
    state: outcome.state,
    access: outcome.access,
    revision: outcome.revision,
  });
}

/**
 * The purchase belongs to another account. A support case opened for this
 * account is its reference; the other account is never revealed.
 */
function mismatch(caseId: unknown, response: Respond): Response {
  return response({
    code: "account_binding_mismatch",
    ...(typeof caseId === "string" && uuid.test(caseId)
      ? { recovery_case_id: caseId }
      : {}),
  }, 403);
}

async function readJson(
  request: Request,
  limit: number,
): Promise<Json | null> {
  if (Number(request.headers.get("Content-Length") ?? "0") > limit) {
    return null;
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).length > limit) return null;
  try {
    const value = JSON.parse(text);
    return typeof value === "object" && value !== null && !Array.isArray(value)
      ? value
      : null;
  } catch {
    return null;
  }
}

/** Rejects unknown fields so clients cannot smuggle an account or a state. */
function exactKeys(body: Json, required: string[], optional: string[]) {
  const keys = Object.keys(body);
  return required.every((k) => keys.includes(k)) &&
    keys.every((k) => required.includes(k) || optional.includes(k));
}

const isProduct = (value: unknown): value is string =>
  typeof value === "string" && productPattern.test(value);
