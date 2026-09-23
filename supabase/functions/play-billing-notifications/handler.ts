// Pub/Sub push endpoint for Play real-time developer notifications.
//
// Answers success only after the message is durably recorded (or is a
// redelivery of one that was), so Pub/Sub redelivers anything that failed to
// store. No Play call happens here: the notification is only a hint, and the
// worker re-fetches Play for the queued purchase.
//
// A subscription token the server has never seen is handed on for
// discovery: the app may never send it (a payment that completed later, a
// failed check), and Play refunds what nobody acknowledges in three days.
// The worker asks Play which account made it.

import { sha256Hex } from "../_shared/monetization/billing_crypto.ts";
import {
  parsePushBody,
  UnusableNotification,
} from "../_shared/monetization/play_notifications.ts";

export interface Dependencies {
  authenticate(authorization: string | null): Promise<boolean>;
  packageName: string;
  record(
    subscription: string,
    messageId: string,
    kind: string,
    type: number | null,
    tokenDigest: string | null,
    eventTime: string | null,
  ): Promise<string>;
  /**
   * Keeps an unknown subscription token (encrypted) for the worker to ask
   * Play whose it is. Absent when the token key is not configured.
   */
  discover?: (
    tokenDigest: string,
    token: string,
    productId: string,
  ) => Promise<string>;
  log?: (event: string, detail: Record<string, unknown>) => void;
}

const maxBody = 64 * 1024;

export function createHandler(deps: Dependencies) {
  const log = deps.log ?? ((event, detail) => console.warn(event, detail));
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") return new Response(null, { status: 405 });
    if (!await deps.authenticate(request.headers.get("Authorization"))) {
      log("play_notification_auth_failed", {});
      return new Response(null, { status: 401 });
    }
    const text = await request.text();
    if (new TextEncoder().encode(text).length > maxBody) {
      log("play_notification_unusable", { reason: "size" });
      return new Response(null, { status: 204 });
    }
    let parsed;
    try {
      parsed = parsePushBody(JSON.parse(text), deps.packageName);
    } catch (error) {
      // Redelivering an unusable message can never succeed; acknowledge it.
      log("play_notification_unusable", {
        reason: error instanceof UnusableNotification ? error.message : "json",
      });
      return new Response(null, { status: 204 });
    }
    const digest = parsed.purchaseToken
      ? await sha256Hex(parsed.purchaseToken)
      : null;
    let outcome: string;
    try {
      outcome = await deps.record(
        parsed.subscription,
        parsed.messageId,
        parsed.kind,
        parsed.type,
        digest,
        parsed.eventTime,
      );
    } catch {
      // Not stored: let Pub/Sub redeliver.
      log("play_notification_store_failed", {});
      return new Response(null, { status: 500 });
    }
    if (outcome === "unmatched") {
      log("play_notification_unmatched", { type: parsed.type });
    }
    // A redelivery may be the retry of a discovery that failed below.
    if (
      (outcome === "unmatched" || outcome === "duplicate") &&
      parsed.kind === "subscription" && digest && parsed.purchaseToken &&
      parsed.productId && deps.discover
    ) {
      try {
        await deps.discover(digest, parsed.purchaseToken, parsed.productId);
      } catch {
        log("play_notification_discovery_failed", {});
        return new Response(null, { status: 500 });
      }
    }
    return new Response(null, { status: 204 });
  };
}
