import { assertEquals, assertNotEquals } from "jsr:@std/assert@1.0.14";
import {
  handlePaidChat,
  isRequestUuid,
  type PaidChatDeps,
  type PaidChatRequest,
  type PaidChatStore,
  payloadDigest,
  type ProviderResult,
  type Reservation,
} from "./paid_chat.ts";

const request: PaidChatRequest = {
  user: "00000000-0000-4000-8000-000000000001",
  requestId: "6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b",
  sessionId: "0a1b2c3d-4e5f-4a6b-8c7d-8e9f0a1b2c3d",
  operation: "conversation",
  context: { level: "a1", scenario_id: "restaurant" },
  messages: [{ role: "user", content: "Dám si kávu." }],
};

const reply: ProviderResult = {
  kind: "reply",
  body: { content: "{}", input_tokens: 100, output_tokens: 50, model: "m" },
  inputTokens: 100,
  outputTokens: 50,
};

function setup(options: {
  reservation?: Reservation;
  provider?: ProviderResult;
  access?: boolean;
  paidChatRequired?: boolean;
  completeThrows?: boolean;
  sealed?: string;
} = {}) {
  const calls: string[] = [];
  const store: PaidChatStore = {
    hasAccess: () => {
      calls.push("access");
      return Promise.resolve(options.access ?? true);
    },
    reserve: (args) => {
      calls.push(`reserve:${args.operation}`);
      return Promise.resolve(
        options.reservation ?? { outcome: "reserved", remaining: 7 },
      );
    },
    complete: (_user, _request, usage, sealed) => {
      calls.push(`complete:${usage.costMicros}:${sealed.slice(0, 7)}`);
      if (options.completeThrows) return Promise.reject(new Error("db"));
      return Promise.resolve(true);
    },
    release: (_user, _request, cost) => {
      calls.push(`release:${cost}`);
      return Promise.resolve(true);
    },
    abandon: () => {
      calls.push("abandon");
      return Promise.resolve(true);
    },
  };
  const logged: string[] = [];
  const deps: PaidChatDeps = {
    store,
    cipher: {
      encrypt: (value) => Promise.resolve(`sealed:${value}`),
      decrypt: (sealed) =>
        sealed.startsWith("sealed:")
          ? Promise.resolve(sealed.slice(7))
          : Promise.reject(new Error("bad")),
    },
    callProvider: () => {
      calls.push("provider");
      return Promise.resolve(options.provider ?? reply);
    },
    cost: (input, output) => input + output * 2,
    paidChatRequired: options.paidChatRequired ?? true,
    log: (event) => logged.push(event),
  };
  return { deps, calls, logged };
}

Deno.test("without the AI subscription chat is refused before anything is reserved", async () => {
  const { deps, calls } = setup({ access: false });
  const result = await handlePaidChat(request, deps);
  assertEquals(result, {
    status: 403,
    body: { code: "ai_entitlement_required" },
  });
  assertEquals(calls, ["access"]);
});

Deno.test("before enforcement, requests still reserve and replay without an access check", async () => {
  const { deps, calls } = setup({ access: false, paidChatRequired: false });
  const result = await handlePaidChat(request, deps);
  assertEquals(result.status, 200);
  assertEquals(calls[0], "reserve:conversation");
});

Deno.test("a reserved turn calls the provider once and stores a sealed replay", async () => {
  const { deps, calls } = setup();
  const result = await handlePaidChat(request, deps);
  assertEquals(result.status, 200);
  assertEquals(result.body.remaining_today, 7);
  assertEquals(result.body.request_id, request.requestId);
  assertEquals(calls, [
    "access",
    "reserve:conversation",
    "provider",
    "complete:200:sealed:",
  ]);
});

Deno.test("a summary does not report conversation turns left", async () => {
  const { deps } = setup({
    reservation: { outcome: "reserved", remaining: null },
  });
  const result = await handlePaidChat(
    { ...request, operation: "conversation_summary" },
    deps,
  );
  assertEquals(result.status, 200);
  assertEquals("remaining_today" in result.body, false);
});

