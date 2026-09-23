import {
  corsHeaders,
  type CorsPolicy,
  preflightResponse,
} from "../_shared/cors.ts";

export interface Dependencies {
  authenticate(token: string): Promise<{ id: string } | null>;
  snapshot(userId: string): Promise<Record<string, unknown> | null>;
  sign(payload: Record<string, unknown>): Promise<string>;
}
const cors: CorsPolicy = {
  allowedOrigins: [],
  allowedHeaders: "authorization, apikey, content-type, x-client-info",
  allowedMethods: "GET, OPTIONS",
};

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
    if (request.method !== "GET") {
      return response({ code: "method_not_allowed" }, 405);
    }
    const url = new URL(request.url);
    const route = url.pathname.split("/").filter(Boolean).pop();
    if (route !== "configuration" && route !== "entitlements") {
      return response({ code: "not_found" }, 404);
    }
    if (url.search) return response({ code: "unexpected_parameters" }, 400);
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ") || authorization.length > 16384) {
      return response({ code: "authentication_required" }, 401);
    }
    try {
      const user = await deps.authenticate(authorization.slice(7));
      if (!user) return response({ code: "authentication_required" }, 401);
      if (route === "configuration") {
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
      const snapshot = await deps.snapshot(user.id);
      if (
        !snapshot || snapshot.user_id !== user.id ||
        snapshot.schema_version !== 1
      ) {
        return response({ code: "verification_unavailable" }, 503);
      }
      return response({ snapshot_jws: await deps.sign(snapshot) });
    } catch {
      // Do not log tokens, private keys or the database's raw error payload.
      return response({ code: "verification_unavailable" }, 503);
    }
  };
}
