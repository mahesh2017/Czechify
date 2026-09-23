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

/// Records the server keeps about the account on its own: course access,
/// subscriptions, referrals, AI allowance and the existing-user migration.
/// The database exports each through a fixed column list, so purchase
/// tokens, fraud signals and the other side of a referral never appear.
export const serverOwnedExportKeys = [
  "course_unit_grants",
  "course_access_windows",
  "feature_access",
  "store_purchases",
  "referral_codes",
  "referral_claims",
  "referral_receipts",
  "referral_rewards",
  "ai_daily_allowance",
  "ai_chat_sessions",
  "legacy_migration_claims",
] as const;

/// Refuse an incomplete backend export rather than silently losing a table.
export const isCompleteAccountSnapshot = (
  value: unknown,
): value is Record<string, unknown[]> => {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }
  const snapshot = value as Record<string, unknown>;
  return [...syncedUserTables, ...serverOwnedExportKeys].every((table) =>
    Array.isArray(snapshot[table])
  );
};

export const isSupportedMethod = (method: string): boolean =>
  method === "GET" || method === "DELETE" || method === "OPTIONS";

export const confirmsDeletion = (value: string | null): boolean =>
  value === "DELETE MY ACCOUNT";

/// Deleting Czechify data does not cancel a Google Play subscription. While
/// one is still renewing, deletion needs the learner to have been told so.
export const acknowledgesStoreSubscription = (value: string | null): boolean =>
  value === "KEEPS RENEWING IN GOOGLE PLAY";

/// Whether the deletion must stop and warn first.
export const needsSubscriptionWarning = (
  notice: unknown,
  acknowledgement: string | null,
): boolean => {
  const renewing = typeof notice === "object" && notice !== null
    ? (notice as Record<string, unknown>).renewing_subscriptions
    : undefined;
  // An unreadable notice warns rather than deleting silently.
  if (typeof renewing !== "number" || !Number.isInteger(renewing)) {
    return !acknowledgesStoreSubscription(acknowledgement);
  }
  return renewing > 0 && !acknowledgesStoreSubscription(acknowledgement);
};

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
