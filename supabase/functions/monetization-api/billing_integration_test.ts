// End-to-end purchase verification against a local Supabase stack: the real
// handler, RPC wiring, Auth and database, with only Google Play faked.
// Skipped unless pointed at a local stack, e.g.:
//
//   supabase start && supabase db reset
//   BILLING_INTEGRATION_URL=http://127.0.0.1:54321 \
//   BILLING_INTEGRATION_ANON_KEY=... BILLING_INTEGRATION_SERVICE_KEY=... \
//   deno test --allow-env --allow-net supabase/functions/monetization-api/billing_integration_test.ts
//
// Never point it at a hosted project: it enables products and creates users.

import { assertEquals } from "jsr:@std/assert@1";
import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import {
  createBilling,
  recordPlayNotification,
  workerQueries,
} from "../_shared/monetization/billing_rpc.ts";
import { createHandler as createNotificationHandler } from "../play-billing-notifications/handler.ts";
import { createHandler as createWorkerHandler } from "../monetization-worker/handler.ts";
import { createHandler } from "./handler.ts";
import { deriveObfuscatedAccountId } from "../_shared/monetization/billing_crypto.ts";
import type { PlayClient } from "../_shared/monetization/play_client.ts";

const url = Deno.env.get("BILLING_INTEGRATION_URL") ?? "";
const anonKey = Deno.env.get("BILLING_INTEGRATION_ANON_KEY") ?? "";
const serviceKey = Deno.env.get("BILLING_INTEGRATION_SERVICE_KEY") ?? "";
const local = /^http:\/\/(127\.0\.0\.1|localhost|host\.docker\.internal):54321$/
  .test(url);

const key = (fill: number) =>
  btoa(String.fromCharCode(...new Uint8Array(32).fill(fill)));
const env: Record<string, string> = {
  MONETIZATION_TOKEN_KEY: key(3),
  BILLING_ACCOUNT_HMAC_KEY: key(5),
  BILLING_ACCOUNT_HMAC_VERSION: "1",
  PLAY_PACKAGE_NAME: "com.czechify.app",
  PLAY_SERVICE_ACCOUNT_JSON: "{}",
};

