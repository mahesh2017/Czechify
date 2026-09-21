// Server-side verification of a Play Integrity standard-request token.
// https://developer.android.com/google/play/integrity/standard
// https://developer.android.com/google/play/integrity/verdicts
//
// Outcome policy for referral receipts:
// - rejected: the token was not made for this request (package, requestHash),
//   is stale, or comes from a signing certificate other than ours;
// - needs_review: the request binding holds but Play could not vouch for the
//   app, device or licence (unrecognized, uncertified device, unevaluated);
// - verified: Play-recognized app, certified device, licensed install.
// Review never erases learning; it only holds the reward for a person.

import {
  classifyGoogleResponse,
  createTokenSource,
  GoogleApiError,
  type ServiceAccount,
} from "./google_auth.ts";
import { isPackageName } from "./play_client.ts";

export type IntegrityOutcome = "verified" | "needs_review";

/** The token cannot vouch for this request. Never retried with the same token. */
export class IntegrityRejected extends Error {}

export interface IntegrityVerifier {
  verify(token: string, expectedRequestHash: string): Promise<IntegrityOutcome>;
}

const maxAgeMs = 10 * 60 * 1000;
const maxSkewMs = 60 * 1000;

type Json = Record<string, unknown>;
const isObject = (v: unknown): v is Json =>
  typeof v === "object" && v !== null && !Array.isArray(v);

/** Pure verdict evaluation, separate from the network call for testing. */
export function evaluateIntegrityPayload(
  payload: unknown,
  expected: {
    packageName: string;
    requestHash: string;
    certificateDigests: readonly string[];
    now: number;
  },
): IntegrityOutcome {
  if (!isObject(payload)) throw new IntegrityRejected("payload");
  const request = isObject(payload.requestDetails)
    ? payload.requestDetails
    : {};
  if (request.requestPackageName !== expected.packageName) {
    throw new IntegrityRejected("package");
  }
  if (request.requestHash !== expected.requestHash) {
    throw new IntegrityRejected("request_hash");
  }
  const issued = Number(request.timestampMillis);
  if (
    !Number.isFinite(issued) || expected.now - issued > maxAgeMs ||
    issued - expected.now > maxSkewMs
  ) {
    throw new IntegrityRejected("stale");
  }
  const app = isObject(payload.appIntegrity) ? payload.appIntegrity : {};
  const recognition = app.appRecognitionVerdict;
  if (recognition !== "UNEVALUATED") {
    const digests = Array.isArray(app.certificateSha256Digest)
      ? app.certificateSha256Digest
      : [];
    if (app.packageName !== expected.packageName) {
      throw new IntegrityRejected("app_package");
    }
    if (
      digests.length === 0 ||
      !digests.every((d) => expected.certificateDigests.includes(d as string))
    ) {
      throw new IntegrityRejected("certificate");
    }
  }
  const device = isObject(payload.deviceIntegrity)
    ? payload.deviceIntegrity
    : {};
  const deviceVerdicts = Array.isArray(device.deviceRecognitionVerdict)
    ? device.deviceRecognitionVerdict
    : [];
  const account = isObject(payload.accountDetails)
    ? payload.accountDetails
    : {};
  return recognition === "PLAY_RECOGNIZED" &&
      deviceVerdicts.includes("MEETS_DEVICE_INTEGRITY") &&
      account.appLicensingVerdict === "LICENSED"
    ? "verified"
    : "needs_review";
}

export function createIntegrityVerifier(options: {
  packageName: string;
  certificateDigests: readonly string[];
  account: ServiceAccount;
  fetch?: typeof fetch;
  now?: () => Date;
}): IntegrityVerifier {
  const doFetch = options.fetch ?? fetch;
  const now = options.now ?? (() => new Date());
  if (
    !isPackageName(options.packageName) ||
    options.certificateDigests.length === 0
  ) {
    throw new GoogleApiError("integrity_not_configured", true);
  }
  const accessToken = createTokenSource({
    account: options.account,
    scope: "https://www.googleapis.com/auth/playintegrity",
    fetch: doFetch,
    now: options.now,
    failureCode: "integrity_auth_failed",
  });
  return {
    async verify(token, expectedRequestHash) {
      const response = await doFetch(
        `https://playintegrity.googleapis.com/v1/${
          encodeURIComponent(options.packageName)
        }:decodeIntegrityToken`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${await accessToken()}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ integrity_token: token }),
        },
      );
      if (response.status === 400) {
        // Google could not decode it: malformed, foreign or tampered.
        await response.body?.cancel();
        throw new IntegrityRejected("undecodable");
      }
      if (!response.ok) {
        await response.body?.cancel();
        throw classifyGoogleResponse(response, "integrity_unavailable");
      }
      const body = await response.json();
      return evaluateIntegrityPayload(body?.tokenPayloadExternal, {
        packageName: options.packageName,
        requestHash: expectedRequestHash,
        certificateDigests: options.certificateDigests,
        now: now().getTime(),
      });
    },
  };
}
