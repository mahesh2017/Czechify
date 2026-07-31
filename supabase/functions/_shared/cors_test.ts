import { assert, assertEquals } from "jsr:@std/assert@1.0.14";
import {
  corsHeaders,
  type CorsPolicy,
  isAllowedOrigin,
  parseAllowedOrigins,
  preflightResponse,
} from "./cors.ts";

const policy = (origins: string[]): CorsPolicy => ({
  allowedOrigins: origins,
  allowedHeaders: "authorization, content-type",
  allowedMethods: "POST, OPTIONS",
});

Deno.test("an unset or blank allowlist denies every origin", () => {
  assertEquals(parseAllowedOrigins(undefined), []);
  assertEquals(parseAllowedOrigins(""), []);
  assertEquals(parseAllowedOrigins("  ,  , "), []);
});

Deno.test("allowlist entries are trimmed", () => {
  assertEquals(
    parseAllowedOrigins("https://a.example , https://b.example"),
    ["https://a.example", "https://b.example"],
  );
});

Deno.test("origin matching is exact, not by prefix or suffix", () => {
  const allowed = ["https://app.example"];
  assert(isAllowedOrigin("https://app.example", allowed));
  assert(!isAllowedOrigin("https://app.example.evil.com", allowed));
  assert(!isAllowedOrigin("https://evil-app.example", allowed));
  assert(!isAllowedOrigin("http://app.example", allowed)); // scheme matters
  assert(!isAllowedOrigin(null, allowed));
});

Deno.test("a disallowed origin is never granted access", () => {
  const headers = corsHeaders("https://evil.example", policy([]));
  assertEquals(headers["Access-Control-Allow-Origin"], undefined);
});

Deno.test("the wildcard is never emitted", () => {
  const headers = corsHeaders(
    "https://app.example",
    policy(["https://app.example"]),
  );
  assertEquals(headers["Access-Control-Allow-Origin"], "https://app.example");
  assert(Object.values(headers).every((value) => value !== "*"));
});

Deno.test("Vary: Origin is always set so caches stay per-origin", () => {
  assertEquals(corsHeaders(null, policy([]))["Vary"], "Origin");
  assertEquals(
    corsHeaders("https://app.example", policy(["https://app.example"]))["Vary"],
    "Origin",
  );
});

Deno.test("native clients send no Origin and are unaffected", () => {
  // CORS is a browser mechanism; a request without an Origin is not
  // cross-origin and must still be served normally.
  const headers = corsHeaders(null, policy(["https://app.example"]));
  assertEquals(headers["Access-Control-Allow-Origin"], undefined);
  assertEquals(headers["Vary"], "Origin");
});

Deno.test("preflight answers 204 without leaking allowlist membership", async () => {
  const allowed = await preflightResponse(
    "https://app.example",
    policy(["https://app.example"]),
  );
  const denied = await preflightResponse("https://evil.example", policy([]));

  assertEquals(allowed.status, 204);
  assertEquals(denied.status, 204);
  assertEquals(
    allowed.headers.get("access-control-allow-origin"),
    "https://app.example",
  );
  assertEquals(denied.headers.get("access-control-allow-origin"), null);
});
