// Allowlist-based CORS for the Edge Functions.
//
// Czechify ships to Android, iOS, macOS, and Windows — there is no web build.
// Native HTTP clients do not send an `Origin` header and browsers' CORS rules
// do not apply to them, so no browser origin needs to be trusted by default.
// The functions previously answered `Access-Control-Allow-Origin: *`, which
// let any web page call them with a user's session token attached.
//
// Default is therefore "no origin allowed". Set the ALLOWED_ORIGINS secret to
// a comma-separated list if a web client is ever added:
//
//   supabase secrets set ALLOWED_ORIGINS="https://app.example.com"
//
// Pure functions so they can be unit-tested without a Deno runtime env; the
// callers read the environment and pass the result in.

export interface CorsPolicy {
  readonly allowedOrigins: readonly string[];
  readonly allowedHeaders: string;
  readonly allowedMethods: string;
}

/// Parses the ALLOWED_ORIGINS secret. Absent, empty, or all-blank yields an
/// empty allowlist, which denies every browser origin.
export const parseAllowedOrigins = (raw: string | undefined): string[] =>
  (raw ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0);

/// Exact-match only. No prefix or suffix matching: `https://evil-app.com`
/// must never satisfy an allowlist entry of `https://app.com`.
export const isAllowedOrigin = (
  origin: string | null,
  allowedOrigins: readonly string[],
): boolean => origin !== null && allowedOrigins.includes(origin);

/// Response headers for a request from [origin].
///
/// `Access-Control-Allow-Origin` is echoed back only for an allowlisted
/// origin — never `*`, so a browser can never attach a user's credentials
/// from an unapproved page. `Vary: Origin` is always set so caches never
/// serve one origin's decision to another.
export const corsHeaders = (
  origin: string | null,
  policy: CorsPolicy,
): Record<string, string> => {
  const headers: Record<string, string> = { Vary: "Origin" };
  if (!isAllowedOrigin(origin, policy.allowedOrigins)) return headers;
  return {
    ...headers,
    "Access-Control-Allow-Origin": origin as string,
    "Access-Control-Allow-Headers": policy.allowedHeaders,
    "Access-Control-Allow-Methods": policy.allowedMethods,
  };
};

/// Preflight reply. A disallowed origin still gets 204 — the absent
/// `Access-Control-Allow-Origin` is what makes the browser block the call,
/// and echoing an error would leak whether an origin is allowlisted.
export const preflightResponse = (
  origin: string | null,
  policy: CorsPolicy,
): Response =>
  new Response(null, { status: 204, headers: corsHeaders(origin, policy) });
