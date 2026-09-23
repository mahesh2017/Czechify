import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import { createHandler } from "./handler.ts";
import {
  billingSecrets,
  createBilling,
  workerQueries,
} from "../_shared/monetization/billing_rpc.ts";

Deno.serve(createHandler({
  // Missing billing secrets leave the secret empty, which never matches.
  secret: billingSecrets.every((name) => Deno.env.get(name))
    ? Deno.env.get("BILLING_WORKER_SECRET") ?? ""
    : "",
  jobs: async () =>
    (await createBilling((name) => Deno.env.get(name) as string, admin)).jobs,
  ...workerQueries(admin),
}));

function admin() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Backend is not configured");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
