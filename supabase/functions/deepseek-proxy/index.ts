import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import {
  corsHeaders,
  type CorsPolicy,
  parseAllowedOrigins,
  preflightResponse,
} from "../_shared/cors.ts";
import {
  buildUpstreamRequest,
  parseBoundedInteger,
  parseContext,
  parseMessages,
} from "./request_policy.ts";

const CORS: CorsPolicy = {
  allowedOrigins: parseAllowedOrigins(Deno.env.get("ALLOWED_ORIGINS")),
  allowedHeaders: "authorization, apikey, content-type, x-client-info",
  allowedMethods: "POST, OPTIONS",
};

Deno.serve(async (request) => {
  const origin = request.headers.get("Origin");
  if (request.method === "OPTIONS") {
    return preflightResponse(origin, CORS);
  }
  const cors = corsHeaders(origin, CORS);
  const jsonResponse = (
    body: Record<string, unknown>,
    status = 200,
    headers: Record<string, string> = {},
  ) =>
    new Response(JSON.stringify(body), {
      status,
      headers: {
        ...cors,
        "Content-Type": "application/json",
        ...headers,
      },
    });

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Authentication required." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const deepSeekKey = Deno.env.get("DEEPSEEK_API_KEY");
  if (!supabaseUrl || !serviceRoleKey || !deepSeekKey) {
    console.error("Missing required server secrets.");
    return jsonResponse({ error: "AI tutor is not configured." }, 503);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const jwt = authorization.slice("Bearer ".length);
  const { data: userData, error: authError } = await admin.auth.getUser(jwt);
  if (authError || !userData.user) {
    return jsonResponse({ error: "Invalid or expired session." }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON request." }, 400);
  }

  const operation = body.operation;
  if (
    operation !== "conversation" && operation !== "grammar_check" &&
    operation !== "writing_evaluation"
  ) {
    return jsonResponse({ error: "Unsupported AI operation." }, 400);
  }
  const context = parseContext(body.context);
  const messages = parseMessages(body.messages);
  if (!context || !messages) {
    return jsonResponse({ error: "Invalid AI request." }, 400);
  }
  const upstreamRequest = buildUpstreamRequest(operation, context, messages);
  if (!upstreamRequest) {
    return jsonResponse({ error: "Invalid operation context." }, 400);
  }

  const userBurstLimit = parseBoundedInteger(
    Deno.env.get("AI_USER_REQUESTS_PER_MINUTE"),
    5,
    1,
    100,
  );
  const projectBurstLimit = parseBoundedInteger(
    Deno.env.get("AI_PROJECT_REQUESTS_PER_MINUTE"),
    60,
    1,
    5_000,
  );
  const { data: burstAllowed, error: burstError } = await admin.rpc(
    "consume_ai_burst_quota",
    {
      p_user_id: userData.user.id,
      p_user_limit: userBurstLimit,
      p_project_limit: projectBurstLimit,
    },
  );
  if (burstError) {
    console.error("Burst quota check failed", burstError.code);
    return jsonResponse({ error: "AI tutor is temporarily unavailable." }, 503);
  }
  if (!burstAllowed) {
    return jsonResponse(
      { error: "Too many AI tutor requests. Try again shortly." },
      429,
      { "Retry-After": "60" },
    );
  }

  const dailyLimit = parseBoundedInteger(
    Deno.env.get("AI_DAILY_REQUEST_LIMIT"),
    20,
    1,
    500,
  );
  const { data: allowed, error: quotaError } = await admin.rpc(
    "consume_ai_quota",
    { p_user_id: userData.user.id, p_daily_limit: dailyLimit },
  );
  if (quotaError) {
    console.error("Quota check failed", quotaError.code);
    return jsonResponse({ error: "AI tutor is temporarily unavailable." }, 503);
  }
  if (!allowed) {
    return jsonResponse(
      { error: "Daily AI tutor limit reached. Try again tomorrow." },
      429,
    );
  }

  let upstream: Response;
  try {
    upstream = await fetch("https://api.deepseek.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${deepSeekKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: upstreamRequest.messages,
        temperature: upstreamRequest.temperature,
        max_tokens: upstreamRequest.maxTokens,
        response_format: { type: "json_object" },
      }),
      signal: AbortSignal.timeout(60_000),
    });
  } catch (error) {
    console.error(
      "DeepSeek request failed",
      error instanceof Error ? error.name : "unknown",
    );
    return jsonResponse({ error: "AI tutor request timed out." }, 504);
  }

  const upstreamBody = await upstream.json().catch(() => null);
  if (!upstream.ok) {
    console.error("DeepSeek error", upstream.status);
    const status = upstream.status === 429 ? 429 : 502;
    return jsonResponse(
      { error: "AI tutor is temporarily unavailable." },
      status,
    );
  }

  const content = upstreamBody?.choices?.[0]?.message?.content;
  if (
    typeof content !== "string" || content.length < 1 || content.length > 20_000
  ) {
    return jsonResponse(
      { error: "AI tutor returned an invalid response." },
      502,
    );
  }
  const usage = upstreamBody.usage ?? {};
  return jsonResponse({
    content,
    input_tokens: Number(usage.prompt_tokens ?? 0),
    output_tokens: Number(usage.completion_tokens ?? 0),
    model: String(upstreamBody.model ?? "deepseek-chat"),
  });
});
