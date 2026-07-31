// Whisper proxy Edge Function — transcribes audio via OpenAI Whisper API.
// The OpenAI API key is stored as a Supabase secret; the client never sees it.
// Returns verbose_json with word-level timestamps and confidence scores.
//
// Cost controls mirror deepseek-proxy: per-user + project burst windows and a
// per-user daily cap, all enforced server-side before OpenAI is called.

import { createClient } from "npm:@supabase/supabase-js@2.110.7";
import {
  corsHeaders,
  type CorsPolicy,
  parseAllowedOrigins,
  preflightResponse,
} from "../_shared/cors.ts";
import { isRecord, parseTranscriptionInput } from "./request_policy.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

const CORS: CorsPolicy = {
  allowedOrigins: parseAllowedOrigins(Deno.env.get("ALLOWED_ORIGINS")),
  allowedHeaders: "authorization, apikey, content-type, x-client-info",
  allowedMethods: "POST, OPTIONS",
};
const MODEL = "whisper-1";
const SERVICE = "whisper";

function boundedInteger(
  raw: string | undefined,
  fallback: number,
  min: number,
  max: number,
): number {
  const value = Number.parseInt(raw ?? "", 10);
  if (Number.isNaN(value) || value < min || value > max) return fallback;
  return value;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origin = req.headers.get("Origin");
  if (req.method === "OPTIONS") {
    return preflightResponse(origin, CORS);
  }
  // Shadows the module-level helper so no reply can forget the CORS headers.
  const cors = corsHeaders(origin, CORS);
  const json = (
    data: unknown,
    status: number,
    headers: Record<string, string> = {},
  ): Response => jsonWithHeaders(data, status, { ...cors, ...headers });

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  if (!OPENAI_API_KEY) {
    return json({ error: "Whisper API key not configured" }, 500);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Missing required server secrets.");
    return json({ error: "Speech service is not configured" }, 503);
  }

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "Authentication required" }, 401);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const jwt = authorization.slice("Bearer ".length);
  const { data: userData, error: authError } = await admin.auth.getUser(jwt);
  if (authError || !userData.user) {
    return json({ error: "Invalid or expired session" }, 401);
  }

  // Parse and validate the request body BEFORE consuming quota — malformed
  // JSON, empty audio, or an invalid language code must never waste the
  // learner's daily allowance.
  let input;
  try {
    input = parseTranscriptionInput(await req.json());
  } catch (_) {
    return json({ error: "Invalid JSON request body" }, 400);
  }
  if (!input) {
    return json({ error: "Invalid transcription request" }, 400);
  }

  // Decode base64 audio and validate it is non-empty before touching quota.
  let audioBytes: Uint8Array;
  try {
    audioBytes = Uint8Array.from(
      atob(input.audioBase64),
      (c) => c.charCodeAt(0),
    );
  } catch (_) {
    return json({ error: "Invalid audio encoding" }, 400);
  }
  if (audioBytes.length === 0) {
    return json({ error: "Audio recording is empty" }, 400);
  }

  // --- Quota checks (only after the request is proven valid) ---
  const userBurstLimit = boundedInteger(
    Deno.env.get("SPEECH_USER_REQUESTS_PER_MINUTE"),
    30,
    1,
    100,
  );
  const projectBurstLimit = boundedInteger(
    Deno.env.get("SPEECH_PROJECT_REQUESTS_PER_MINUTE"),
    60,
    1,
    5_000,
  );
  const { data: burstAllowed, error: burstError } = await admin.rpc(
    "consume_service_burst_quota",
    {
      p_service: SERVICE,
      p_user_id: userData.user.id,
      p_user_limit: userBurstLimit,
      p_project_limit: projectBurstLimit,
    },
  );
  if (burstError) {
    console.error("Speech burst quota check failed", burstError.code);
    return json({ error: "Speech service is temporarily unavailable" }, 503);
  }
  if (!burstAllowed) {
    return json(
      { error: "Too many pronunciation checks. Try again shortly." },
      429,
      { "Retry-After": "60" },
    );
  }

  const dailyLimit = boundedInteger(
    Deno.env.get("SPEECH_DAILY_REQUEST_LIMIT"),
    100,
    1,
    10_000,
  );
  const { data: dailyAllowed, error: dailyError } = await admin.rpc(
    "consume_service_daily_quota",
    {
      p_service: SERVICE,
      p_user_id: userData.user.id,
      p_daily_limit: dailyLimit,
    },
  );
  if (dailyError) {
    console.error("Speech daily quota check failed", dailyError.code);
    return json({ error: "Speech service is temporarily unavailable" }, 503);
  }
  if (!dailyAllowed) {
    return json(
      { error: "Daily pronunciation check limit reached. Try again tomorrow." },
      429,
    );
  }

  try {
    // Build multipart form data for OpenAI
    const formData = new FormData();
    const blob = new Blob([audioBytes as BlobPart], { type: "audio/wav" });
    formData.append("file", blob, "audio.wav");
    formData.append("model", MODEL);
    formData.append("language", input.language);
    formData.append("response_format", "verbose_json");
    // Word-level timestamps/probabilities are opt-in; without these the
    // response has segments only and the client loses per-word confidence.
    formData.append("timestamp_granularities[]", "word");
    formData.append("timestamp_granularities[]", "segment");

    // Optional: pass reference text as prompt to improve accuracy
    if (input.prompt) {
      formData.append("prompt", input.prompt);
    }

    const response = await fetch(
      "https://api.openai.com/v1/audio/transcriptions",
      {
        method: "POST",
        headers: { Authorization: `Bearer ${OPENAI_API_KEY}` },
        body: formData,
        signal: AbortSignal.timeout(60_000),
      },
    );

    if (!response.ok) {
      // Refund the daily quota — Whisper returned an error, so the learner's
      // allowance should not be consumed for a failed call.
      await admin.rpc("refund_service_daily_quota", {
        p_service: SERVICE,
        p_user_id: userData.user.id,
      }).catch((e: unknown) =>
        console.error("Quota refund failed", e)
      );
      return json({
        error: `Whisper API error: ${response.status}`,
      }, 502);
    }

    const decoded: unknown = await response.json();
    if (!isRecord(decoded)) {
      return json({ error: "Invalid transcription response" }, 502);
    }
    const result = decoded;

    // Extract word-level data for pronunciation scoring
    const words: Array<{
      word: string;
      start: number;
      end: number;
      probability: number;
    }> = [];

    // Per-segment confidence from avg_logprob (e^logprob ∈ 0..1), used as the
    // word probability for words falling inside that segment's time range —
    // OpenAI's API returns words at the top level without per-word probability.
    const segments = Array.isArray(result.segments)
      ? result.segments.filter(isRecord)
      : [];
    const confidenceAt = (t: number): number => {
      for (const seg of segments) {
        const start = typeof seg.start === "number" ? seg.start : 0;
        const end = typeof seg.end === "number" ? seg.end : 0;
        if (t >= start && t <= end) {
          return typeof seg.avg_logprob === "number"
            ? Math.min(1, Math.exp(seg.avg_logprob))
            : 1;
        }
      }
      return 1;
    };

    if (Array.isArray(result.words)) {
      for (const w of result.words) {
        if (!isRecord(w)) continue;
        const start = typeof w.start === "number" ? w.start : 0;
        words.push({
          word: typeof w.word === "string" ? w.word.trim() : "",
          start,
          end: typeof w.end === "number" ? w.end : 0,
          probability: typeof w.probability === "number"
            ? w.probability
            : confidenceAt(start),
        });
      }
    }

    return json({
      text: typeof result.text === "string" ? result.text : "",
      language: typeof result.language === "string"
        ? result.language
        : input.language,
      duration: typeof result.duration === "number" ? result.duration : 0,
      words,
      segments: segments.map((segment) => ({
        id: segment.id,
        start: segment.start,
        end: segment.end,
        text: typeof segment.text === "string" ? segment.text.trim() : "",
        confidence: typeof segment.avg_logprob === "number"
          ? segment.avg_logprob
          : 0,
      })),
    }, 200);
  } catch (_) {
    return json({ error: "Internal error" }, 500);
  }
});

function jsonWithHeaders(
  data: unknown,
  status: number,
  headers: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}
