// Minimal Play Developer API client for subscription verification and
// acknowledgement, authenticated as a service account. `fetch` and the clock
// are injectable so tests never reach Google.

import { importPKCS8, SignJWT } from "npm:jose@6.2.12";

const scope = "https://www.googleapis.com/auth/androidpublisher";
const api = "https://androidpublisher.googleapis.com/androidpublisher/v3";

export interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri: string;
}

/**
 * `retryable` failures back off and keep the last verified entitlement;
 * permanent ones end the job. Configuration and auth failures are retryable
 * so a bad deploy never marks every subscription expired.
 */
export class PlayApiError extends Error {
  constructor(
    readonly code: string,
    readonly retryable: boolean,
    readonly retryAfterSeconds: number | null = null,
  ) {
    super(code);
  }
}

export interface PlayClient {
  getSubscription(
    productId: string,
    token: string,
  ): Promise<{ body: unknown; text: string }>;
  acknowledge(productId: string, token: string): Promise<void>;
}

export function parseServiceAccount(raw: string | undefined): ServiceAccount {
  const value = JSON.parse(raw ?? "null");
  if (
    typeof value?.client_email !== "string" ||
    typeof value?.private_key !== "string" ||
    typeof value?.token_uri !== "string"
  ) {
    throw new PlayApiError("play_not_configured", true);
  }
  return value;
}

export function createPlayClient(options: {
  packageName: string;
  account: ServiceAccount;
  fetch?: typeof fetch;
  now?: () => Date;
}): PlayClient {
  const doFetch = options.fetch ?? fetch;
  const now = options.now ?? (() => new Date());
  if (
    !/^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$/.test(
      options.packageName,
    )
  ) {
    throw new PlayApiError("play_not_configured", true);
  }
  let cached: { token: string; expires: number } | null = null;

  async function accessToken(): Promise<string> {
    const at = now().getTime();
    if (cached && cached.expires - 60_000 > at) return cached.token;
    const key = await importPKCS8(options.account.private_key, "RS256");
    const assertion = await new SignJWT({ scope })
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
      throw classify(response, "play_auth_failed");
    }
    const json = await response.json();
    if (typeof json.access_token !== "string") {
      throw new PlayApiError("play_auth_failed", true);
    }
    cached = {
      token: json.access_token,
      expires: at + Number(json.expires_in ?? 0) * 1000,
    };
    return cached.token;
  }

  const path = (productId: string, token: string, v2: boolean) =>
    `${api}/applications/${encodeURIComponent(options.packageName)}/purchases/${
      v2 ? "subscriptionsv2" : "subscriptions/" + encodeURIComponent(productId)
    }/tokens/${encodeURIComponent(token)}`;

  return {
    async getSubscription(productId, token) {
      const response = await doFetch(path(productId, token, true), {
        headers: { Authorization: `Bearer ${await accessToken()}` },
      });
      if (!response.ok) {
        await response.body?.cancel();
        throw classify(response, "play_verification_failed");
      }
      const text = await response.text();
      return { body: JSON.parse(text), text };
    },
    async acknowledge(productId, token) {
      const response = await doFetch(
        `${path(productId, token, false)}:acknowledge`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${await accessToken()}`,
            "Content-Type": "application/json",
          },
          body: "{}",
        },
      );
      await response.body?.cancel();
      if (!response.ok) throw classify(response, "play_acknowledge_failed");
    },
  };
}

function classify(response: Response, fallback: string): PlayApiError {
  const retryAfter = Number(response.headers.get("Retry-After"));
  const after = Number.isFinite(retryAfter) && retryAfter > 0
    ? retryAfter
    : null;
  if (response.status === 404 || response.status === 410) {
    return new PlayApiError("purchase_not_found", false);
  }
  if (response.status === 400) return new PlayApiError("play_rejected", false);
  return new PlayApiError(fallback, true, after);
}
