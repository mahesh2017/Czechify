# Reviewer curriculum access

Selected accounts can be given temporary or permanent access to every unit and
lesson without changing placement, progress, XP, or learning evidence.

## Before granting access

Ask the reviewer to open **Settings → Account & data** and link their Czechify
account to an email address. Google Play tester membership is not exposed to
the app, so a Play Console email alone does not identify the in-app account.

Find the linked user in the Supabase dashboard or SQL editor:

```sql
select id, email, created_at
from auth.users
where lower(email) = lower('reviewer@example.com');
```

## Grant access

Run this through the Supabase SQL editor or another service-role-only admin
surface. Never expose the service-role key in the app.

```sql
insert into public.curriculum_entitlements (
  user_id,
  unlock_all,
  expires_at,
  reason
)
values (
  '00000000-0000-0000-0000-000000000000',
  true,
  now() + interval '30 days',
  'Play internal reviewer'
)
on conflict (user_id) do update
set unlock_all = excluded.unlock_all,
    expires_at = excluded.expires_at,
    reason = excluded.reason,
    updated_at = now();
```

Use `null` for `expires_at` only when access should not expire. The app refreshes
the entitlement on startup, account changes, and app resume, and caches the last
server result for offline use. An expired cached entitlement is treated as inactive.

## Revoke access

```sql
delete from public.curriculum_entitlements
where user_id = '00000000-0000-0000-0000-000000000000';
```

Revocation takes effect the next time the app successfully refreshes. A device
that remains offline keeps its last non-expired result, so temporary reviewer
access should normally have an expiry date.

## Developer builds

`--dart-define=UNLOCK_ALL=true` remains available for developer-only builds.
It unlocks the curriculum for every installation of that build and must not be
used to target individual production users.
