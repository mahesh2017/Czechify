# Entitlement backend: staging setup

This delivery implements signed access documents and phase-specific placement. Checkout, referral qualification/Integrity and paywall activation remain later phases. All `/configuration` activation switches return false; no existing screen enforces paid access yet.

## Deployment order

1. Apply the three `20260921` migrations to a dedicated staging Supabase project. The phase-ceiling migration must precede the entitlement schema. New clients send `phase_ceilings`, so deploy the backend migration before distributing the updated app. Old clients remain compatible after the migration.
2. Provision an Ed25519 signing key in your secret manager. Set `MONETIZATION_SNAPSHOT_PRIVATE_JWK` (private OKP JWK, `crv=Ed25519`) and `MONETIZATION_SNAPSHOT_KEY_ID` for the `monetization-api` function. Never commit the private key or place it in Flutter configuration.
3. Put only the corresponding raw 32-byte public key, base64url encoded, in the app's `MONETIZATION_SNAPSHOT_PUBLIC_KEYS` Dart define: a JSON map of key ID to public key. The default is an empty map, so unconfigured builds cannot accept any signed entitlement. Never use the committed test vector key in a deployed environment.
4. Deploy `monetization-api` with Supabase gateway JWT verification enabled. Its handler also verifies the JWT through Auth and derives the account from the verified user. `GET /entitlements` returns `snapshot_jws`; caller-selected account IDs and mutations are rejected.
5. Test two different staging accounts, the owner-only projections, account switch/rollback, export/deletion, signature rejection, offline expiry and key rotation before enabling any acquisition flow.

No production project or Store configuration was changed by implementation.

## Schema and operation boundaries

- `monetization_accounts`, `course_unit_grants` and `course_access_windows` expose owner-only reads. Clients cannot write them.
- Private feature sources, audit and outbox records are not exposed. Service role cannot bypass the grant/revision transaction with a direct table write.
- Service-only `set_course_unit_grant` serializes on the account, deduplicates source keys, increments the revision and records audit/outbox entries atomically. It is a persistence primitive, **not referral eligibility verification**. The referral worker must prove eligibility and apply the two-milestone rule before invoking it.
- Service-only `apply_verified_feature` accepts state only after the future billing worker verifies Play and holds its fenced lineage lease. It cannot itself verify a purchase token. Do not expose it in a client mutation endpoint.
- Access windows are read by the snapshot resolver, but the fixed-cutoff legacy migration writer is intentionally deferred to the existing-user rollout phase.
- `get_monetization_snapshot` reads a consistent statement snapshot, omits revoked grants, separates Core from AI, and computes each purchase's offline bound before aggregating. Routine snapshot requests do not refresh purchase verification timestamps.
- Account export includes safe grant/window/feature history, excluding source keys and internal audit records. Account deletion cascades owned access/cache data and removes the user's ID from retained audit records. Define final audit retention with the production privacy/accounting policy before rollout.

## Cache and signing behavior

The Dart client uses `cryptography` Ed25519 verification with an embedded key allowlist and fixed compact-JWS header. It validates schema, account, feature bounds, campaign/manifest and grant membership after verification. A valid signature alone is insufficient.

Cache rows are account-scoped, excluded from generic sync and erased with learner data. Account transitions suspend the repository before session or local-data changes; late callbacks cannot write or publish access for the next account. Failed remote refresh retains only an independently verified cached document. Identical or older signed documents cannot reset the clock anchor. Clock rollback requires reverification for time-limited access; permanent grants remain available. A genuinely newer verified server document establishes a new clock anchor.

Retain old public keys while permanent offline documents may still exist. Publish the next public key in clients before switching the backend signer. Removing an old key without an online refresh path can strand offline learners.

## Verification scope

The new migrations and pgTAP security suite are tested in a disposable local PostgreSQL 17 container. That harness supplies minimal Auth/legacy relations; CI's normal Supabase reset remains responsible for exercising the complete historical Supabase migration chain. Tests cover owner isolation, rejected client writes/RPCs, idempotent grants, revision/outbox atomicity, purchase-bound offline validity, old/new placement merges, export redaction and deletion.

The standard Deno suite includes JWT-routing and JOSE signing tests. A committed public test vector produced by `jose` is verified by Dart's independent Ed25519 implementation. Its ephemeral private key was discarded.

Primary library references: [Supabase function security](https://supabase.com/docs/guides/database/functions), [Dart cryptography](https://pub.dev/documentation/cryptography/latest/).
