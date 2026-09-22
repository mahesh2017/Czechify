import { assertEquals } from "jsr:@std/assert@1";
import { GoogleApiError } from "../_shared/monetization/google_auth.ts";
import {
  IntegrityRejected,
  type IntegrityVerifier,
} from "../_shared/monetization/play_integrity.ts";
import {
  integrityRequestHash,
  normalizeReceipt,
  receiptDigest,
} from "../_shared/monetization/referral_receipt.ts";
import { createHandler } from "./handler.ts";
import type { ReferralDependencies } from "./referrals.ts";
import fixture from "../../../test/fixtures/monetization/referral_receipt.v1.json" with {
  type: "json",
};

const user = "7a4e2c90-1f3b-4d6a-8b5c-9e0d1f2a3b4c";
const nonce = "9".repeat(64);
type Json = Record<string, unknown>;

function setup(options: {
  anonymous?: boolean;
  deps?: Partial<ReferralDependencies>;
  integrity?: IntegrityVerifier | null;
  referrals?: boolean;
  cohort?: boolean;
} = {}) {
  const log: string[] = [];
  const verified: IntegrityVerifier = {
    verify: (token, hash) => {
      log.push(`integrity:${token}:${hash}`);
      return Promise.resolve("verified");
    },
  };
  const deps: ReferralDependencies = {
    code: (actor) => {
      log.push(`code:${actor}`);
      return Promise.resolve({ referral_code: "ABCDEF0123456789ABCDEF01" });
    },
    claim: (actor, campaign, code) => {
      log.push(`claim:${actor}:${campaign}:${code}`);
      return Promise.resolve({ claim_id: "c", status: "claimed" });
    },
    challenge: (actor, claim, digest) => {
      log.push(`challenge:${actor}:${claim}:${digest}`);
      return Promise.resolve({ nonce, expires_at: "later" });
    },
    findReceipt: () => Promise.resolve(null),
    submit: (actor, claim, n, _receipt, digest, verdict) => {
      log.push(`submit:${actor}:${claim}:${n}:${digest}:${verdict}`);
      return Promise.resolve({ receipt_id: "r", status: "accepted" });
    },
    status: (actor, after, limit) => {
      log.push(`status:${actor}:${after}:${limit}`);
      return Promise.resolve({ units_earned: 1 });
    },
    integrity: options.integrity === undefined ? verified : options.integrity,
    ...options.deps,
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
    referrals: options.referrals === false
      ? undefined
      : () => Promise.resolve(deps),
    rollout: () => Promise.resolve({ referral_claims: options.cohort ?? true }),
  });
  return { handle, log };
}
const post = (path: string, body: unknown) =>
  new Request(`https://example.com/functions/v1/monetization-api/${path}`, {
    method: "POST",
    headers: { authorization: "Bearer valid" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
const get = (path: string) =>
  new Request(`https://example.com/functions/v1/monetization-api/${path}`, {
    headers: { authorization: "Bearer valid" },
  });
const receiptBody = (extra: Json = { integrity_token: "tok" }) => ({
  receipt: fixture.receipt_as_sent,
  nonce,
  ...extra,
});

Deno.test("the account always comes from the token, never the body", async () => {
  const { handle, log } = setup();
  assertEquals(
    (await handle(post("referrals/code", { campaign_id: "a1-referral-v1" })))
      .status,
    200,
  );
  assertEquals(
    (await handle(post("referrals/code", {
      campaign_id: "a1-referral-v1",
      user_id: "someone-else",
    }))).status,
    400,
  );
  assertEquals(log, [`code:${user}`]);
});

Deno.test("an anonymous invitee can claim; unknown sources are refused", async () => {
  const { handle, log } = setup({ anonymous: true });
  const claim = {
    campaign_id: "a1-referral-v1",
    code: "abc",
    attribution_source: "manual",
  };
  const created = await handle(post("referrals/claim", claim));
  assertEquals(created.status, 201);
  assertEquals((await created.json()).required_units, [1, 2]);
  assertEquals(
    (await handle(
      post("referrals/claim", { ...claim, attribution_source: "app_link" }),
    )).status,
    400,
  );
  assertEquals(log, [`claim:${user}:a1-referral-v1:abc`]);
});

Deno.test("database refusals map to stable codes", async () => {
  const cases: [string, number][] = [
    ["referral_already_claimed", 409],
    ["referral_ineligible", 422],
    ["campaign_unavailable", 409],
    ["rate_limited", 429],
    ["linked_account_required", 403],
    ["something_new", 503],
  ];
  for (const [code, status] of cases) {
    const { handle } = setup({
      deps: {
        claim: () => Promise.resolve({ code }),
        code: () => Promise.resolve({ code }),
      },
    });
    const response = await handle(post("referrals/claim", {
      campaign_id: "a1-referral-v1",
      code: "x",
      attribution_source: "manual",
    }));
    assertEquals(response.status, status);
    assertEquals(
      (await response.json()).code,
      status === 503 ? "verification_unavailable" : code,
    );
  }
});

Deno.test("a challenge is issued for a digest", async () => {
  const { handle } = setup();
  const ok = await handle(post("referrals/challenges", {
    claim_id: fixture.receipt_as_sent.claim_id,
    receipt_digest: fixture.receipt_digest,
  }));
  assertEquals(ok.status, 201);
  assertEquals((await ok.json()).nonce, nonce);
  assertEquals(
    (await handle(post("referrals/challenges", {
      claim_id: "x",
      receipt_digest: fixture.receipt_digest,
    }))).status,
    400,
  );
});

Deno.test("a receipt is verified against a hash bound to account, claim and nonce", async () => {
  const { handle, log } = setup();
  const response = await handle(post("referrals/receipts", receiptBody()));
  assertEquals(response.status, 202);
  assertEquals(await response.json().then((b) => b.status), "accepted");
  const digest = await receiptDigest(normalizeReceipt(fixture.receipt_as_sent));
  const hash = await integrityRequestHash({
    account_id: user,
    campaign_id: "a1-referral-v1",
    claim_id: fixture.receipt_as_sent.claim_id,
    nonce,
    receipt_digest: digest,
  });
  assertEquals(log, [
    `integrity:tok:${hash}`,
    `submit:${user}:${fixture.receipt_as_sent.claim_id}:${nonce}:${digest}:verified`,
  ]);
});

Deno.test("a committed receipt answers before any token is checked", async () => {
  const { handle, log } = setup({
    deps: {
      findReceipt: () =>
        Promise.resolve({ receipt_id: "old", status: "accepted" }),
    },
  });
  const response = await handle(post("referrals/receipts", receiptBody()));
  assertEquals(response.status, 202);
  assertEquals((await response.json()).receipt_id, "old");
  assertEquals(log, []);
});

Deno.test("a token for another request is refused and nothing is stored", async () => {
  const { handle, log } = setup({
    integrity: { verify: () => Promise.reject(new IntegrityRejected("hash")) },
  });
  const response = await handle(post("referrals/receipts", receiptBody()));
  assertEquals(response.status, 403);
  assertEquals((await response.json()).code, "integrity_rejected");
  assertEquals(log.some((l) => l.startsWith("submit")), false);
});

Deno.test("a Play outage or missing Integrity setup is retryable", async () => {
  const down = setup({
    integrity: {
      verify: () => Promise.reject(new GoogleApiError("down", true)),
    },
  });
  assertEquals(
    (await down.handle(post("referrals/receipts", receiptBody()))).status,
    503,
  );
  const off = setup({ integrity: null });
  assertEquals(
    (await off.handle(post("referrals/receipts", receiptBody()))).status,
    503,
  );
});

Deno.test("a device without Integrity takes the review route", async () => {
  const { handle, log } = setup({ integrity: null });
  const response = await handle(
    post("referrals/receipts", receiptBody({ integrity_unavailable: true })),
  );
  assertEquals(response.status, 202);
  assertEquals(log.at(-1)!.endsWith(":needs_review"), true);
});

Deno.test("malformed receipt requests are refused before any work", async () => {
  const { handle, log } = setup();
  const bad: unknown[] = [
    receiptBody({}),
    receiptBody({ integrity_token: "t", integrity_unavailable: true }),
    receiptBody({ integrity_unavailable: false }),
    { ...receiptBody(), nonce: "short" },
    { ...receiptBody(), verdict: "verified" },
  ];
  for (const body of bad) {
    assertEquals((await handle(post("referrals/receipts", body))).status, 400);
  }
  assertEquals(
    (await handle(post("referrals/receipts", {
      ...receiptBody(),
      receipt: { ...fixture.receipt_as_sent, lesson_id: 1.5 },
    }))).status,
    422,
  );
  assertEquals(log, []);
});

Deno.test("status pages take a cursor; other routes take no parameters", async () => {
  const { handle, log } = setup();
  assertEquals(
    (await handle(get("referrals/status?cursor=20&limit=10"))).status,
    200,
  );
  assertEquals(
    (await handle(get("referrals/status?limit=500"))).status,
    400,
  );
  assertEquals(
    (await handle(get("referrals/status?account=x"))).status,
    400,
  );
  assertEquals(
    (await handle(get("entitlements?cursor=1"))).status,
    400,
  );
  assertEquals(log, [`status:${user}:20:10`]);
});

Deno.test("without referral wiring the routes answer 503", async () => {
  const { handle } = setup({ referrals: false });
  assertEquals((await handle(get("referrals/status"))).status, 503);
});

Deno.test("new codes and claims need the cohort; status and evidence do not", async () => {
  const { handle, log } = setup({ cohort: false });
  for (
    const [path, body] of [
      ["referrals/code", { campaign_id: "a1-referral-v1" }],
      ["referrals/claim", {
        campaign_id: "a1-referral-v1",
        code: "ABCDEF0123456789ABCDEF01",
        attribution_source: "manual",
      }],
    ] as const
  ) {
    const response = await handle(post(path, body));
    assertEquals(response.status, 409);
    assertEquals((await response.json()).code, "campaign_unavailable");
  }
  assertEquals((await handle(get("referrals/status"))).status, 200);
  assertEquals(log, [`status:${user}:0:20`]);
});
