import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import { type BillingDependencies, createHandler } from "./handler.ts";
import { parseBoundedInteger } from "../deepseek-proxy/request_policy.ts";
import { createSnapshotSigner } from "./signing.ts";
import {
  billingSecrets,
  createBilling,
} from "../_shared/monetization/billing_rpc.ts";
import {
  createReferrals,
  integrityFromEnv,
} from "../_shared/monetization/referral_rpc.ts";

const billingConfigured = billingSecrets.every((name) => Deno.env.get(name));
let billing: Promise<BillingDependencies> | null = null;
// The campaign itself ships disabled in the database; these routes are inert
// until an operator enables it.
const referrals = createReferrals(admin, integrity());

// A malformed Integrity secret must not take the whole API down with it.
function integrity() {
  try {
    return integrityFromEnv((name) => Deno.env.get(name));
  } catch {
    console.warn("play_integrity_misconfigured");
    return null;
  }
}

Deno.serve(createHandler({
  paidChatRequired: Deno.env.get("AI_PAID_CHAT_REQUIRED") === "true",
  // Parsed as the proxy parses it, so the app states the limit enforced.
  aiDailyTurnLimit: parseBoundedInteger(
    Deno.env.get("AI_DAILY_REQUEST_LIMIT"),
    20,
    1,
    500,
  ),
  async authenticate(token) {
    const { data, error } = await admin().auth.getUser(token);
    // An unknown anonymity flag is treated as anonymous: it cannot buy.
    return error || !data.user
      ? null
      : { id: data.user.id, anonymous: data.user.is_anonymous ?? true };
  },
  async snapshot(userId) {
    const { data, error } = await admin().rpc("get_monetization_snapshot", {
      p_user: userId,
    });
    if (error) throw new Error("Snapshot query failed");
    return data;
  },
  async sign(payload) {
    const raw = Deno.env.get("MONETIZATION_SNAPSHOT_PRIVATE_JWK");
    const kid = Deno.env.get("MONETIZATION_SNAPSHOT_KEY_ID");
    if (!raw || !kid) throw new Error("Snapshot signer is not configured");
    return (await createSnapshotSigner(JSON.parse(raw), kid))(payload);
  },
  billing: billingConfigured
    ? () => {
      billing ??= createBilling(
        (name) => Deno.env.get(name) as string,
        admin,
      ).catch((error) => {
        billing = null;
        throw error;
      });
      return billing;
    }
    : undefined,
  referrals: () => Promise.resolve(referrals),
  legacy: {
    async status(user) {
      const { data, error } = await admin().rpc("legacy_claim_status", {
        p_user: user,
      });
      if (error) throw new Error("legacy_claim_status failed");
      return data;
    },
    async claim(user, migration, completed, attempted, reviewThreshold) {
      const { data, error } = await admin().rpc("submit_legacy_claim", {
        p_user: user,
        p_migration: migration,
        p_completed: completed,
        p_attempted: attempted,
        p_review_threshold: reviewThreshold,
      });
      if (error) throw new Error("submit_legacy_claim failed");
      return data;
    },
    reviewThreshold: parseBoundedInteger(
      Deno.env.get("LEGACY_CLAIM_REVIEW_UNITS"),
      3,
      0,
      31,
    ),
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
