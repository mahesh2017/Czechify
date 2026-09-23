# Shared contract fixtures

`campaign_manifest.v1.json` pins curriculum revision 25 from the inspected worktree. Unit and lesson IDs come from the actual bundled JSON. SHA-256 values hash the raw lesson-file bytes. `exercise_ids` contains all required authored initial exercises; `teaching_exercise_ids` is its subset requiring acknowledgement. There are eight free lessons and 92 exercises.

`decision_cases.v1.json` contains 43 normative cases grouped by `kind`. Each implementation test suite should load the applicable cases rather than maintain a copied list of expected unit IDs. The fixtures themselves do not run the application or prove transaction safety.

- `commercial_access`: already-normalized entitlement inputs; tests the commercial union, independently of lesson prerequisites. Revoked IDs refer to revoked permanent grants, not a power to remove free units.
- `reward_allocation`: input ordinals are new, not already processed; expected unit IDs follow campaign order. Ordinal outcomes correspond positionally to requested ordinals. Use the transaction cases to test repeats.
- `billing_access`: normalized authoritative current state; `paused` means effective pause. Test scheduling of a future pause separately while the state is still active.
- `paid_offline_lease`: tests a single source's `min(valid_until, verified_at + seven days)`. Snapshot issue time cannot extend the lease. The backend takes the maximum bound across eligible sources of a feature.
- `milestone_readiness`: complete units mean all manifest lessons have qualifying receipts. Waiting for identity/review retains evidence but yields no awardable ordinal yet.
- `lesson_admission`: assumes authenticated account context is stable, content is valid, loading is resolved and no existing attempt permit applies.
- `transaction_scenario`: run against real PostgreSQL transactions. Unspecified claim assignment order means either claimant may win, but grant IDs and counts must match the expected set.

Add signature canonicalization vectors, AI request replay cases and full device integration tests during implementation; do not mistake these policy fixtures for the entire test suite.

When curriculum content changes, generate a new manifest from the source, review lesson equivalence and preserve the old campaign manifest for queued receipts. Never overwrite production campaign content expectations just because the latest app ships a revised lesson file.
