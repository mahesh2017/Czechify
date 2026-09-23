import { assertEquals } from "jsr:@std/assert@1";
import { createHandler } from "./handler.ts";
import type { LegacyDependencies } from "./legacy.ts";

const user = "7a4e2c90-1f3b-4d6a-8b5c-9e0d1f2a3b4c";
type Json = Record<string, unknown>;

const applied: Json = {
  available: true,
  migration_id: "t0-2026-11-01",
  cutoff_at: "2026-11-01T00:00:00+00:00",
  grace_ends_at: "2026-12-01T00:00:00+00:00",
  claim_window_ends_at: "2026-12-01T00:00:00+00:00",
  eligible: true,
  claim_window_open: true,
  legacy_unit_ids: [1, 2],
  claim: null,
};

function setup(options: {
  status?: Json;
  claim?: Json;
  legacy?: boolean;
  anonymous?: boolean;
} = {}) {
  const log: string[] = [];
  const legacy: LegacyDependencies = {
    status: (u) => {
      log.push(`status:${u}`);
      return Promise.resolve(options.status ?? applied);
    },
    claim: (u, migration, completed, attempted, threshold) => {
      log.push(
        `claim:${u}:${migration}:${completed}:${attempted}:${threshold}`,
      );
      return Promise.resolve(
        options.claim ?? { status: "applied", unit_ids: [3] },
      );
    },
    reviewThreshold: 3,
  };
  const handle = createHandler({
    authenticate: (token) =>
      Promise.resolve(
        token === "valid"
          ? { id: user, anonymous: options.anonymous ?? false }
          : null,
      ),
    snapshot: () => Promise.resolve(null),
    sign: () => Promise.resolve(""),
    legacy: options.legacy === false ? undefined : legacy,
  });
  return { handle, log };
}

const post = (body: unknown) =>
  new Request(
    "https://example.com/functions/v1/monetization-api/legacy/claim",
    {
      method: "POST",
      headers: { authorization: "Bearer valid" },
      body: typeof body === "string" ? body : JSON.stringify(body),
    },
  );
const getStatus = () =>
  new Request(
    "https://example.com/functions/v1/monetization-api/legacy/status",
    { headers: { authorization: "Bearer valid" } },
  );
const claimBody = {
  completed_lesson_ids: [301, 101, 101],
  attempted_lesson_ids: [401],
};

Deno.test("status shows the learner's window and keeps the run ID private", async () => {
  const { handle, log } = setup();
  const response = await handle(getStatus());
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.available, true);
  assertEquals(body.grace_ends_at, "2026-12-01T00:00:00+00:00");
  assertEquals(body.legacy_unit_ids, [1, 2]);
  assertEquals(body.claim, null);
  assertEquals("migration_id" in body, false);
  assertEquals(log, [`status:${user}`]);
});

Deno.test("status before any migration says only that", async () => {
  const { handle } = setup({ status: { available: false } });
  const body = await (await handle(getStatus())).json();
  assertEquals(body.available, false);
  assertEquals("cutoff_at" in body, false);
});

Deno.test("status reports an existing claim", async () => {
  const { handle } = setup({
    status: { ...applied, claim: { status: "needs_review", unit_ids: [3, 4] } },
  });
  const body = await (await handle(getStatus())).json();
  assertEquals(body.claim, { status: "needs_review", unit_ids: [3, 4] });
});

Deno.test("a claim goes to the applied run with the server's threshold", async () => {
  const { handle, log } = setup();
  const response = await handle(post(claimBody));
  assertEquals(response.status, 200);
  assertEquals(await response.json().then((b) => [b.status, b.unit_ids]), [
    "applied",
    [3],
  ]);
  // Deduplicated and sorted; the account and run never come from the body.
  assertEquals(log, [
    `status:${user}`,
    `claim:${user}:t0-2026-11-01:101,301:401:3`,
  ]);
});

Deno.test("an anonymous pre-launch learner can claim too", async () => {
  const { handle } = setup({ anonymous: true });
  assertEquals((await handle(post(claimBody))).status, 200);
});

Deno.test("malformed claims are refused before the database", async () => {
  for (
    const body of [
      "not json",
      [],
      { completed_lesson_ids: [101] },
      { ...claimBody, user_id: user },
      { ...claimBody, migration_id: "other" },
      { ...claimBody, completed_lesson_ids: ["101"] },
      { ...claimBody, completed_lesson_ids: [0] },
      { ...claimBody, completed_lesson_ids: [1.5] },
      { ...claimBody, attempted_lesson_ids: [1000000] },
      { ...claimBody, attempted_lesson_ids: null },
      { ...claimBody, completed_lesson_ids: Array(501).fill(101) },
    ]
  ) {
    const { handle, log } = setup();
    const response = await handle(post(body));
    assertEquals(response.status, 400, JSON.stringify(body).slice(0, 60));
    assertEquals((await response.json()).code, "invalid_request");
    assertEquals(log.filter((l) => l.startsWith("claim")), []);
  }
});

Deno.test("no applied migration means nothing to claim", async () => {
  const { handle, log } = setup({ status: { available: false } });
  const response = await handle(post(claimBody));
  assertEquals(response.status, 409);
  assertEquals((await response.json()).code, "migration_not_ready");
  assertEquals(log, [`status:${user}`]);
});

Deno.test("database refusals keep their codes", async () => {
  for (
    const [code, status] of [
      ["claim_window_closed", 409],
      ["not_eligible", 403],
      ["already_claimed", 409],
      ["migration_not_ready", 409],
      ["something_new", 503],
    ] as const
  ) {
    const { handle } = setup({ claim: { code } });
    const response = await handle(post(claimBody));
    assertEquals(response.status, status, code);
    assertEquals(
      (await response.json()).code,
      code === "something_new" ? "verification_unavailable" : code,
    );
  }
});

Deno.test("review and rejection are answers, not errors", async () => {
  const { handle } = setup({
    claim: { status: "needs_review", unit_ids: [3, 4, 5, 6] },
  });
  const body = await (await handle(post(claimBody))).json();
  assertEquals([body.status, body.unit_ids], ["needs_review", [3, 4, 5, 6]]);
  const rejected = setup({ claim: { status: "rejected" } });
  const empty = await (await rejected.handle(post(claimBody))).json();
  assertEquals([empty.status, empty.unit_ids], ["rejected", []]);
});

Deno.test("routes answer 503 without the database and 405 on the wrong method", async () => {
  const { handle } = setup({ legacy: false });
  assertEquals((await handle(getStatus())).status, 503);
  const wired = setup();
  assertEquals(
    (await wired.handle(
      new Request(
        "https://example.com/functions/v1/monetization-api/legacy/status",
        { method: "POST", headers: { authorization: "Bearer valid" } },
      ),
    )).status,
    405,
  );
});

Deno.test("a database failure is a 503 without detail", async () => {
  const { handle } = setup();
  const failing = createHandler({
    authenticate: () => Promise.resolve({ id: user, anonymous: false }),
    snapshot: () => Promise.resolve(null),
    sign: () => Promise.resolve(""),
    legacy: {
      status: () => Promise.reject(new Error("boom")),
      claim: () => Promise.reject(new Error("boom")),
      reviewThreshold: 3,
    },
  });
  assertEquals((await handle(getStatus())).status, 200);
  const response = await failing(getStatus());
  assertEquals(response.status, 503);
  assertEquals((await response.json()).code, "verification_unavailable");
});
