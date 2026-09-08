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
  // Speech processing writes user-linked counters here. It was missing from
  // this list, so an export handed the learner an incomplete picture of what
  // is held about them — the one thing a subject-access request is for.
  "ai_service_daily_usage",
  "curriculum_entitlements",
  // Reports a learner filed about the tutor. Theirs, so it belongs in an
  // export — and in a deletion.
  "tutor_reply_reports",
  // The portable half of the learning history: the evidence placement reads,
  // and practice already scheduled for a future date.
  "learning_evidence_events",
  "delayed_transfer_assignments",
] as const;

/// A deterministic total order for reading each exported table, one page at
/// a time.
///
/// Paging needs a tiebreak-free sort or it is not paging. The export ordered
/// by `user_id` *inside* a filter on `user_id`, so every row carried the same
/// sort key: Postgres is free to order ties differently between statements,
/// and offset paging over that returns some rows twice and never returns
/// others. Nothing about a truncated export announces itself, which is why
/// this is declared here rather than left to each call site — a new table
/// without an entry fails the test below rather than paging incorrectly in
/// production.
///
/// Every synced table carries `revision`, the server-owned sequence stamped on
/// insert and update, which is unique and ascending. The three server-owned
/// tables have no revision and are keyed on their own primary keys instead.
export const exportOrderColumns: Record<string, readonly string[]> = {
  lesson_progress: ["revision"],
  earned_badges: ["revision"],
  user_progress: ["revision"],
  srs_cards: ["revision"],
  custom_cards: ["revision"],
  gamification_state: ["revision"],
  learner_profiles: ["revision"],
  reminder_preferences: ["revision"],
  placement_profiles: ["revision"],
  tutor_reply_reports: ["revision"],
  learning_evidence_events: ["revision"],
  delayed_transfer_assignments: ["revision"],
  ai_daily_usage: ["usage_date"],
  ai_service_daily_usage: ["service", "usage_date"],
  curriculum_entitlements: ["user_id"],
};

export const isSupportedMethod = (method: string): boolean =>
  method === "GET" || method === "DELETE" || method === "OPTIONS";

export const confirmsDeletion = (value: string | null): boolean =>
  value === "DELETE MY ACCOUNT";

/// How recently the caller must have proved their identity to delete an
/// account. A stolen access token stays valid for its full lifetime, so the
/// confirmation header alone never established that the person pressing
/// delete is the account holder — only that someone holds a token.
export const maxDeletionAuthAgeSeconds = 300;

/// The payload of an already-verified access token.
///
/// The signature is checked by `auth.getUser()` before any of this is called,
/// so these helpers deliberately do no verification of their own — they only
/// read claims out of a token that has already been established as genuine.
const decodePayload = (jwt: string): Record<string, unknown> | null => {
  const segments = jwt.split(".");
  if (segments.length !== 3) return null;
  try {
    const padded = segments[1].replaceAll("-", "+").replaceAll("_", "/");
    return JSON.parse(
      atob(padded.padEnd(Math.ceil(padded.length / 4) * 4, "=")),
    ) as Record<string, unknown>;
  } catch {
    return null;
  }
};

/// When the caller most recently *authenticated*, from the `amr` claim.
///
/// This gate used to read `iat`, which is when the token was issued — and a
/// refresh issues a new token with a fresh `iat` without the learner typing
/// anything. So "authenticated in the last five minutes" was satisfied by any
/// session that had merely refreshed, and stolen refresh credentials cleared
/// the step-up the prompt in the UI implies.
///
/// `amr` records the authentication methods actually used and when, and a
/// refresh does not add an entry. The most recent entry is the last time the
/// account holder genuinely proved who they were.
///
/// Returns null when the claim is missing or unusable — including for tokens
/// minted before this claim was relied on — which callers must treat as "not
/// recent" and refuse.
export const decodeLatestAuthTime = (jwt: string): number | null => {
  const payload = decodePayload(jwt);
  if (payload === null) return null;

  const amr = payload.amr;
  if (!Array.isArray(amr)) return null;

  let latest: number | null = null;
  for (const entry of amr) {
    if (typeof entry !== "object" || entry === null) continue;
    const timestamp = (entry as Record<string, unknown>).timestamp;
    if (typeof timestamp !== "number" || !Number.isFinite(timestamp)) continue;
    if (latest === null || timestamp > latest) latest = timestamp;
  }
  return latest;
};

/// Anonymous accounts hold no credential to re-enter, so requiring a fresh
/// sign-in would make their data impossible to delete. They are exempt.
export const requiresRecentAuth = (isAnonymous: boolean): boolean =>
  !isAnonymous;

/// Authentication counts as recent when it happened within [maxAgeSeconds].
///
/// Timestamps in the future are rejected rather than trusted, so clock skew
/// or a forged claim cannot buy an indefinite window.
export const hasRecentAuth = (
  authenticatedAt: number | null,
  nowSeconds: number,
  maxAgeSeconds: number = maxDeletionAuthAgeSeconds,
): boolean => {
  if (authenticatedAt === null) return false;
  const age = nowSeconds - authenticatedAt;
  return age >= 0 && age <= maxAgeSeconds;
};
