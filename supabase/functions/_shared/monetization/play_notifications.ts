// Google Play real-time developer notifications delivered by Pub/Sub push.
// https://developer.android.com/google/play/billing/rtdn-reference
// https://cloud.google.com/pubsub/docs/authenticate-push-subscriptions

import {
  createRemoteJWKSet,
  jwtVerify,
  type JWTVerifyGetKey,
} from "npm:jose@6.2.12";

export const googleCerts = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs"),
);

/**
 * Pub/Sub push carries a Google-signed OIDC token, not a Supabase JWT. Only
 * a token for this endpoint's audience, issued to the configured push
 * service account with a verified email, is accepted.
 */
export async function verifyPushToken(
  authorization: string | null,
  expected: { audience: string; email: string },
  keys: JWTVerifyGetKey = googleCerts,
): Promise<boolean> {
  if (!authorization?.startsWith("Bearer ") || authorization.length > 8192) {
    return false;
  }
  try {
    const { payload } = await jwtVerify(authorization.slice(7), keys, {
      issuer: ["https://accounts.google.com", "accounts.google.com"],
      audience: expected.audience,
      algorithms: ["RS256"],
    });
    return payload.email === expected.email && payload.email_verified === true;
  } catch {
    return false;
  }
}

export interface PlayNotification {
  subscription: string;
  messageId: string;
  kind: "subscription" | "voided" | "test" | "other";
  type: number | null;
  purchaseToken: string | null;
  /** The subscription product, for a subscription notification. */
  productId: string | null;
  eventTime: string | null;
}

/** A push body this endpoint will never be able to use. */
export class UnusableNotification extends Error {}

type Json = Record<string, unknown>;
const isObject = (v: unknown): v is Json =>
  typeof v === "object" && v !== null && !Array.isArray(v);

export function parsePushBody(
  body: unknown,
  packageName: string,
): PlayNotification {
  if (!isObject(body) || !isObject(body.message)) {
    throw new UnusableNotification("envelope");
  }
  const message = body.message;
  const messageId = message.messageId ?? message.message_id;
  if (
    typeof body.subscription !== "string" || body.subscription.length === 0 ||
    body.subscription.length > 300 || typeof messageId !== "string" ||
    messageId.length === 0 || messageId.length > 200 ||
    typeof message.data !== "string"
  ) {
    throw new UnusableNotification("envelope");
  }
  let data: unknown;
  try {
    data = JSON.parse(atob(message.data));
  } catch {
    throw new UnusableNotification("data");
  }
  if (!isObject(data) || data.packageName !== packageName) {
    throw new UnusableNotification("package");
  }
  const millis = Number(data.eventTimeMillis);
  const eventTime = Number.isFinite(millis) && millis > 0
    ? new Date(millis).toISOString()
    : null;
  const base = {
    subscription: body.subscription,
    messageId,
    eventTime,
    productId: null,
  };
  const token = (value: unknown) =>
    typeof value === "string" && value.length > 0 && value.length <= 16384
      ? value
      : null;
  if (isObject(data.subscriptionNotification)) {
    const n = data.subscriptionNotification;
    const purchaseToken = token(n.purchaseToken);
    if (!purchaseToken) throw new UnusableNotification("token");
    return {
      ...base,
      kind: "subscription",
      type: Number.isInteger(n.notificationType)
        ? n.notificationType as number
        : null,
      purchaseToken,
      productId: typeof n.subscriptionId === "string" &&
          /^[a-z0-9_.]{1,100}$/.test(n.subscriptionId)
        ? n.subscriptionId
        : null,
    };
  }
  if (isObject(data.voidedPurchaseNotification)) {
    const n = data.voidedPurchaseNotification;
    // productType 1 is a subscription; one-time products are not sold.
    if (n.productType !== 1) {
      return { ...base, kind: "other", type: null, purchaseToken: null };
    }
    const purchaseToken = token(n.purchaseToken);
    if (!purchaseToken) throw new UnusableNotification("token");
    return { ...base, kind: "voided", type: null, purchaseToken };
  }
  return {
    ...base,
    kind: isObject(data.testNotification) ? "test" : "other",
    type: null,
    purchaseToken: null,
  };
}
