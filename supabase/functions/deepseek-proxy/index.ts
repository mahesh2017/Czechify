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

const SCALEWAY_MODEL = Deno.env.get("SCALEWAY_MODEL") ??
  "deepseek-v4-flash-0731";

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
  const scalewayKey = Deno.env.get("SCALEWAY_API_KEY");
  const scalewayChatUrl = Deno.env.get("SCALEWAY_CHAT_COMPLETIONS_URL");
  if (!supabaseUrl || !serviceRoleKey || !scalewayKey || !scalewayChatUrl) {
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
    operation !== "conversation" && operation !== "conversation_summary" &&
    operation !== "grammar_check" && operation !== "writing_evaluation"
  ) {
    return jsonResponse({ error: "Unsupported AI operation." }, 400);
  }

  // conversation_summary is machinery, not a turn: the client issues it to
  // compress history the learner never asked to lose. Charging their daily
  // allowance for it would mean a long conversation quietly costs double, so
  // it is exempt from the daily cap. It still passes the burst limits below,
  // which is what protects the project from a client looping on it.
  const consumesDailyAllowance = operation !== "conversation_summary";
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
  if (consumesDailyAllowance) {
    const { data: allowed, error: quotaError } = await admin.rpc(
      "consume_ai_quota",
      { p_user_id: userData.user.id, p_daily_limit: dailyLimit },
    );
    if (quotaError) {
      console.error("Quota check failed", quotaError.code);
      return jsonResponse(
        { error: "AI tutor is temporarily unavailable." },
        503,
      );
    }
    if (!allowed) {
      return jsonResponse(
        { error: "Daily AI tutor limit reached. Try again tomorrow." },
        429,
      );
    }
  }

  // How many turns are left today, for the client to show before the learner
  // runs out rather than at the moment they do. A snapshot taken after
  // consumption; a later refund simply makes the next reply's number higher.
  // Read rather than derived because consume_ai_quota returns only a boolean.
  const remainingToday = async (): Promise<number | null> => {
    const { data, error } = await admin
      .from("ai_daily_usage")
      .select("request_count")
      .eq("user_id", userData.user.id)
      .eq("usage_date", new Date().toISOString().slice(0, 10))
      .maybeSingle();
    if (error || !data) return null;
    return Math.max(0, dailyLimit - Number(data.request_count ?? 0));
  };

  // Returns the daily allowance after any failure past the point it was
  // consumed. The burst window is per-minute and heals itself; a daily unit
  // lost to a server-side fault is gone until tomorrow.
  const refundDaily = async () => {
    // Refunding what was never consumed would hand the learner free allowance
    // every time a summary request failed.
    if (!consumesDailyAllowance) return;
    const { error } = await admin.rpc("refund_ai_daily_quota", {
      p_user_id: userData.user.id,
    });
    if (error) console.error("Quota refund failed", error.code);
  };

  let upstream: Response;
  try {
    upstream = await fetch(scalewayChatUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${scalewayKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: SCALEWAY_MODEL,
        messages: upstreamRequest.messages,
        temperature: upstreamRequest.temperature,
        max_tokens: upstreamRequest.maxTokens,
        // DeepSeek V4 Flash otherwise spends its output budget on hidden
        // reasoning and can leave the user-facing structured reply empty.
        reasoning_effort: "none",
        response_format: upstreamRequest.responseFormat,
      }),
      signal: AbortSignal.timeout(60_000),
    });
  } catch (error) {
    console.error(
      "Scaleway request failed",
      error instanceof Error ? error.name : "unknown",
    );
    await refundDaily();
    return jsonResponse({ error: "AI tutor request timed out." }, 504);
  }

  const upstreamBody = await upstream.json().catch(() => null);
  if (!upstream.ok) {
    console.error("Scaleway error", upstream.status);
    await refundDaily();
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
    // A 200 carrying nothing usable is still a failed turn from the learner's
    // side, so it is refunded like any other.
    await refundDaily();
    return jsonResponse(
      { error: "AI tutor returned an invalid response." },
      502,
    );
  }
  try {
    JSON.parse(content);
  } catch (_) {
    // The app consumes typed JSON contracts. A syntactically invalid answer
    // is not a successful learner turn even if the provider returned 200.
    await refundDaily();
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
    model: String(upstreamBody.model ?? SCALEWAY_MODEL),
    remaining_today: await remainingToday(),
    daily_limit: dailyLimit,
  });
});
