/// Every table holding data belonging to the account, for export and audit.
///
/// This must cover every entity the client syncs, plus anything the server
/// records about the account on its own. `custom_cards` — the learner's
/// hand-written vocabulary — was missing, so a subject-access export silently
/// omitted the one thing on this list they authored themselves. Deletion was
/// unaffected (the foreign key cascades), which is exactly why the gap was
/// invisible.
///
/// A Dart test cross-checks this list against the client's sync entity map, so
/// adding a synced table without adding it here fails the build.
export const syncedUserTables = [
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
  "curriculum_entitlements",
] as const;

export const isSupportedMethod = (method: string): boolean =>
  method === "GET" || method === "DELETE" || method === "OPTIONS";

export const confirmsDeletion = (value: string | null): boolean =>
  value === "DELETE MY ACCOUNT";

/// How recently the caller must have proved their identity to delete an
/// account. A stolen access token stays valid for its full lifetime, so the
/// confirmation header alone never established that the person pressing
/// delete is the account holder — only that someone holds a token.
export const maxDeletionAuthAgeSeconds = 300;

/// Reads `iat` out of an already-verified access token.
///
/// The signature is checked by `auth.getUser()` before this is called; this
/// only reads a claim out of the payload, so it deliberately does no
/// verification of its own. Returns null when the token is malformed or has
/// no usable `iat`, which callers must treat as "not recent".
export const decodeJwtIssuedAt = (jwt: string): number | null => {
  const segments = jwt.split(".");
  if (segments.length !== 3) return null;
  try {
    const padded = segments[1].replaceAll("-", "+").replaceAll("_", "/");
    const payload = JSON.parse(
      atob(padded.padEnd(Math.ceil(padded.length / 4) * 4, "=")),
    );
    const issuedAt = (payload as Record<string, unknown>).iat;
    return typeof issuedAt === "number" && Number.isFinite(issuedAt)
      ? issuedAt
      : null;
  } catch {
    return null;
  }
};

/// Anonymous accounts hold no credential to re-enter, so requiring a fresh
/// sign-in would make their data impossible to delete. They are exempt.
export const requiresRecentAuth = (isAnonymous: boolean): boolean =>
  !isAnonymous;

/// A token counts as recent when it was issued within [maxAgeSeconds].
///
/// Tokens issued in the future are rejected rather than trusted, so clock
/// skew or a forged `iat` cannot buy an indefinite window.
export const hasRecentAuth = (
  issuedAt: number | null,
  nowSeconds: number,
  maxAgeSeconds: number = maxDeletionAuthAgeSeconds,
): boolean => {
  if (issuedAt === null) return false;
  const age = nowSeconds - issuedAt;
  return age >= 0 && age <= maxAgeSeconds;
};
