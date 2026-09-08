import { assertEquals, assertNotEquals } from "jsr:@std/assert@1.0.14";
import { handleRequest } from "./handler.ts";
import {
  buildUpstreamRequest,
  type Operation,
  satisfiesReply,
  satisfiesResponseFormat,
} from "./request_policy.ts";

const cases: Array<{
  operation: Operation;
  context: Record<string, string>;
  field: string;
  reply: Record<string, unknown>;
}> = [
  {
    operation: "conversation",
    context: { level: "a1", scenario_id: "restaurant" },
    field: "tutor_reply_cz",
    reply: {
      tutor_reply_cz: "Dobrý den! Co si dáte?",
      tutor_reply_en: "Hello! What would you like?",
      corrections: [],
      new_vocabulary: [],
      suggested_replies: [],
    },
  },
  {
    operation: "conversation_summary",
    context: { level: "a1" },
    field: "summary",
    reply: { summary: "The learner ordered a coffee." },
  },
  {
    operation: "grammar_check",
    context: { level: "a1" },
    field: "corrected_text",
    reply: { corrected_text: "Dám si kávu.", errors: [] },
  },
  {
    operation: "writing_evaluation",
    context: { level: "a1", task_description: "Order a coffee." },
    field: "feedback",
    reply: {
      feedback: "Good use of the accusative.",
      score: { grammar: 80, vocabulary: 80, coherence: 80, overall: 80 },
      errors: [],
    },
  },
];

for (const sample of cases) {
  Deno.test(`${sample.operation}: validation rejects blanks without changing provider schema`, () => {
    const request = buildUpstreamRequest(sample.operation, sample.context, [{
      role: "user",
      content: "Dám si kávu.",
    }])!;
    assertNotEquals(
      request.validationSchema,
      request.responseFormat.json_schema.schema,
    );
    const before = JSON.stringify(request.responseFormat);
    for (const blank of ["", " ", "\n\t", "\u00a0\u2003"]) {
      const reply = { ...sample.reply, [sample.field]: blank };
      assertEquals(
        satisfiesResponseFormat(request.responseFormat, reply),
        true,
      );
      assertEquals(satisfiesReply(request, reply), false);
    }
    // Do not impose a multi-character grammar or arbitrary minimum on Czech.
    assertEquals(
      satisfiesReply(request, { ...sample.reply, [sample.field]: "Č" }),
      true,
    );
    assertEquals(satisfiesReply(request, sample.reply), true);
    assertEquals(JSON.stringify(request.responseFormat), before);
  });
}

Deno.test("proxy rejects blank replies, refunds each operation and sends only the wire schema", async () => {
  const env = {
    SUPABASE_URL: "https://backend.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "test-service-role",
    SCALEWAY_API_KEY: "test-provider-key",
    SCALEWAY_CHAT_COMPLETIONS_URL: "https://provider.invalid/chat",
  };
  const previous = Object.fromEntries(
    Object.keys(env).map((key) => [key, Deno.env.get(key)]),
  );
  const originalFetch = globalThis.fetch;
  let response: Record<string, unknown> = {};
  let sent: Record<string, unknown> = {};
  const calls: string[] = [];
  const json = (value: unknown) =>
    new Response(JSON.stringify(value), {
      headers: { "Content-Type": "application/json" },
    });
  try {
    for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
    // Not `async`: nothing here awaits, and a real fetch signals failure by
    // rejecting rather than throwing at the call site.
    globalThis.fetch = (input, init) => {
      const url = new URL(input instanceof Request ? input.url : String(input));
      calls.push(url.pathname);
      if (url.hostname === "provider.invalid") {
        sent = JSON.parse(String(init?.body));
        return Promise.resolve(json({
          choices: [{ message: { content: JSON.stringify(response) } }],
          usage: {},
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
        return Promise.resolve(json(true));
      }
      if (url.pathname === "/rest/v1/ai_daily_usage") {
        return Promise.resolve(json({ request_count: 1 }));
      }
      return Promise.reject(
        new Error(`Unexpected HTTP request ${url.pathname}`),
      );
    };
    for (const sample of cases) {
      for (const blank of [true, false]) {
        calls.length = 0;
        response = {
          ...sample.reply,
          ...(blank ? { [sample.field]: " \n\t" } : {}),
        };
        const result = await handleRequest(
          new Request("https://proxy.invalid", {
            method: "POST",
            headers: {
              Authorization: "Bearer test-user",
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              operation: sample.operation,
              context: sample.context,
              messages: [{ role: "user", content: "Dám si kávu." }],
            }),
          }),
        );
        assertEquals(result.status, blank ? 502 : 200, sample.operation);
        const refunds = calls.filter((path) => path.includes("/refund_"));
        assertEquals(
          refunds,
          blank
            ? [
              sample.operation === "conversation_summary"
                ? "/rest/v1/rpc/refund_ai_summary_quota"
                : "/rest/v1/rpc/refund_ai_daily_quota",
            ]
            : [],
        );
        assertEquals("validationSchema" in sent, false);
        const wire = JSON.stringify(sent.response_format);
        for (const keyword of ["minLength", "maxLength", "pattern", "format"]) {
          assertEquals(wire.includes(`"${keyword}":`), false);
        }
        await result.body?.cancel();
      }
    }
  } finally {
    globalThis.fetch = originalFetch;
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
});
