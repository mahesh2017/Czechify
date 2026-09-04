# Google sign-up and sign-in setup

The client flow is implemented, but Google and Supabase must know which signed
app is allowed to use it. OAuth client identifiers are public configuration;
the Google client secret belongs only in Supabase and must never be added to
the app, `env/prod.json`, or GitHub build artifacts.

The four `assets/images/google_sign_in_*` files are the unmodified light/dark,
Android/iOS PNGs from Google's current pre-approved Sign in with Google asset
bundle. Replace them only with a newer official bundle; do not redraw the G.

## Account behavior

- A new learner starts anonymously. **Continue with Google** manually links
  Google to that same Supabase user ID, preserving local and cloud progress.
- If Google already belongs to a Czechify account, the app asks before replacing
  this installation's local learner data. It authenticates the destination on
  an isolated Supabase client, downloads its snapshot, and commits the account
  transition atomically.
- A protected email account can add Google without creating a second Czechify
  account. It cannot merge two existing Czechify accounts.
- Deleting a Google account reopens Google's account chooser to mint a recent
  session before the deletion Edge Function is called.

## Google Cloud Console

1. Configure the OAuth consent screen for Czechify.
2. Create a **Web application** OAuth client. Add this Supabase callback as an
   authorized redirect URI:

   `https://twhvcxtieolvnbnczypj.supabase.co/auth/v1/callback`

3. Create an **Android** OAuth client for package
   `com.eminentsite.czechify`. Add the SHA-1 for every certificate that signs a
   build you test:
   - the Google Play **App signing key certificate** for Play-installed builds;
   - the upload/release certificate for directly installed release builds; and
   - the debug certificate for local debug builds, if needed.
4. For iOS, create an **iOS** OAuth client for the Runner bundle ID. Add its
   reversed client ID as another URL scheme in `ios/Runner/Info.plist` before
   enabling the iOS release job. The existing `czechify` callback scheme stays.

## Supabase dashboard

In **Authentication → Providers → Google**:

1. enable Google;
2. enter the Web client ID and Web client secret;
3. add the Android and iOS client IDs to the accepted client-ID list when the
   dashboard supports multiple IDs (Web first); and
4. enable manual identity linking in Auth settings. The committed local
   `supabase/config.toml` mirrors this as `enable_manual_linking = true`.

For native iOS sign-in, follow the current Supabase provider guidance for its
nonce setting. Do not relax nonce validation for Android unnecessarily.

## App and CI configuration

Put the public IDs in the local release define file:

```json
{
  "GOOGLE_WEB_CLIENT_ID": "...apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": "...apps.googleusercontent.com"
}
```

Set matching GitHub Actions secrets named `GOOGLE_WEB_CLIENT_ID` and
`GOOGLE_IOS_CLIENT_ID`. The Android release requires the Web ID; the iOS release
requires both. The workflow now fails early rather than publishing a build with
a nonfunctional Google button.

## Verification checklist

Test using a Play Internal Testing install, not only a USB-installed debug APK:

1. New anonymous learner with progress → Continue with Google → user ID and
   progress stay unchanged.
2. Fresh installation → same Google account → replacement warning → synced
   progress appears.
3. Cancel the Google chooser and cancel the replacement warning → current
   account and local progress remain unchanged.
4. Email-protected account → Link Google → both sign-in methods reach the same
   user ID.
5. Select a different Google account during deletion → deletion is refused.
6. Delete with the connected Google account → cloud and local data are removed
   and a new anonymous session is created.
