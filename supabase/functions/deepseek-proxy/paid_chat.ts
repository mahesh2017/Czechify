// Paid AI chat (engineering spec §6): a conversation turn or summary that
// carries a request ID. Entitlement, allowance and idempotency live in
// reserve_ai_request; this module orders the calls around the provider and
// maps every outcome to a response the app can explain.
//
// The rule that matters most: once a request may have reached the provider,
// it is never sent again. A retry gets the stored reply, "still running", or
// result_unavailable — never a second billed call.

import { sha256Hex } from "../_shared/monetization/billing_crypto.ts";
import type { AllowedMessage, Operation } from "./request_policy.ts";

export type ChatOperation = Extract<
  Operation,
  "conversation" | "conversation_summary"
>;

export type Reservation =
  | { outcome: "reserved"; remaining: number | null }
  | { outcome: "replay"; replay_sealed: string }
  | { outcome: "quota_exceeded"; resets_at: string }
  | {
    outcome:
      | "in_flight"
      | "result_unavailable"
      | "conflict"
      | "summary_not_due";
  };

/** What the provider call produced, as the handler classifies it. */
export type ProviderResult =
  | {
    kind: "reply";
    body: Record<string, unknown>;
    inputTokens: number;
    outputTokens: number;
  }
  // The provider answered, but not usably: the learner is refunded and any
  // tokens it still charged are counted.
  | {
    kind: "failed";
    status: number;
    inputTokens: number;
    outputTokens: number;
  }
  // No answer: timeout or dropped connection. It may have been billed.
  | { kind: "unknown" };

export interface PaidChatStore {
  hasAccess(user: string): Promise<boolean>;
  reserve(args: {
    user: string;
    request: string;
    operation: ChatOperation;
    digest: string;
    session: string;
  }): Promise<Reservation>;
  complete(
    user: string,
    request: string,
    usage: { input: number; output: number; costMicros: number },
    sealed: string,
  ): Promise<boolean>;
  release(user: string, request: string, costMicros: number): Promise<boolean>;
  abandon(user: string, request: string): Promise<boolean>;
}

export interface ReplayCipher {
  encrypt(value: string): Promise<string>;
  decrypt(sealed: string): Promise<string>;
}

export interface PaidChatDeps {
  store: PaidChatStore;
  cipher: ReplayCipher;
  /** Calls the provider once. Never retried by this module. */
  callProvider(): Promise<ProviderResult>;
  /** Estimated provider cost of a call, in micros of the billing currency. */
  cost(inputTokens: number, outputTokens: number): number;
  paidChatRequired: boolean;
  log?: (event: string, detail: Record<string, unknown>) => void;
}

export interface PaidChatRequest {
  user: string;
  requestId: string;
  sessionId: string;
  operation: ChatOperation;
  context: Record<string, string>;
  messages: AllowedMessage[];
}

export type PaidChatResponse = {
  status: number;
  body: Record<string, unknown>;
  headers?: Record<string, string>;
};

const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

/** A request ID or session ID as the app sends it: a lowercase UUID. */
export const isRequestUuid = (value: unknown): value is string =>
  typeof value === "string" && uuid.test(value);

/**
 * The semantic payload a request ID is bound to. Context keys are sorted so
 * the same request always digests the same, whatever order the client used.
 */
export const payloadDigest = (request: PaidChatRequest): Promise<string> =>
  sha256Hex(JSON.stringify([
    request.operation,
    request.sessionId,
    Object.keys(request.context).sort().map((key) => [
      key,
      request.context[key],
    ]),
    request.messages.map((message) => [message.role, message.content]),
  ]));

export async function handlePaidChat(
  request: PaidChatRequest,
  deps: PaidChatDeps,
): Promise<PaidChatResponse> {
  const log = deps.log ?? ((event, detail) => console.warn(event, detail));
  const { store } = deps;

  if (deps.paidChatRequired && !await store.hasAccess(request.user)) {
    return { status: 403, body: { code: "ai_entitlement_required" } };
  }

  const reservation = await store.reserve({
    user: request.user,
    request: request.requestId,
    operation: request.operation,
    digest: await payloadDigest(request),
    session: request.sessionId,
  });
  switch (reservation.outcome) {
    case "replay": {
      let body: Record<string, unknown>;
      try {
        body = JSON.parse(await deps.cipher.decrypt(reservation.replay_sealed));
      } catch {
        // A replay that cannot be opened (rotated key, corrupt row) is still
        // never a reason to call the provider again.
        return { status: 409, body: { code: "result_unavailable" } };
      }
      return { status: 200, body: { ...body, replayed: true } };
    }
    case "in_flight":
      return {
        status: 409,
        body: { code: "request_in_progress" },
        headers: { "Retry-After": "5" },
      };
    case "result_unavailable":
      return { status: 409, body: { code: "result_unavailable" } };
    case "conflict":
      return { status: 409, body: { code: "idempotency_conflict" } };
    case "summary_not_due":
      return { status: 409, body: { code: "summary_not_due" } };
    case "quota_exceeded":
      return {
        status: 429,
        body: { code: "quota_exceeded", resets_at: reservation.resets_at },
      };
    case "reserved":
      break;
  }

  const result = await deps.callProvider();
  if (result.kind === "unknown") {
    await store.abandon(request.user, request.requestId);
    return { status: 504, body: { code: "result_unavailable" } };
  }
  if (result.kind === "failed") {
    await store.release(
      request.user,
      request.requestId,
      deps.cost(result.inputTokens, result.outputTokens),
    );
    return {
      status: result.status,
      body: { code: "ai_temporarily_unavailable" },
    };
  }

  const costMicros = deps.cost(result.inputTokens, result.outputTokens);
  const allowance = request.operation === "conversation" ? reservation : null;
  const body: Record<string, unknown> = {
    ...result.body,
    request_id: request.requestId,
    ...(allowance ? { remaining_today: allowance.remaining } : {}),
  };
  let completed = false;
  try {
    completed = await store.complete(
      request.user,
      request.requestId,
      {
        input: result.inputTokens,
        output: result.outputTokens,
        costMicros,
      },
      await deps.cipher.encrypt(JSON.stringify(body)),
    );
  } catch {
    completed = false;
  }
  if (!completed) {
    // The learner still gets this reply. A retry of the same request finds
    // it in flight, then unavailable after the lease — never a second call.
    log("ai_request_completion_failed", { operation: request.operation });
  }
  return { status: 200, body };
}
