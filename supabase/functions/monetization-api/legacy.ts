// Existing-user migration routes of monetization-api. The account always
// comes from the verified JWT and the migration from the database: a client
// names only the lessons it has on record from before the cutoff.

type Json = Record<string, unknown>;
type Respond = (body: Json, status?: number) => Response;

export interface LegacyDependencies {
  status(user: string): Promise<Json>;
  claim(
    user: string,
    migration: string,
    completed: number[],
    attempted: number[],
    reviewThreshold: number,
  ): Promise<Json>;
  /** More new units than this in one claim waits for support. */
  reviewThreshold: number;
}

export const legacyRoutes: Record<string, string> = {
  "legacy/status": "GET",
  "legacy/claim": "POST",
};

/** The course has 124 lessons; anything longer is not a real record. */
const maxLessons = 500;

const statusFor: Record<string, number> = {
  migration_not_ready: 409,
  claim_window_closed: 409,
  not_eligible: 403,
  already_claimed: 409,
};

export async function handleLegacyRoute(
  name: string,
  user: string,
  body: Json | null,
  deps: LegacyDependencies,
  respond: Respond,
): Promise<Response> {
  const status = await deps.status(user);
  if (name === "legacy/status") return respond(publicStatus(status));

  const completed = lessonIds(body?.completed_lesson_ids);
  const attempted = lessonIds(body?.attempted_lesson_ids);
  if (
    !body || !exact(body, ["completed_lesson_ids", "attempted_lesson_ids"]) ||
    !completed || !attempted
  ) {
    return respond({ code: "invalid_request" }, 400);
  }
  if (status.available !== true || typeof status.migration_id !== "string") {
    return respond({ code: "migration_not_ready" }, 409);
  }
  const result = await deps.claim(
    user,
    status.migration_id,
    completed,
    attempted,
    deps.reviewThreshold,
  );
  if (typeof result.code === "string") {
    return respond(
      {
        code: result.code in statusFor
          ? result.code
          : "verification_unavailable",
      },
      statusFor[result.code] ?? 503,
    );
  }
  return respond({
    status: result.status,
    unit_ids: Array.isArray(result.unit_ids) ? result.unit_ids : [],
  });
}

/** Only what the app shows; the migration ID stays on the server. */
function publicStatus(status: Json): Json {
  if (status.available !== true) return { available: false };
  const claim = status.claim as Json | null | undefined;
  return {
    available: true,
    cutoff_at: status.cutoff_at,
    grace_ends_at: status.grace_ends_at,
    claim_window_ends_at: status.claim_window_ends_at,
    eligible: status.eligible === true,
    claim_window_open: status.claim_window_open === true,
    legacy_unit_ids: Array.isArray(status.legacy_unit_ids)
      ? status.legacy_unit_ids
      : [],
    claim: claim
      ? { status: claim.status, unit_ids: claim.unit_ids ?? [] }
      : null,
  };
}

function lessonIds(value: unknown): number[] | null {
  if (!Array.isArray(value) || value.length > maxLessons) return null;
  if (
    !value.every((id) =>
      Number.isSafeInteger(id) && (id as number) > 0 &&
      (id as number) < 1000000
    )
  ) {
    return null;
  }
  return [...new Set(value as number[])].sort((a, b) => a - b);
}

function exact(body: Json, required: string[]) {
  const keys = Object.keys(body);
  return required.every((k) => keys.includes(k)) &&
    keys.every((k) => required.includes(k));
}