Deno.test({
  name: "a linked account buys Core; another account cannot reuse the token",
  ignore: !local || !anonKey || !serviceKey,
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const admin = () =>
      createClient(url, serviceKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
    const service = admin();
    const created: string[] = [];
    async function linkedUser(): Promise<{ id: string; token: string }> {
      const email = `billing-${crypto.randomUUID()}@example.com`;
      const { data, error } = await service.auth.admin.createUser({
        email,
        password: "integration-password",
        email_confirm: true,
      });
      if (error) throw error;
      created.push(data.user.id);
      const client = createClient(url, anonKey, {
        auth: { persistSession: false },
      });
      const session = await client.auth.signInWithPassword({
        email,
        password: "integration-password",
      });
      if (session.error) throw session.error;
      return { id: data.user.id, token: session.data.session.access_token };
    }

    const buyer = await linkedUser();
    const other = await linkedUser();
    const binding = await deriveObfuscatedAccountId(
      env.BILLING_ACCOUNT_HMAC_KEY,
      buyer.id,
    );
    const acknowledged: string[] = [];
    let playState = "SUBSCRIPTION_STATE_ACTIVE";
    const play: PlayClient = {
      getSubscription: (productId, token) => {
        const body = {
          subscriptionState: playState,
          acknowledgementState: acknowledged.length > 0
            ? "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
            : "ACKNOWLEDGEMENT_STATE_PENDING",
          externalAccountIdentifiers: { obfuscatedExternalAccountId: binding },
          lineItems: [{
            productId,
            expiryTime: new Date(Date.now() + 30 * 86400_000).toISOString(),
            offerDetails: { basePlanId: "monthly" },
          }],
        };
        assertEquals(token, "integration-play-token");
        return Promise.resolve({ body, text: JSON.stringify(body) });
      },
      acknowledge: (_productId, token) => {
        acknowledged.push(token);
        return Promise.resolve();
      },
    };
    const billing = await createBilling((name) => env[name], admin, play);
    const handle = createHandler({
      async authenticate(token) {
        const { data, error } = await service.auth.getUser(token);
        return error || !data.user
          ? null
          : { id: data.user.id, anonymous: data.user.is_anonymous ?? true };
      },
      snapshot: () => Promise.resolve(null),
      sign: () => Promise.resolve(""),
      billing: () => Promise.resolve(billing),
    });
    const post = (path: string, token: string, body: unknown) =>
      handle(
        new Request(`${url}/functions/v1/monetization-api/${path}`, {
          method: "POST",
          headers: {
            authorization: `Bearer ${token}`,
            "Idempotency-Key": crypto.randomUUID(),
          },
          body: JSON.stringify(body),
        }),
      );

    try {
      for (const product of ["czechify_core", "czechify_ai"]) {
        const { error } = await service.rpc("set_billing_product_enabled", {
          p_product: product,
          p_enabled: true,
        });
        if (error) throw error;
      }

      const intent = await post("purchase-intents", buyer.token, {
        product_id: "czechify_core",
        base_plan_id: "monthly",
        platform: "android",
      });
      const intentBody = await intent.json();
      assertEquals(intent.status, 201);
      assertEquals(intentBody.obfuscated_account_id, binding);

      const verify = await post("purchases/verify", buyer.token, {
        purchase_token: "integration-play-token",
        product_id: "czechify_core",
        source: "purchase",
        intent_id: intentBody.intent_id,
      });
      const verified = await verify.json();
      assertEquals(verify.status, 200);
      assertEquals([verified.status, verified.state, verified.access], [
        "provisioned",
        "active",
        true,
      ]);
      assertEquals(acknowledged, ["integration-play-token"]);

      const snapshot = await service.rpc("get_monetization_snapshot", {
        p_user: buyer.id,
      });
      assertEquals(snapshot.data.features.core.state, "active");
      assertEquals(snapshot.data.features.ai_chat.state, "inactive");

      const status = await handle(
        new Request(
          `${url}/functions/v1/monetization-api/purchases/status/${verified.verification_id}`,
          { headers: { authorization: `Bearer ${buyer.token}` } },
        ),
      );
      assertEquals((await status.json()).verification, "verified");

      // Play reports a cancellation: intake queues a refresh, the worker
      // re-reads Play, and access continues to the paid-through time.
      playState = "SUBSCRIPTION_STATE_CANCELED";
      const notify = createNotificationHandler({
        authenticate: () => Promise.resolve(true),
        packageName: env.PLAY_PACKAGE_NAME,
        record: recordPlayNotification(admin),
        log: () => {},
      });
      const message = {
        subscription: "projects/local/subscriptions/play",
        message: {
          messageId: crypto.randomUUID(),
          data: btoa(JSON.stringify({
            packageName: env.PLAY_PACKAGE_NAME,
            subscriptionNotification: {
              notificationType: 3,
              purchaseToken: "integration-play-token",
            },
          })),
        },
      };
      const pushed = () =>
        notify(
          new Request(`${url}/functions/v1/play-billing-notifications`, {
            method: "POST",
            body: JSON.stringify(message),
          }),
        );
      assertEquals((await pushed()).status, 204);
      assertEquals((await pushed()).status, 204, "redelivery is acknowledged");

      const workerSecret = "w".repeat(40);
      const worker = createWorkerHandler({
        secret: workerSecret,
        billing: {
          jobs: () => Promise.resolve(billing.jobs),
          ...workerQueries(admin),
        },
        log: () => {},
      });
      const run = await worker(
        new Request(`${url}/functions/v1/monetization-worker`, {
          method: "POST",
          headers: { "x-worker-secret": workerSecret },
        }),
      );
      const ran = await run.json();
      assertEquals(run.status, 200);
      assertEquals(ran.outcomes.provisioned >= 1, true);
      assertEquals(ran.outcomes.retry, undefined);
      const after = await handle(
        new Request(
          `${url}/functions/v1/monetization-api/purchases/status/${verified.verification_id}`,
          { headers: { authorization: `Bearer ${buyer.token}` } },
        ),
      );
      assertEquals((await after.json()).state, "canceled");
      const stillPaid = await service.rpc("get_monetization_snapshot", {
        p_user: buyer.id,
      });
      assertEquals(stillPaid.data.features.core.state, "active");

      const stolen = await post("purchases/verify", other.token, {
        purchase_token: "integration-play-token",
        product_id: "czechify_core",
        source: "restore",
      });
      assertEquals(stolen.status, 403);
      assertEquals((await stolen.json()).code, "account_binding_mismatch");

      const anonymous = await createClient(url, anonKey, {
        auth: { persistSession: false },
      }).auth.signInAnonymously();
      if (anonymous.error) throw anonymous.error;
      created.push(anonymous.data.user!.id);
      const refused = await post(
        "purchase-intents",
        anonymous.data.session!.access_token,
        {
          product_id: "czechify_core",
          base_plan_id: "monthly",
          platform: "android",
        },
      );
      assertEquals(refused.status, 403);
      assertEquals((await refused.json()).code, "linked_account_required");
    } finally {
      for (const product of ["czechify_core", "czechify_ai"]) {
        await service.rpc("set_billing_product_enabled", {
          p_product: product,
          p_enabled: false,
        });
      }
      for (const id of created) await service.auth.admin.deleteUser(id);
    }
  },
});
