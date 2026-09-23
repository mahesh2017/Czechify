import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import { createHandler } from "./handler.ts";
import { createSnapshotSigner } from "./signing.ts";

Deno.serve(createHandler({
  async authenticate(token) {
    const { data, error } = await admin().auth.getUser(token);
    return error || !data.user ? null : { id: data.user.id };
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
}));

function admin() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Backend is not configured");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
