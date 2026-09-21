// Google service-account OAuth (JWT bearer grant) for server-to-Google calls.
// One token source per scope; tokens are cached until a minute before expiry.

import { importPKCS8, SignJWT } from "npm:jose@6.2.12";

export interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri: string;
}

/**
 * `retryable` failures back off and keep previous verified state; permanent
 * ones end the operation. Configuration and auth failures are retryable so a
 * bad deploy never turns into a wrong verdict.
 */
export class GoogleApiError extends Error {
  constructor(
    readonly code: string,
    readonly retryable: boolean,
    readonly retryAfterSeconds: number | null = null,
  ) {
    super(code);
  }
}

export function parseServiceAccount(
  raw: string | undefined,
  notConfigured = "google_not_configured",
): ServiceAccount {
  let value;
  try {
    value = JSON.parse(raw ?? "null");
  } catch {
    throw new GoogleApiError(notConfigured, true);
  }
  if (
    typeof value?.client_email !== "string" ||
    typeof value?.private_key !== "string" ||
    typeof value?.token_uri !== "string"
  ) {
    throw new GoogleApiError(notConfigured, true);
  }
  return value;
}

export function createTokenSource(options: {
  account: ServiceAccount;
  scope: string;
  fetch?: typeof fetch;
  now?: () => Date;
  failureCode?: string;
}): () => Promise<string> {
  const doFetch = options.fetch ?? fetch;
  const now = options.now ?? (() => new Date());
  const failure = options.failureCode ?? "google_auth_failed";
  let cached: { token: string; expires: number } | null = null;
  return async () => {
    const at = now().getTime();
    if (cached && cached.expires - 60_000 > at) return cached.token;
    const key = await importPKCS8(options.account.private_key, "RS256");
    const assertion = await new SignJWT({ scope: options.scope })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .setIssuer(options.account.client_email)
      .setAudience(options.account.token_uri)
      .setIssuedAt(Math.floor(at / 1000))
      .setExpirationTime(Math.floor(at / 1000) + 3600)
      .sign(key);
    const response = await doFetch(options.account.token_uri, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw classifyGoogleResponse(response, failure);
    }
    const json = await response.json();
    if (typeof json.access_token !== "string") {
      throw new GoogleApiError(failure, true);
    }
    cached = {
      token: json.access_token,
      expires: at + Number(json.expires_in ?? 0) * 1000,
    };
    return cached.token;
  };
}

/** 404/410: the object does not exist; 400: refused; anything else retries. */
export function classifyGoogleResponse(
  response: Response,
  fallback: string,
  codes: { notFound?: string; rejected?: string } = {},
): GoogleApiError {
  const retryAfter = Number(response.headers.get("Retry-After"));
  const after = Number.isFinite(retryAfter) && retryAfter > 0
    ? retryAfter
    : null;
  if (response.status === 404 || response.status === 410) {
    return new GoogleApiError(codes.notFound ?? "not_found", false);
  }
  if (response.status === 400) {
    return new GoogleApiError(codes.rejected ?? "rejected", false);
  }
  return new GoogleApiError(fallback, true, after);
}
