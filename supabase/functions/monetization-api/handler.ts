import {
  corsHeaders,
  type CorsPolicy,
  preflightResponse,
} from "../_shared/cors.ts";
import { sha256Hex } from "../_shared/monetization/billing_crypto.ts";
import type { BillingDependencies } from "../_shared/monetization/billing_rpc.ts";
import { runBillingJob } from "../_shared/monetization/purchase_jobs.ts";

export type { BillingDependencies };

type Json = Record<string, unknown>;

export interface Dependencies {
  authenticate(
    token: string,
  ): Promise<{ id: string; anonymous?: boolean } | null>;
  snapshot(userId: string): Promise<Record<string, unknown> | null>;
  sign(payload: Record<string, unknown>): Promise<string>;
  /** Absent until billing secrets are configured; purchase routes then 503. */
  billing?: () => Promise<BillingDependencies>;
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
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const productPattern = /^[a-z0-9_.]{1,100}$/;
const maxBody = 24 * 1024;
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
    if (url.search) return response({ code: "unexpected_parameters" }, 400);
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ") || authorization.length > 16384) {
      return response({ code: "authentication_required" }, 401);
    }
    try {
      const user = await deps.authenticate(authorization.slice(7));
      if (!user) return response({ code: "authentication_required" }, 401);
      if (name === "configuration") {
        return response({
          schema_version: 1,
          minimum_protocol_version: 1,
          campaign_id: "a1-referral-v1",
          free_unit_ids: [1, 2],
          course_paywall_enabled: false,
          play_checkout_enabled: false,
          referral_claims_enabled: false,
          paid_chat_required: false,
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
      const body = await readJson(request);
      if (!body) return response({ code: "invalid_request" }, 400);
      if (name === "purchase-intents") {
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
    return response({ code: "account_binding_mismatch" }, 403);
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
    return response({ code: "account_binding_mismatch" }, 403);
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

async function readJson(request: Request): Promise<Json | null> {
  if (Number(request.headers.get("Content-Length") ?? "0") > maxBody) {
    return null;
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).length > maxBody) return null;
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
