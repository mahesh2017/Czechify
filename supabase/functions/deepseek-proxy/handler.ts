import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.110.7";
import {
  corsHeaders,
  type CorsPolicy,
  parseAllowedOrigins,
  preflightResponse,
} from "../_shared/cors.ts";
import { createTokenCipher } from "../_shared/monetization/billing_crypto.ts";
import {
  handlePaidChat,
  isRequestUuid,
  type PaidChatStore,
  type ProviderResult,
  type Reservation,
} from "./paid_chat.ts";

/** A server-known course task, as course_ai_task returns it. */
type CourseTask = {
  task_id: string;
  operation: string;
  level: string;
  task_description: string;
  allowed: boolean;
};
import {
  buildUpstreamRequest,
  parseBoundedInteger,
  parseContext,
  parseMessages,
  satisfiesReply,
  type UpstreamRequest,
} from "./request_policy.ts";

const SCALEWAY_MODEL = Deno.env.get("SCALEWAY_MODEL") ??
  "deepseek-v4-flash-0731";

const CORS: CorsPolicy = {
  allowedOrigins: parseAllowedOrigins(Deno.env.get("ALLOWED_ORIGINS")),
  allowedHeaders: "authorization, apikey, content-type, x-client-info",
  allowedMethods: "POST, OPTIONS",
};

