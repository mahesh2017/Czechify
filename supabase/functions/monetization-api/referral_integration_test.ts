// End-to-end referral flow against a local Supabase stack: the real routes,
// canonical receipts, RPC wiring, Auth and database, with only Play Integrity
// faked. Skipped unless pointed at a local stack (see the billing
// integration test for the environment variables). Never point it at a
// hosted project: it opens the campaign and creates users.

import { assertEquals } from "jsr:@std/assert@1";
import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import {
  createReferrals,
  referralWorkerQueries,
} from "../_shared/monetization/referral_rpc.ts";
import {
  normalizeReceipt,
  receiptDigest,
} from "../_shared/monetization/referral_receipt.ts";
import { createHandler as createWorkerHandler } from "../monetization-worker/handler.ts";
import { createHandler } from "./handler.ts";
import manifest from "../../../docs/monetization/fixtures/campaign_manifest.v1.json" with {
  type: "json",
};

const url = Deno.env.get("BILLING_INTEGRATION_URL") ?? "";
const anonKey = Deno.env.get("BILLING_INTEGRATION_ANON_KEY") ?? "";
const serviceKey = Deno.env.get("BILLING_INTEGRATION_SERVICE_KEY") ?? "";
const local = /^http:\/\/(127\.0\.0\.1|localhost|host\.docker\.internal):54321$/
  .test(url);

