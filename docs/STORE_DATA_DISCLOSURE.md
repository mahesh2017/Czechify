# Store Data-Safety Answer Sheet — Czechify

Copy these answers into **App Store Connect → App Privacy** and **Play Console →
Data safety**. They reflect the app as built (anonymous-first Supabase backend,
Scaleway-hosted DeepSeek V4 Flash AI tutor, OpenAI Whisper pronunciation). Re-verify before each
submission if the data flows change.

## Summary of data that leaves the device

| Data | Where it goes | Purpose | Linked to user? |
|------|---------------|---------|-----------------|
| Learning progress (lesson scores, XP, streaks, badges, SRS state) | Supabase | App functionality (sync) | Yes — anonymous user id + device id |
| Account curriculum-access entitlement (selected support/reviewer accounts only) | Supabase | App functionality (account access) | Yes — anonymous user id |
| AI tutor text (your messages + recent context) | Supabase → Scaleway Generative APIs (DeepSeek V4 Flash model) | App functionality (AI tutor) | Yes, during the request |
| Pronunciation audio clips | Supabase → OpenAI Whisper | App functionality (speech-to-text scoring) | Not stored by Czechify; OpenAI may retain API data for up to 30 days unless zero retention applies |
| Optional email or Google basic account profile | Google → Supabase Auth | Account identity across devices | Yes |
| Installation device id | Supabase | Sync conflict resolution | Yes |

No advertising, no third-party analytics, no tracking across apps/sites.

## Apple — App Privacy answers

**Data used to track you:** None.

**Data linked to you:**
- **User Content → Audio Data** — pronunciation recordings. Purpose: App
  Functionality. Sent for transcription, not used for tracking, not stored by
  Czechify; OpenAI may retain API data for up to 30 days unless zero retention
  applies.
- **User Content → Other User Content** — AI tutor messages, learning progress.
  Purpose: App Functionality.
- **Contact Info → Email Address / Name** — only if the user links email or
  connects Google. Google may also supply a profile image and provider user ID.
  Purpose: App Functionality (account identity).
- **Identifiers → User ID / Device ID** — anonymous Supabase user id +
  install device id. Purpose: App Functionality.

**Data not linked to you:** None additional.

**Account deletion:** Yes — in-app via Settings → Account & data, and via the
public deletion page listed below (satisfies Guideline 5.1.1(v)).

## Google Play — Data safety answers

**Does your app collect or share user data?** Yes (collect; not shared for
advertising/analytics).

- **App activity / App info & performance** — learning progress. Collected,
  linked to user, App functionality. Encrypted in transit. Deletable.
- **Audio → Voice or sound recordings** — pronunciation clips. Collected (sent
  for transcription), encrypted in transit, App functionality. Czechify does
  not store them, but do not select a zero-retention answer unless the OpenAI
  project is actually approved and configured for Zero Data Retention.
- **Personal info → Email address / Name** — optional (email or Google account
  linking only). Declare the Google profile image under the applicable photo
  category if it is retained in the production Supabase user metadata.
- **App activity → Other user-generated content** — AI tutor messages.

**Data handling:**
- Encrypted in transit: **Yes** (HTTPS to Supabase; Supabase → Scaleway/OpenAI
  over HTTPS).
- Users can request data deletion: **Yes** (in-app account deletion + the
  public account-deletion page). The page must be hosted before submission.
- Data collection required or optional: anonymous account creation and progress
  sync occur automatically in a production build when the backend is reachable.
  Email/Google linking, AI tutor/writing evaluation, and cloud pronunciation
  are optional. Device speech may be processed by the operating-system provider.

**Important “shared” answer:** Play's processor/service-provider exception is
contract-specific. Supabase, Scaleway, and OpenAI publish data-processing terms.
The Scaleway inference flow runs in Paris and its default Zero Data Retention
policy says prompts and outputs are not used for training or made available to
model creators. Keep evidence that the applicable provider terms/DPA are
accepted for the production account. When those providers act only on
Czechify's instructions, declare the data as collected for app functionality,
not shared; answer differently if the actual contract or configuration changes.

## Subprocessors to name in the listing / privacy label

- **Supabase** — auth, database sync, storage, Edge Functions (hosting).
- **Google** — optional Google account authentication (email, provider user ID,
  and basic profile fields); no Drive, contacts, or other Google content scope.
- **Scaleway** — Generative APIs hosting the DeepSeek V4 Flash model used for AI conversation, grammar, summaries, and writing evaluation (text), in Paris, France.
- **OpenAI** — Whisper speech-to-text (pronunciation audio).
- **Google Gmail** — support/privacy email and AI-reply reports sent by users.

## Release-blocking privacy operations

- Set Google Play target audience to **16 and over** unless the app is separately
  redesigned and reviewed for the Families policy.
- Retain the production Scaleway account terms/DPA and re-check its Paris/EEA
  hosting and Zero Data Retention status before each release.
- Confirm the OpenAI API project retention setting and keep the public policy's
  “up to 30 days” wording unless Zero Data Retention is actually enabled.
- Follow the published email retention schedule: resolve and remove ordinary
  reports/support mail within 12 months, retaining only minimal accountability
  evidence for up to three years where needed.

## Privacy policy URL

Host the pages in [docs/site](site/README.md) at stable public URLs and enter
the privacy-policy URL and account-deletion URL in Play Console. GitHub Pages
is supported by the included workflow.
