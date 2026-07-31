import { assertEquals } from "jsr:@std/assert@1.0.14";
import {
  confirmsDeletion,
  decodeJwtIssuedAt,
  hasRecentAuth,
  isSupportedMethod,
  maxDeletionAuthAgeSeconds,
  requiresRecentAuth,
  syncedUserTables,
} from "./account_policy.ts";

const jwtWithPayload = (payload: Record<string, unknown>): string => {
  const encode = (value: Record<string, unknown>) =>
    btoa(JSON.stringify(value)).replaceAll("+", "-").replaceAll("/", "_")
      .replaceAll("=", "");
  return `${encode({ alg: "HS256" })}.${encode(payload)}.signature`;
};

Deno.test("only export, deletion, and preflight methods are supported", () => {
  assertEquals(isSupportedMethod("GET"), true);
  assertEquals(isSupportedMethod("DELETE"), true);
  assertEquals(isSupportedMethod("POST"), false);
});

Deno.test("account deletion requires an exact confirmation phrase", () => {
  assertEquals(confirmsDeletion("DELETE MY ACCOUNT"), true);
  assertEquals(confirmsDeletion("delete my account"), false);
  assertEquals(confirmsDeletion(null), false);
});

Deno.test("export includes every user-owned cloud table", () => {
  assertEquals(syncedUserTables, [
    "lesson_progress",
    "earned_badges",
    "user_progress",
    "srs_cards",
    "gamification_state",
    "ai_daily_usage",
  ]);
});

Deno.test("issued-at is read out of a well-formed token", () => {
  assertEquals(
    decodeJwtIssuedAt(jwtWithPayload({ iat: 1730000000 })),
    1730000000,
  );
});

Deno.test("a token with no usable issued-at is not trusted", () => {
  assertEquals(decodeJwtIssuedAt("not-a-jwt"), null);
  assertEquals(decodeJwtIssuedAt(jwtWithPayload({})), null);
  assertEquals(decodeJwtIssuedAt(jwtWithPayload({ iat: "recently" })), null);
  // Missing iat must fail closed, never read as "recent".
  assertEquals(hasRecentAuth(null, 1730000000), false);
});

Deno.test("deletion requires a session minted in the last few minutes", () => {
  const now = 1730000000;
  assertEquals(hasRecentAuth(now, now), true);
  assertEquals(hasRecentAuth(now - maxDeletionAuthAgeSeconds, now), true);
  assertEquals(hasRecentAuth(now - maxDeletionAuthAgeSeconds - 1, now), false);
  // A day-old token is exactly the stolen-token case this gate exists for.
  assertEquals(hasRecentAuth(now - 86400, now), false);
});

Deno.test("a future-dated token buys no extra window", () => {
  const now = 1730000000;
  assertEquals(hasRecentAuth(now + 60, now), false);
});

Deno.test("anonymous accounts are exempt — they hold no credential to re-enter", () => {
  assertEquals(requiresRecentAuth(false), true);
  assertEquals(requiresRecentAuth(true), false);
});