export const handleRequest = async (request: Request): Promise<Response> => {
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
  // allowance for it would mean a long conversation quietly costs double.
  //
  // So it does not spend conversation turns — but it is not unlimited either.
  // It used to be exempt from the daily cap entirely, leaving only a
  // per-minute burst limit between any authenticated caller (an anonymous
  // account included) and the paid model, indefinitely. A per-minute ceiling
  // is not a spending ceiling. Summaries have their own daily counter.
  const isSummary = operation === "conversation_summary";
  const context = parseContext(body.context);
  const messages = parseMessages(body.messages);
  if (!context || !messages) {
    return jsonResponse({ error: "Invalid AI request." }, 400);
  }
  // Course feedback names a server-known task; the server supplies its text
  // and level, so client context cannot become an arbitrary prompt.
  const isCourseOperation = operation === "grammar_check" ||
    operation === "writing_evaluation";
  // A server switch turns each rule on; the account's rollout cohort
  // decides whom it reaches. Asked only when the switch is on.
  let cohort: Record<string, unknown> | null = null;
  const inCohort = async (feature: string) => {
    if (cohort === null) {
      const { data, error } = await admin.rpc("rollout_for", {
        p_user: userData.user.id,
      });
      if (error) throw new CohortUnavailable();
      cohort = (data ?? {}) as Record<string, unknown>;
    }
    return cohort[feature] === true;
  };
  let courseAccessRequired: boolean;
  try {
    courseAccessRequired =
      Deno.env.get("AI_COURSE_ACCESS_REQUIRED") === "true" &&
      isCourseOperation && await inCohort("course_paywall");
  } catch {
    return jsonResponse({ code: "ai_temporarily_unavailable" }, 503);
  }
  let courseTask: CourseTask | null = null;
  let upstreamContext = context;
  if (isCourseOperation && context.task_id !== undefined) {
    const { data: task, error: taskError } = await admin.rpc(
      "course_ai_task",
      { p_user: userData.user.id, p_task: context.task_id },
    );
    if (taskError) {
      console.error("Course task lookup failed", taskError.code);
      return jsonResponse({ code: "ai_temporarily_unavailable" }, 503);
    }
    if (!task || task.operation !== operation) {
      return jsonResponse({ code: "unknown_task" }, 404);
    }
    // One learner answer; nothing else from the client reaches the prompt.
    if (messages.length !== 1 || messages[0].role !== "user") {
      return jsonResponse({ code: "invalid_request" }, 400);
    }
    if (courseAccessRequired && task.allowed !== true) {
      return jsonResponse({ code: "course_access_required" }, 403);
    }
    courseTask = task as CourseTask;
    upstreamContext = {
      level: courseTask.level,
      task_description: courseTask.task_description,
    };
  } else if (isCourseOperation && courseAccessRequired) {
    // Free-form feedback is how a claimed course operation would become an
    // unmetered chat. The app sends task IDs for writing; nothing in it
    // sends grammar_check.
    return operation === "writing_evaluation"
      ? jsonResponse({ code: "client_update_required" }, 426)
      : jsonResponse({ code: "course_task_required" }, 403);
  }
  const upstreamRequest = buildUpstreamRequest(
    operation,
    upstreamContext,
    messages,
  );
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

  // Emergency switch: stops every new provider request, whatever its kind.
  // History stays readable in the app; nothing is charged.
  if (Deno.env.get("AI_PROVIDER_REQUESTS_ENABLED") === "false") {
    return jsonResponse(
      {
        error: "AI tutor is temporarily unavailable.",
        code: "ai_temporarily_unavailable",
      },
      503,
    );
  }
  // Project spend ceiling, estimated from token counts. Reaching it stops new
  // provider requests for the rest of the UTC day and is logged once as an
  // incident.
  const spendCeiling = parseBoundedInteger(
    Deno.env.get("AI_DAILY_SPEND_CEILING_MICROS"),
    20_000_000,
    1,
    1_000_000_000_000,
  );
  {
    const { data: ceiling, error: ceilingError } = await admin.rpc(
      "ai_spend_ceiling_reached",
      { p_ceiling_micros: spendCeiling },
    );
    if (ceilingError) {
      console.error("Spend ceiling check failed", ceilingError.code);
      return jsonResponse(
        {
          error: "AI tutor is temporarily unavailable.",
          code: "ai_temporarily_unavailable",
        },
        503,
      );
    }
    if (ceiling?.reached === true) {
      if (ceiling.newly_tripped === true) {
        console.error("ai_spend_ceiling_tripped", { ceiling: spendCeiling });
      }
      return jsonResponse(
        {
          error: "AI tutor is temporarily unavailable.",
          code: "ai_temporarily_unavailable",
        },
        503,
      );
    }
  }
  const inputPrice = parseBoundedInteger(
    Deno.env.get("AI_INPUT_MICROS_PER_MILLION_TOKENS"),
    300_000,
    0,
    1_000_000_000,
  );
  const outputPrice = parseBoundedInteger(
    Deno.env.get("AI_OUTPUT_MICROS_PER_MILLION_TOKENS"),
    1_200_000,
    0,
    1_000_000_000,
  );
  const cost = (input: number, output: number) =>
    Math.ceil((input * inputPrice + output * outputPrice) / 1_000_000);
  const recordSpend = async (micros: number) => {
    if (micros <= 0) return;
    const { error } = await admin.rpc("record_ai_spend", {
      p_cost_micros: micros,
    });
    if (error) console.error("Spend record failed", error.code);
  };

  const dailyLimit = parseBoundedInteger(
    Deno.env.get("AI_DAILY_REQUEST_LIMIT"),
    20,
    1,
    500,
  );
  // Compression is cheaper than a turn and happens on the client's schedule
  // rather than the learner's, so its ceiling is higher — but it is a ceiling.
  const summaryDailyLimit = parseBoundedInteger(
    Deno.env.get("AI_DAILY_SUMMARY_LIMIT"),
    60,
    1,
    500,
  );

  // A provider call whose outcome is unknown may still have been billed, so
  // it counts against the ceiling at its worst case: every output token the
  // request allowed, and its input at a conservative characters-per-token.
  const dispatch = async (): Promise<ProviderResult> => {
    const result = await callProvider(
      scalewayChatUrl,
      scalewayKey,
      upstreamRequest,
    );
    if (result.kind === "unknown") {
      await recordSpend(cost(
        Math.ceil(JSON.stringify(upstreamRequest.messages).length / 3),
        upstreamRequest.maxTokens,
      ));
    }
    return result;
  };

  if (courseTask) {
    const feedbackLimit = parseBoundedInteger(
      Deno.env.get("AI_DAILY_FEEDBACK_LIMIT"),
      30,
      1,
      500,
    );
    const { data: allowance, error: allowanceError } = await admin.rpc(
      "consume_ai_feedback",
      { p_user: userData.user.id, p_limit: feedbackLimit },
    );
    if (allowanceError) {
      console.error("Feedback allowance failed", allowanceError.code);
      return jsonResponse({ code: "ai_temporarily_unavailable" }, 503);
    }
    if (allowance?.allowed !== true) {
      return jsonResponse(
        { code: "quota_exceeded", resets_at: allowance?.resets_at ?? null },
        429,
      );
    }
    // Feedback has no replay: any failure returns the allowance, and the
    // learner may simply ask again.
    const refund = async () => {
      const { error } = await admin.rpc("refund_ai_feedback", {
        p_user: userData.user.id,
        p_day: allowance.quota_day,
      });
      if (error) console.error("Feedback refund failed", error.code);
    };
    const result = await dispatch();
    if (result.kind === "unknown") {
      await refund();
      return jsonResponse({ code: "result_unavailable" }, 504);
    }
    await recordSpend(cost(result.inputTokens, result.outputTokens));
    if (result.kind === "failed") {
      await refund();
      return jsonResponse(
        { code: "ai_temporarily_unavailable" },
        result.status,
      );
    }
    return jsonResponse({
      ...result.body,
      task_id: courseTask.task_id,
      remaining_feedback: allowance.remaining,
      feedback_limit: feedbackLimit,
    });
  }

  const isChat = operation === "conversation" || isSummary;
  let paidChatRequired: boolean;
  try {
    paidChatRequired = Deno.env.get("AI_PAID_CHAT_REQUIRED") === "true" &&
      isChat && await inCohort("paid_chat");
  } catch {
    return jsonResponse({ code: "ai_temporarily_unavailable" }, 503);
  }
  if (isChat && body.request_id !== undefined) {
    if (!isRequestUuid(body.request_id) || !isRequestUuid(body.session_id)) {
      return jsonResponse({ code: "invalid_request" }, 400);
    }
    const replayKey = Deno.env.get("AI_REPLAY_KEY");
    if (!replayKey) {
      console.error("Missing AI_REPLAY_KEY.");
      return jsonResponse(
        {
          error: "AI tutor is not configured.",
          code: "ai_temporarily_unavailable",
        },
        503,
      );
    }
    let result;
    try {
      result = await handlePaidChat(
        {
          user: userData.user.id,
          requestId: body.request_id,
          sessionId: body.session_id,
          operation,
          context,
          messages,
        },
        {
          store: paidChatStore(admin, {
            conversation: dailyLimit,
            summary: summaryDailyLimit,
            minNewTurns: parseBoundedInteger(
              Deno.env.get("AI_SUMMARY_MIN_NEW_TURNS"),
              1,
              1,
              50,
            ),
          }),
          cipher: await createTokenCipher(replayKey),
          callProvider: dispatch,
          cost,
          paidChatRequired,
        },
      );
    } catch (error) {
      console.error(
        "Paid chat failed",
        error instanceof Error ? error.message : "unknown",
      );
      return jsonResponse({ code: "ai_temporarily_unavailable" }, 503);
    }
    return jsonResponse(
      result.status === 200
        ? { ...result.body, daily_limit: dailyLimit }
        : result.body,
      result.status,
      result.headers,
    );
  }
  if (isChat && paidChatRequired) {
    // A client too old to send request IDs cannot be held to the paid-chat
    // rules, so it is asked to update rather than served on the old path.
    return jsonResponse({ code: "client_update_required" }, 426);
  }

  {
    const { data: allowed, error: quotaError } = await admin.rpc(
      isSummary ? "consume_ai_summary_quota" : "consume_ai_quota",
      {
        p_user_id: userData.user.id,
        p_daily_limit: isSummary ? summaryDailyLimit : dailyLimit,
      },
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
    const { error } = await admin.rpc(
      isSummary ? "refund_ai_summary_quota" : "refund_ai_daily_quota",
      { p_user_id: userData.user.id },
    );
    if (error) console.error("Quota refund failed", error.code);
  };

  const result = await dispatch();
  if (result.kind === "unknown") {
    await refundDaily();
    return jsonResponse({ error: "AI tutor request timed out." }, 504);
  }
  await recordSpend(cost(result.inputTokens, result.outputTokens));
  if (result.kind === "failed") {
    await refundDaily();
    return jsonResponse(
      {
        error: result.status === 429
          ? "AI tutor is temporarily unavailable."
          : "AI tutor returned an invalid response.",
      },
      result.status,
    );
  }
  return jsonResponse({
    ...result.body,
    remaining_today: await remainingToday(),
    daily_limit: dailyLimit,
  });
};

/**
 * One provider call, classified. A timeout or dropped connection is
 * "unknown": the provider may have billed it, so callers must not resend.
 */
async function callProvider(
  url: string,
  key: string,
  upstreamRequest: UpstreamRequest,
): Promise<ProviderResult> {
  let upstream: Response;
  try {
    upstream = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${key}`,
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
    return { kind: "unknown" };
  }

  const upstreamBody = await upstream.json().catch(() => null);
  const usage = upstreamBody?.usage ?? {};
  const inputTokens = Number(usage.prompt_tokens ?? 0) || 0;
  const outputTokens = Number(usage.completion_tokens ?? 0) || 0;
  if (!upstream.ok) {
    console.error("Scaleway error", upstream.status);
    return {
      kind: "failed",
      status: upstream.status === 429 ? 429 : 502,
      inputTokens,
      outputTokens,
    };
  }
  const invalid: ProviderResult = {
    kind: "failed",
    status: 502,
    inputTokens,
    outputTokens,
  };
  const content = upstreamBody?.choices?.[0]?.message?.content;
  if (
    typeof content !== "string" || content.length < 1 || content.length > 20_000
  ) {
    // A 200 carrying nothing usable is still a failed turn from the learner's
    // side, so it is refunded like any other.
    return invalid;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch (_) {
    // The app consumes typed JSON contracts. A syntactically invalid answer
    // is not a successful learner turn even if the provider returned 200.
    return invalid;
  }
  if (!satisfiesReply(upstreamRequest, parsed)) {
    // Syntax was all this checked, so a well-formed answer to a different
    // question was billed as a successful turn. The client then filled the
    // gaps with defaults, and an evaluation carrying only an overall score
    // reached the learner as three criterion scores of zero it had invented —
    // indistinguishable from a real assessment of a bad answer.
    //
    // The server contract includes nonblank rules removed from the provider
    // schema, where they would accidentally constrain generated language.
    console.error("Upstream reply did not match");
    return invalid;
  }
  return {
    kind: "reply",
    body: {
      content,
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      model: String(upstreamBody.model ?? SCALEWAY_MODEL),
    },
    inputTokens,
    outputTokens,
  };
}

/** The paid-chat RPCs. A database error throws; the handler maps it to 503. */
function paidChatStore(
  admin: SupabaseClient,
  limits: { conversation: number; summary: number; minNewTurns: number },
): PaidChatStore {
  const call = async <T>(name: string, args: Record<string, unknown>) => {
    const { data, error } = await admin.rpc(name, args);
    if (error) throw new Error(`${name} failed: ${error.code}`);
    return data as T;
  };
  return {
    hasAccess: (user) => call<boolean>("has_ai_chat_access", { p_user: user }),
    reserve: ({ user, request, operation, digest, session }) =>
      call<Reservation>("reserve_ai_request", {
        p_user: user,
        p_request: request,
        p_operation: operation,
        p_digest: digest,
        p_session: session,
        p_conversation_limit: limits.conversation,
        p_summary_limit: limits.summary,
        p_min_new_turns: limits.minNewTurns,
        // The provider timeout is 60 seconds; the lease outlasts it.
        p_lease_seconds: 90,
      }),
    complete: (user, request, usage, sealed) =>
      call<boolean>("complete_ai_request", {
        p_user: user,
        p_request: request,
        p_input_tokens: usage.input,
        p_output_tokens: usage.output,
        p_cost_micros: usage.costMicros,
        p_replay_sealed: sealed,
        p_replay_seconds: 86_400,
      }),
    release: (user, request, costMicros) =>
      call<boolean>("release_ai_request", {
        p_user: user,
        p_request: request,
        p_cost_micros: costMicros,
      }),
    abandon: (user, request) =>
      call<boolean>("abandon_ai_request", { p_user: user, p_request: request }),
  };
}

class CohortUnavailable extends Error {}
