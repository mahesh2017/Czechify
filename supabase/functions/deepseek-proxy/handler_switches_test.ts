import { assertEquals } from "jsr:@std/assert@1.0.14";
import { handleRequest } from "./handler.ts";

/// The switches in front of every provider call: the emergency stop, the
/// project spend ceiling, and paid-chat enforcement for old clients.

const baseEnv = {
  SUPABASE_URL: "https://backend.invalid",
  SUPABASE_SERVICE_ROLE_KEY: "test-service-role",
  SCALEWAY_API_KEY: "test-provider-key",
  SCALEWAY_CHAT_COMPLETIONS_URL: "https://provider.invalid/chat",
};

const replies: Record<string, Record<string, unknown>> = {
  conversation: {
    tutor_reply_cz: "Dobrý den!",
    tutor_reply_en: "Hello!",
    corrections: [],
    new_vocabulary: [],
    suggested_replies: [],
  },
  grammar_check: { corrected_text: "Dám si kávu.", errors: [] },
};

async function run(
  env: Record<string, string>,
  body: Record<string, unknown>,
  rpc: Record<string, unknown> = {},
) {
  const all = { ...baseEnv, ...env };
  const keys = [
    ...Object.keys(all),
    "AI_PROVIDER_REQUESTS_ENABLED",
    "AI_PAID_CHAT_REQUIRED",
  ];
  const previous = Object.fromEntries(keys.map((k) => [k, Deno.env.get(k)]));
  const originalFetch = globalThis.fetch;
  const calls: string[] = [];
  const json = (value: unknown) =>
    new Response(JSON.stringify(value), {
      headers: { "Content-Type": "application/json" },
    });
  try {
    for (const key of keys) Deno.env.delete(key);
    for (const [key, value] of Object.entries(all)) Deno.env.set(key, value);
    globalThis.fetch = (input) => {
      const url = new URL(input instanceof Request ? input.url : String(input));
      calls.push(url.pathname);
      if (url.hostname === "provider.invalid") {
        return Promise.resolve(json({
          choices: [{
            message: {
              content: JSON.stringify(replies[String(body.operation)]),
            },
          }],
          usage: { prompt_tokens: 10, completion_tokens: 5 },
        }));
      }
      if (url.pathname === "/auth/v1/user") {
        return Promise.resolve(json({
          id: "00000000-0000-4000-8000-000000000001",
          aud: "authenticated",
          role: "authenticated",
          created_at: "2026-09-08T00:00:00Z",
          app_metadata: {},
          user_metadata: {},
        }));
      }
      if (url.pathname.startsWith("/rest/v1/rpc/")) {
        const name = url.pathname.slice("/rest/v1/rpc/".length);
        return Promise.resolve(json(name in rpc ? rpc[name] : true));
      }
      if (url.pathname === "/rest/v1/ai_daily_usage") {
        return Promise.resolve(json({ request_count: 1 }));
      }
      return Promise.reject(new Error(`Unexpected ${url.pathname}`));
    };
    const response = await handleRequest(
      new Request("https://proxy.invalid", {
        method: "POST",
        headers: {
          Authorization: "Bearer test-user",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          context: { level: "a1", scenario_id: "restaurant" },
          messages: [{ role: "user", content: "Dám si kávu." }],
          ...body,
        }),
      }),
    );
    return {
      status: response.status,
      body: await response.json(),
      providerCalled: calls.includes("/chat"),
      calls,
    };
  } finally {
    globalThis.fetch = originalFetch;
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

Deno.test("the emergency switch stops every provider request", async () => {
  for (const operation of ["conversation", "grammar_check"]) {
    const result = await run({ AI_PROVIDER_REQUESTS_ENABLED: "false" }, {
      operation,
    });
    assertEquals(result.status, 503, operation);
    assertEquals(result.body.code, "ai_temporarily_unavailable");
    assertEquals(result.providerCalled, false);
  }
});

Deno.test("at the spend ceiling nothing new reaches the provider", async () => {
  const result = await run({}, { operation: "grammar_check" }, {
    ai_spend_ceiling_reached: { reached: true, newly_tripped: true },
  });
  assertEquals(result.status, 503);
  assertEquals(result.body.code, "ai_temporarily_unavailable");
  assertEquals(result.providerCalled, false);
});

Deno.test("below the ceiling a legacy call records its estimated spend", async () => {
  const result = await run({}, { operation: "grammar_check" }, {
    ai_spend_ceiling_reached: { reached: false },
  });
  assertEquals(result.status, 200);
  assertEquals(result.calls.includes("/rest/v1/rpc/record_ai_spend"), true);
});

Deno.test("with paid chat required, an old client is asked to update", async () => {
  const result = await run({ AI_PAID_CHAT_REQUIRED: "true" }, {
    operation: "conversation",
  });
  assertEquals(result.status, 426);
  assertEquals(result.body.code, "client_update_required");
  assertEquals(result.providerCalled, false);
});

Deno.test("course feedback is not held to the chat subscription", async () => {
  const result = await run({ AI_PAID_CHAT_REQUIRED: "true" }, {
    operation: "grammar_check",
  });
  assertEquals(result.status, 200);
  assertEquals(result.providerCalled, true);
});

Deno.test("a malformed request or session ID is refused", async () => {
  const result = await run({ AI_REPLAY_KEY: "k" }, {
    operation: "conversation",
    request_id: "not-a-uuid",
    session_id: "0a1b2c3d-4e5f-4a6b-8c7d-8e9f0a1b2c3d",
  });
  assertEquals(result.status, 400);
  assertEquals(result.body.code, "invalid_request");
  assertEquals(result.providerCalled, false);
});

Deno.test("a paid chat request without an AI subscription is refused", async () => {
  const result = await run(
    {
      AI_PAID_CHAT_REQUIRED: "true",
      AI_REPLAY_KEY: btoa("k".repeat(32)),
    },
    {
      operation: "conversation",
      request_id: "6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b",
      session_id: "0a1b2c3d-4e5f-4a6b-8c7d-8e9f0a1b2c3d",
    },
    { has_ai_chat_access: false },
  );
  assertEquals(result.status, 403);
  assertEquals(result.body.code, "ai_entitlement_required");
  assertEquals(result.calls.includes("/rest/v1/rpc/reserve_ai_request"), false);
  assertEquals(result.providerCalled, false);
});

Deno.test("a paid chat turn reserves, answers and completes", async () => {
  const result = await run(
    { AI_REPLAY_KEY: btoa("k".repeat(32)) },
    {
      operation: "conversation",
      request_id: "6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b",
      session_id: "0a1b2c3d-4e5f-4a6b-8c7d-8e9f0a1b2c3d",
    },
    { reserve_ai_request: { outcome: "reserved", remaining: 19 } },
  );
  assertEquals(result.status, 200);
  assertEquals(result.body.remaining_today, 19);
  assertEquals(result.body.daily_limit, 20);
  assertEquals(
    result.calls.filter((c) => c.includes("_ai_request")),
    ["/rest/v1/rpc/reserve_ai_request", "/rest/v1/rpc/complete_ai_request"],
  );
});
