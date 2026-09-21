import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import { createHandler } from "./handler.ts";
import { verifyPushToken } from "../_shared/monetization/play_notifications.ts";
import { recordPlayNotification } from "../_shared/monetization/billing_rpc.ts";

// Gateway JWT verification is off for this function only (config.toml):
// Google signs these requests, and the handler verifies that token itself.
const audience = Deno.env.get("PLAY_PUSH_AUDIENCE") ?? "";
const email = Deno.env.get("PLAY_PUSH_SERVICE_ACCOUNT") ?? "";
const packageName = Deno.env.get("PLAY_PACKAGE_NAME") ?? "";

Deno.serve(createHandler({
  // Unconfigured means every request is refused, never accepted.
  authenticate: (authorization) =>
    audience && email && packageName
      ? verifyPushToken(authorization, { audience, email })
      : Promise.resolve(false),
  packageName,
  record: recordPlayNotification(admin),
}));

function admin() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Backend is not configured");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
