// Minimal Play Developer API client for subscription verification and
// acknowledgement, authenticated as a service account. `fetch` and the clock
// are injectable so tests never reach Google.

import {
  classifyGoogleResponse,
  createTokenSource,
  GoogleApiError,
  parseServiceAccount as parseAccount,
  type ServiceAccount,
} from "./google_auth.ts";

export type { ServiceAccount };
/** Billing's name for a Google API failure; see [GoogleApiError]. */
export { GoogleApiError as PlayApiError };

const scope = "https://www.googleapis.com/auth/androidpublisher";
const api = "https://androidpublisher.googleapis.com/androidpublisher/v3";

export interface PlayClient {
  getSubscription(
    productId: string,
    token: string,
  ): Promise<{ body: unknown; text: string }>;
  acknowledge(productId: string, token: string): Promise<void>;
}

export const parseServiceAccount = (raw: string | undefined) =>
  parseAccount(raw, "play_not_configured");

export function createPlayClient(options: {
  packageName: string;
  account: ServiceAccount;
  fetch?: typeof fetch;
  now?: () => Date;
}): PlayClient {
  const doFetch = options.fetch ?? fetch;
  if (!isPackageName(options.packageName)) {
    throw new GoogleApiError("play_not_configured", true);
  }
  const accessToken = createTokenSource({
    account: options.account,
    scope,
    fetch: doFetch,
    now: options.now,
    failureCode: "play_auth_failed",
  });
  const codes = { notFound: "purchase_not_found", rejected: "play_rejected" };

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
        throw classifyGoogleResponse(
          response,
          "play_verification_failed",
          codes,
        );
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
      if (!response.ok) {
        throw classifyGoogleResponse(
          response,
          "play_acknowledge_failed",
          codes,
        );
      }
    },
  };
}

export const isPackageName = (value: string) =>
  /^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$/.test(value);
