import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import { alertMessage, createHandler } from "./handler.ts";
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
  operations: async () => {
    const { data, error } = await admin().rpc(
      "monetization_operations_report",
    );
    if (error) throw new Error("Operations report failed");
    return data;
  },
  notify: alertWebhook(),
}));

// MONETIZATION_ALERT_WEBHOOK_URL (https only) receives each crossed alert at
// most once an hour while it stays crossed. Without it, alerts are log lines.
function alertWebhook() {
  const url = Deno.env.get("MONETIZATION_ALERT_WEBHOOK_URL");
  if (!url) return undefined;
  if (!url.startsWith("https://")) {
    console.warn("monetization_alert_webhook_not_https");
    return undefined;
  }
  return async (alerts: { alert: string; level: string }[]) => {
    const { data, error } = await admin().rpc("claim_alert_deliveries", {
      p_alerts: alerts.map((a) => a.alert),
      p_minutes: 60,
    });
    if (error) throw new Error("Alert throttle failed");
    const due = new Set<string>(data ?? []);
    const send = alerts.filter((a) => due.has(a.alert));
    if (send.length === 0) return;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(alertMessage(send)),
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) throw new Error("Alert webhook refused");
  };
}

function admin() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Backend is not configured");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
