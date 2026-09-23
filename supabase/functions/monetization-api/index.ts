import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import { type BillingDependencies, createHandler } from "./handler.ts";
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
}));

function admin() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Backend is not configured");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