Deno.test("a retry replays the stored reply without calling the provider", async () => {
  const { deps, calls } = setup({
    reservation: {
      outcome: "replay",
      replay_sealed: 'sealed:{"content":"{}","remaining_today":3}',
    },
  });
  const result = await handlePaidChat(request, deps);
  assertEquals(result, {
    status: 200,
    body: { content: "{}", remaining_today: 3, replayed: true },
  });
  assertEquals(calls.includes("provider"), false);
});

Deno.test("a replay that cannot be opened is unavailable, never resent", async () => {
  const { deps, calls } = setup({
    reservation: { outcome: "replay", replay_sealed: "garbled" },
  });
  const result = await handlePaidChat(request, deps);
  assertEquals(result, { status: 409, body: { code: "result_unavailable" } });
  assertEquals(calls.includes("provider"), false);
});

Deno.test("every refusal from the reservation has its own code and no provider call", async () => {
  const cases: Array<[Reservation, number, Record<string, unknown>]> = [
    [{ outcome: "in_flight" }, 409, { code: "request_in_progress" }],
    [{ outcome: "result_unavailable" }, 409, { code: "result_unavailable" }],
    [{ outcome: "conflict" }, 409, { code: "idempotency_conflict" }],
    [{ outcome: "summary_not_due" }, 409, { code: "summary_not_due" }],
    [
      { outcome: "quota_exceeded", resets_at: "2026-09-22T00:00:00Z" },
      429,
      { code: "quota_exceeded", resets_at: "2026-09-22T00:00:00Z" },
    ],
  ];
  for (const [reservation, status, body] of cases) {
    const { deps, calls } = setup({ reservation });
    const result = await handlePaidChat(request, deps);
    assertEquals(result.status, status, reservation.outcome);
    assertEquals(result.body, body);
    assertEquals(calls.includes("provider"), false);
  }
  const { deps } = setup({ reservation: { outcome: "in_flight" } });
  assertEquals((await handlePaidChat(request, deps)).headers, {
    "Retry-After": "5",
  });
});

Deno.test("an unknown provider outcome keeps the allowance spent and is not refunded", async () => {
  const { deps, calls } = setup({ provider: { kind: "unknown" } });
  const result = await handlePaidChat(request, deps);
  assertEquals(result, { status: 504, body: { code: "result_unavailable" } });
  assertEquals(calls.slice(-2), ["provider", "abandon"]);
  assertEquals(calls.some((c) => c.startsWith("release")), false);
});

Deno.test("a definite provider failure refunds the learner and records what it cost", async () => {
  const { deps, calls } = setup({
    provider: { kind: "failed", status: 502, inputTokens: 10, outputTokens: 5 },
  });
  const result = await handlePaidChat(request, deps);
  assertEquals(result, {
    status: 502,
    body: { code: "ai_temporarily_unavailable" },
  });
  assertEquals(calls.at(-1), "release:20");
});

Deno.test("a reply is still returned when storing it fails", async () => {
  const { deps, logged } = setup({ completeThrows: true });
  const result = await handlePaidChat(request, deps);
  assertEquals(result.status, 200);
  assertEquals(logged, ["ai_request_completion_failed"]);
});

Deno.test("the payload digest ignores context order and binds the messages", async () => {
  const same = await payloadDigest({
    ...request,
    context: { scenario_id: "restaurant", level: "a1" },
  });
  assertEquals(same, await payloadDigest(request));
  assertNotEquals(
    await payloadDigest({
      ...request,
      messages: [{ role: "user", content: "Dám si čaj." }],
    }),
    same,
  );
  assertNotEquals(
    await payloadDigest({ ...request, operation: "conversation_summary" }),
    same,
  );
});

Deno.test("request IDs must be lowercase UUIDs", () => {
  assertEquals(isRequestUuid(request.requestId), true);
  assertEquals(isRequestUuid(request.requestId.toUpperCase()), false);
  assertEquals(isRequestUuid("not-a-uuid"), false);
  assertEquals(isRequestUuid(42), false);
});
