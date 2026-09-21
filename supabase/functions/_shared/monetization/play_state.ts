// Normalizes a Play Developer API `purchases.subscriptionsv2` response into
// the fields `apply_play_verification` accepts. Pure: no network, no clock.
// https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2

import { sha256Hex } from "./billing_crypto.ts";

export type NormalizedState =
  | "pending"
  | "active"
  | "in_grace_period"
  | "canceled"
  | "on_hold"
  | "paused"
  | "expired";

export interface NormalizedPurchase {
  state: NormalizedState;
  raw_state: string;
  valid_until: string;
  verified_at: string;
  auto_renewing: boolean;
  acknowledged: boolean;
  product_id: string;
  base_plan_id: string | null;
  obfuscated_account_id: string | null;
  linked_token_digest: string | null;
  response_fingerprint: string;
}

/** Play returned something this code cannot safely interpret. Not retryable. */
export class UnexpectedPlayResponse extends Error {}

const states: Record<string, NormalizedState> = {
  SUBSCRIPTION_STATE_PENDING: "pending",
  SUBSCRIPTION_STATE_ACTIVE: "active",
  SUBSCRIPTION_STATE_IN_GRACE_PERIOD: "in_grace_period",
  SUBSCRIPTION_STATE_CANCELED: "canceled",
  SUBSCRIPTION_STATE_ON_HOLD: "on_hold",
  SUBSCRIPTION_STATE_PAUSED: "paused",
  SUBSCRIPTION_STATE_EXPIRED: "expired",
  // A pending purchase the buyer abandoned never granted anything.
  SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED: "expired",
};

type Json = Record<string, unknown>;
const isObject = (v: unknown): v is Json =>
  typeof v === "object" && v !== null && !Array.isArray(v);

export async function normalizeSubscription(
  body: unknown,
  productId: string,
  verifiedAt: Date,
  rawText: string,
): Promise<NormalizedPurchase> {
  if (!isObject(body)) throw new UnexpectedPlayResponse("not an object");
  const rawState = body.subscriptionState;
  const state = typeof rawState === "string" ? states[rawState] : undefined;
  // UNSPECIFIED or a future state is unknown, never "expired" or "paid".
  if (!state) throw new UnexpectedPlayResponse("unknown state");
  const items = Array.isArray(body.lineItems)
    ? body.lineItems.filter((i) => isObject(i) && i.productId === productId)
    : [];
  if (items.length !== 1) throw new UnexpectedPlayResponse("line items");
  const item = items[0] as Json;
  const offer = isObject(item.offerDetails) ? item.offerDetails : {};
  const expiry = typeof item.expiryTime === "string"
    ? new Date(item.expiryTime)
    : null;
  if (expiry && Number.isNaN(expiry.getTime())) {
    throw new UnexpectedPlayResponse("expiry");
  }
  // A pending purchase may have no expiry yet; it grants nothing anyway.
  if (!expiry && state !== "pending") {
    throw new UnexpectedPlayResponse("missing expiry");
  }
  const renewing = isObject(item.autoRenewingPlan) &&
    item.autoRenewingPlan.autoRenewEnabled === true;
  const accounts = isObject(body.externalAccountIdentifiers)
    ? body.externalAccountIdentifiers
    : {};
  const obfuscated = accounts.obfuscatedExternalAccountId;
  const linked = body.linkedPurchaseToken;
  return {
    state,
    raw_state: rawState as string,
    valid_until: (expiry ?? verifiedAt).toISOString(),
    verified_at: verifiedAt.toISOString(),
    auto_renewing: renewing,
    acknowledged: body.acknowledgementState ===
      "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    product_id: productId,
    base_plan_id: typeof offer.basePlanId === "string"
      ? offer.basePlanId
      : null,
    obfuscated_account_id: typeof obfuscated === "string" ? obfuscated : null,
    linked_token_digest: typeof linked === "string" && linked.length > 0
      ? await sha256Hex(linked)
      : null,
    response_fingerprint: await sha256Hex(rawText),
  };
}
