import { assertEquals } from "jsr:@std/assert@1.0.14";
import {
  confirmsDeletion,
  decodeLatestAuthTime,
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
  // custom_cards holds the learner's own hand-written vocabulary. It synced
  // for months while this list omitted it, so an export handed back everything
  // EXCEPT the part they authored. Deletion was unaffected — the foreign key
  // cascades — which is why nothing surfaced it.
  //
  // test/data/account_export_contract_test.dart cross-checks this list against
  // the Dart sync map, which is the half that catches the next omission.
  assertEquals(syncedUserTables, [
    "lesson_progress",
    "earned_badges",
    "user_progress",
    "srs_cards",
    "custom_cards",
    "gamification_state",
    "learner_profiles",
    "reminder_preferences",
    "placement_profiles",
    "ai_daily_usage",
    "ai_service_daily_usage",
    "curriculum_entitlements",
    "tutor_reply_reports",
  ]);
});

Deno.test("the authentication time is read out of a well-formed token", () => {
  assertEquals(
    decodeLatestAuthTime(jwtWithPayload({
      amr: [{ method: "password", timestamp: 1730000000 }],
    })),
    1730000000,
  );
});

Deno.test("the most recent authentication wins", () => {
  assertEquals(
    decodeLatestAuthTime(jwtWithPayload({
      amr: [
        { method: "password", timestamp: 1730000000 },
        { method: "oauth", timestamp: 1730000500 },
      ],
    })),
    1730000500,
  );
});

Deno.test("a refreshed token does not count as re-authentication", () => {
  // This is the whole finding. `iat` moves on every refresh, so reading it
  // meant any session that had merely refreshed satisfied a gate that exists
  // to prove the account holder is present. `amr` records authentication
  // events, and a refresh adds none — so a fresh token carrying an old
  // authentication is correctly judged stale.
  const now = 1730000000;
  const refreshed = jwtWithPayload({
    iat: now,
    amr: [{ method: "password", timestamp: now - 86400 }],
  });

  assertEquals(decodeLatestAuthTime(refreshed), now - 86400);
  assertEquals(hasRecentAuth(decodeLatestAuthTime(refreshed), now), false);
});

Deno.test("a token with no usable authentication claim is not trusted", () => {
  assertEquals(decodeLatestAuthTime("not-a-jwt"), null);
  assertEquals(decodeLatestAuthTime(jwtWithPayload({})), null);
  // Tokens minted before this claim was relied on land here too, and must
  // fail closed rather than be read as recent.
  assertEquals(decodeLatestAuthTime(jwtWithPayload({ iat: 1730000000 })), null);
  assertEquals(decodeLatestAuthTime(jwtWithPayload({ amr: "password" })), null);
  assertEquals(
    decodeLatestAuthTime(jwtWithPayload({ amr: [{ method: "password" }] })),
    null,
  );
  assertEquals(hasRecentAuth(null, 1730000000), false);
});

Deno.test("deletion requires authentication in the last few minutes", () => {
  const now = 1730000000;
  assertEquals(hasRecentAuth(now, now), true);
  assertEquals(hasRecentAuth(now - maxDeletionAuthAgeSeconds, now), true);
  assertEquals(hasRecentAuth(now - maxDeletionAuthAgeSeconds - 1, now), false);
  // A day-old authentication is exactly the stolen-credential case this
  // gate exists for.
  assertEquals(hasRecentAuth(now - 86400, now), false);
});

Deno.test("a future-dated authentication buys no extra window", () => {
  const now = 1730000000;
  assertEquals(hasRecentAuth(now + 60, now), false);
});

Deno.test("anonymous accounts are exempt — they hold no credential to re-enter", () => {
  assertEquals(requiresRecentAuth(false), true);
  assertEquals(requiresRecentAuth(true), false);
});
