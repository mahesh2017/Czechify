import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import {
  corsHeaders,
  type CorsPolicy,
  parseAllowedOrigins,
  preflightResponse,
} from "../_shared/cors.ts";
import {
  confirmsDeletion,
  decodeJwtIssuedAt,
  hasRecentAuth,
  isSupportedMethod,
  requiresRecentAuth,
  syncedUserTables,
} from "./account_policy.ts";

const CORS: CorsPolicy = {
  allowedOrigins: parseAllowedOrigins(Deno.env.get("ALLOWED_ORIGINS")),
  allowedHeaders:
    "authorization, apikey, content-type, x-client-info, x-confirm-account-deletion",
  allowedMethods: "GET, DELETE, OPTIONS",
};

Deno.serve(async (request) => {
  const origin = request.headers.get("Origin");
  if (request.method === "OPTIONS") {
    return preflightResponse(origin, CORS);
  }
  const cors = corsHeaders(origin, CORS);
  const jsonResponse = (body: Record<string, unknown>, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: {
        ...cors,
        "Cache-Control": "no-store",
        "Content-Type": "application/json",
      },
    });

  if (!isSupportedMethod(request.method)) {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Authentication required." }, 401);
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Missing required account-data secrets.");
    return jsonResponse({ error: "Account service is not configured." }, 503);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const jwt = authorization.slice("Bearer ".length);
  const { data: userData, error: authError } = await admin.auth.getUser(jwt);
  const user = userData.user;
  if (authError || !user) {
    return jsonResponse({ error: "Invalid or expired session." }, 401);
  }

  if (request.method === "GET") {
    const results = await Promise.all(
      syncedUserTables.map(async (table) => {
        const { data, error } = await admin
          .from(table)
          .select("*")
          .eq("user_id", user.id);
        if (error) throw new Error(`${table}:${error.code}`);
        return [table, data ?? []] as const;
      }),
    ).catch((error) => {
      console.error(
        "Account export failed",
        error instanceof Error ? error.message : "unknown",
      );
      return null;
    });
    if (!results) {
      return jsonResponse({ error: "Could not export account data." }, 503);
    }
    return jsonResponse({
      format_version: 1,
      exported_at: new Date().toISOString(),
      account: {
        id: user.id,
        email: user.email ?? null,
        is_anonymous: user.is_anonymous ?? false,
        created_at: user.created_at,
        identities: (user.identities ?? []).map((identity) => ({
          provider: identity.provider,
          created_at: identity.created_at,
        })),
      },
      cloud_data: Object.fromEntries(results),
    });
  }

  if (
    !confirmsDeletion(
      request.headers.get("x-confirm-account-deletion"),
    )
  ) {
    return jsonResponse({ error: "Deletion confirmation is required." }, 400);
  }

  // Re-authentication gate. The confirmation header proves intent, not
  // identity: anyone holding a valid access token could previously wipe the
  // account. Requiring a token minted in the last few minutes means the
  // caller has just proved who they are.
  if (
    requiresRecentAuth(user.is_anonymous === true) &&
    !hasRecentAuth(decodeJwtIssuedAt(jwt), Math.floor(Date.now() / 1000))
  ) {
    return jsonResponse({
      error: "Please sign in again to confirm account deletion.",
      code: "reauthentication_required",
    }, 401);
  }

  const { error: signOutError } = await admin.auth.admin.signOut(jwt, "global");
  if (signOutError) {
    console.error("Account session revocation failed", signOutError.code);
    return jsonResponse({ error: "Could not revoke account sessions." }, 503);
  }
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("Account deletion failed", deleteError.code);
    return jsonResponse({ error: "Could not delete account." }, 503);
  }
  return new Response(null, {
    status: 204,
    headers: { ...cors, "Cache-Control": "no-store" },
  });
});