Deno.test({
  name: "two units of a friend's learning earn two permanent units, once",
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
    async function linkedUser() {
      const email = `referral-${crypto.randomUUID()}@example.com`;
      const { data, error } = await service.auth.admin.createUser({
        email,
        password: "integration-password",
        email_confirm: true,
      });
      if (error) throw error;
      created.push(data.user.id);
      const session = await createClient(url, anonKey, {
        auth: { persistSession: false },
      }).auth.signInWithPassword({ email, password: "integration-password" });
      if (session.error) throw session.error;
      return { id: data.user.id, token: session.data.session.access_token };
    }
    // Stands in for Play: checks the hash really binds this request.
    const hashes: string[] = [];
    const referrals = createReferrals(admin, {
      verify: (token, hash) => {
        hashes.push(hash);
        assertEquals(token, "play-integrity-token");
        return Promise.resolve("verified");
      },
    });
    const handle = createHandler({
      async authenticate(token) {
        const { data, error } = await service.auth.getUser(token);
        return error || !data.user
          ? null
          : { id: data.user.id, anonymous: data.user.is_anonymous ?? true };
      },
      snapshot: () => Promise.resolve(null),
      sign: () => Promise.resolve(""),
      // The cohort rules have their own tests; these accounts are in it.
      rollout: () => Promise.resolve({ referral_claims: true }),
      referrals: () => Promise.resolve(referrals),
    });
    const call = async (token: string, path: string, body?: unknown) => {
      const response = await handle(
        new Request(`${url}/functions/v1/monetization-api/${path}`, {
          method: body === undefined ? "GET" : "POST",
          headers: { authorization: `Bearer ${token}` },
          body: body === undefined ? undefined : JSON.stringify(body),
        }),
      );
      return { status: response.status, body: await response.json() };
    };
    const campaign = (enabled: boolean, paused: boolean) =>
      service.rpc("set_referral_campaign", {
        p_campaign: "a1-referral-v1",
        p_enabled: enabled,
        p_processing_paused: paused,
        p_starts_at: enabled ? new Date(Date.now() - 86400_000) : null,
        p_claim_closes_at: enabled ? new Date(Date.now() + 86400_000) : null,
        p_ends_at: enabled ? new Date(Date.now() + 2 * 86400_000) : null,
      });

    try {
      const owner = await linkedUser();
      const friend = await linkedUser();
      assertEquals((await campaign(true, true)).error, null);

      const code = await call(owner.token, "referrals/code", {
        campaign_id: "a1-referral-v1",
      });
      assertEquals(code.status, 200);
      const claim = await call(friend.token, "referrals/claim", {
        campaign_id: "a1-referral-v1",
        code: code.body.referral_code,
        attribution_source: "manual",
      });
      assertEquals(claim.status, 201);
      const claimId = claim.body.claim_id as string;

      const submit = async (
        lesson: (typeof manifest.free_unit_lessons)[0]["lessons"][0],
      ) => {
        const now = new Date().toISOString();
        const receipt = normalizeReceipt({
          schema_version: 1,
          claim_id: claimId,
          campaign_id: "a1-referral-v1",
          content_revision: 25,
          lesson_id: lesson.lesson_id,
          attempt_id: crypto.randomUUID(),
          started_at_client: now,
          completed_at_client: now,
          initial_coverage: lesson.exercise_ids.map((id) => ({
            exercise_id: id,
            interaction: lesson.teaching_exercise_ids.includes(id)
              ? "teaching_acknowledged"
              : "answered_incorrectly",
          })),
        });
        const challenge = await call(friend.token, "referrals/challenges", {
          claim_id: claimId,
          receipt_digest: await receiptDigest(receipt),
        });
        assertEquals(challenge.status, 201);
        const body = {
          receipt,
          nonce: challenge.body.nonce,
          integrity_token: "play-integrity-token",
        };
        const first = await call(friend.token, "referrals/receipts", body);
        assertEquals([first.status, first.body.status], [202, "accepted"]);
        return { body, first };
      };

      const lessons = manifest.free_unit_lessons.flatMap((u) => u.lessons);
      const results = [];
      for (const lesson of lessons) results.push(await submit(lesson));

      // Processing is paused: learning is recorded, rewards wait.
      let status = await call(owner.token, "referrals/status");
      assertEquals(status.body.units_earned, 0);
      assertEquals(
        status.body.friends[0].milestones.map((m: { status: string }) =>
          m.status
        ),
        ["verification_pending", "verification_pending"],
      );

      // Resume: the worker grants both milestones.
      assertEquals((await campaign(true, false)).error, null);
      const workerSecret = "w".repeat(40);
      const run = await createWorkerHandler({
        secret: workerSecret,
        referrals: referralWorkerQueries(admin),
        log: () => {},
      })(
        new Request(`${url}/functions/v1/monetization-worker`, {
          method: "POST",
          headers: { "x-worker-secret": workerSecret },
        }),
      );
      assertEquals((await run.json()).referrals.processed >= 1, true);
      status = await call(owner.token, "referrals/status");
      assertEquals(status.body.units_earned, 2);
      assertEquals(status.body.next_reward_unit, 5);
      assertEquals(
        status.body.friends[0].milestones.map((m: { status: string }) =>
          m.status
        ),
        ["reward_granted", "reward_granted"],
      );
      const grants = await service.rpc("get_monetization_snapshot", {
        p_user: owner.id,
      });
      assertEquals(
        grants.data.permanent_unit_grants.map((g: { unit_id: number }) =>
          g.unit_id
        ),
        [3, 4],
      );

      // A retry of a committed receipt answers from the database, with no
      // new challenge or token check, and grants nothing more.
      const verifiedBefore = hashes.length;
      const replay = await call(
        friend.token,
        "referrals/receipts",
        results[0].body,
      );
      assertEquals(replay.status, 202);
      assertEquals(replay.body.receipt_id, results[0].first.body.receipt_id);
      assertEquals(hashes.length, verifiedBefore);
      assertEquals(
        (await call(owner.token, "referrals/status")).body.units_earned,
        2,
      );

      // The invitee sees their own completed progress.
      const mine = await call(friend.token, "referrals/status");
      assertEquals(mine.body.own_claim.lessons_completed, 8);
    } finally {
      await campaign(false, true);
      for (const id of created) await service.auth.admin.deleteUser(id);
    }
  },
});
