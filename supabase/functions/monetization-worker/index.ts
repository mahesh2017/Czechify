import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import { createHandler } from "./handler.ts";
import {
  billingSecrets,
  createBilling,
  workerQueries,
} from "../_shared/monetization/billing_rpc.ts";
import { referralWorkerQueries } from "../_shared/monetization/referral_rpc.ts";

const billingConfigured = billingSecrets.every((name) => Deno.env.get(name));

Deno.serve(createHandler({
  // A missing secret stays empty, which never matches.
  secret: Deno.env.get("BILLING_WORKER_SECRET") ?? "",
  billing: billingConfigured
    ? {
      jobs: async () =>
        (await createBilling((name) => Deno.env.get(name) as string, admin))
          .jobs,
      ...workerQueries(admin),
    }
    : undefined,
  referrals: referralWorkerQueries(admin),
  aiRetention: async () => {
    const { data, error } = await admin().rpc("cleanup_ai_request_records");
    if (error) throw new Error("AI retention failed");
    return data;
  },
  privacyRetention: async () => {
    const { data, error } = await admin().rpc("cleanup_privacy_records");
    if (error) throw new Error("Privacy retention failed");
    return data;
  },
}));

function admin() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Backend is not configured");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
