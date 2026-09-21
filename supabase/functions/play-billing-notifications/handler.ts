// Pub/Sub push endpoint for Play real-time developer notifications.
//
// Answers success only after the message is durably recorded (or is a
// redelivery of one that was), so Pub/Sub redelivers anything that failed to
// store. No Play call happens here: the notification is only a hint, and the
// worker re-fetches Play for the queued purchase.

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
    try {
      const outcome = await deps.record(
        parsed.subscription,
        parsed.messageId,
        parsed.kind,
        parsed.type,
        parsed.purchaseToken ? await sha256Hex(parsed.purchaseToken) : null,
        parsed.eventTime,
      );
      if (outcome === "unmatched") {
        log("play_notification_unmatched", { type: parsed.type });
      }
      return new Response(null, { status: 204 });
    } catch {
      // Not stored: let Pub/Sub redeliver.
      log("play_notification_store_failed", {});
      return new Response(null, { status: 500 });
    }
  };
}
