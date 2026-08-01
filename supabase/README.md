# Supabase deployment

The app uses anonymous Supabase Auth for progress sync and an authenticated
Edge Function for AI. The DeepSeek key exists only as a server secret.

1. Create an EU Supabase project, enable anonymous and email sign-ins, enable
   manual identity linking, and add `ceskinapro://auth-callback` to the Auth
   redirect allowlist.
2. Install/login to the Supabase CLI, link the project, apply the committed
   migrations, and deploy:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
supabase secrets set DEEPSEEK_API_KEY='YOUR_DEEPSEEK_KEY'
supabase secrets set AI_DAILY_REQUEST_LIMIT='20'
supabase secrets set AI_USER_REQUESTS_PER_MINUTE='5'
supabase secrets set AI_PROJECT_REQUESTS_PER_MINUTE='60'
supabase secrets set OPENAI_API_KEY='YOUR_OPENAI_KEY'
supabase secrets set SPEECH_DAILY_REQUEST_LIMIT='100'
supabase secrets set SPEECH_USER_REQUESTS_PER_MINUTE='30'
supabase secrets set SPEECH_PROJECT_REQUESTS_PER_MINUTE='60'
supabase functions deploy deepseek-proxy
supabase functions deploy whisper-proxy
supabase functions deploy account-data
supabase storage cp -r AUDIO_MP3_DIRECTORY/. ss:///course-audio \
  --cache-control 'public,max-age=31536000,immutable' \
  --content-type audio/mpeg --experimental
supabase storage cp assets/audio/manifest.json ss:///course-audio/manifest.json \
  --cache-control 'public,max-age=300' \
  --content-type application/json --experimental
```

Do not create a `DEEPSEEK_API_KEY` Dart define and never put it in a checked-in
`.env` file. Supabase automatically provides `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` to the deployed function.

Run the app with the project's public URL and publishable/anon key:

```sh
flutter run \
  --dart-define=SUPABASE_URL='https://YOUR_PROJECT_REF.supabase.co' \
  --dart-define=SUPABASE_ANON_KEY='YOUR_PUBLIC_KEY'
```

The public key is designed to ship in clients; RLS and authenticated Edge
Functions provide authorization. The service-role and DeepSeek keys must never
be shipped.

The three AI quota settings are optional. Their bounded defaults are 20 daily
requests per user, 5 requests per user per minute, and 60 requests project-wide
per minute. The burst limiter responds with HTTP 429 and `Retry-After: 60`.

## Local verification

With Docker running, rebuild the database exclusively from committed
migrations and run the database security/sync suite:

```sh
supabase start
supabase db reset --local --no-seed
supabase test db --local supabase/tests/database
supabase db lint --local --level warning --fail-on warning
supabase migration list --local
```

The pgTAP suite covers grants, RLS ownership, server-only quota execution,
constraints, deterministic LWW behavior, generated pagination IDs, pull
indexes, and the public audio bucket. Run the same migrations against staging
before production promotion.
