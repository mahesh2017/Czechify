# Store Data-Safety Answer Sheet — Czechify

Copy these answers into **App Store Connect → App Privacy** and **Play Console →
Data safety**. They reflect the app as built (anonymous-first Supabase backend,
DeepSeek AI tutor, OpenAI Whisper pronunciation). Re-verify before each
submission if the data flows change.

## Summary of data that leaves the device

| Data | Where it goes | Purpose | Linked to user? |
|------|---------------|---------|-----------------|
| Learning progress (lesson scores, XP, streaks, badges, SRS state) | Supabase | App functionality (sync) | Yes — anonymous user id + device id |
| AI tutor text (your messages + recent context) | Supabase → DeepSeek | App functionality (AI tutor) | Yes, during the request |
| Pronunciation audio clips | Supabase → OpenAI Whisper | App functionality (speech-to-text scoring) | Transient; not stored after transcription |
| Optional linked email | Supabase Auth | Account identity across devices | Yes |
| Installation device id | Supabase | Sync conflict resolution | Yes |

No advertising, no third-party analytics, no tracking across apps/sites.

## Apple — App Privacy answers

**Data used to track you:** None.

**Data linked to you:**
- **User Content → Audio Data** — pronunciation recordings. Purpose: App
  Functionality. (Sent for transcription; not used for tracking; not stored
  after processing.)
- **User Content → Other User Content** — AI tutor messages, learning progress.
  Purpose: App Functionality.
- **Contact Info → Email Address** — only if the user links an account.
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
  for transcription), **not stored**, encrypted in transit, App functionality.
  Answer "collected" (transient processing), "not shared" for ads.
- **Personal info → Email address** — optional (account linking only).
- **App activity → Other user-generated content** — AI tutor messages.

**Data handling:**
- Encrypted in transit: **Yes** (HTTPS to Supabase; Supabase → DeepSeek/OpenAI
  over HTTPS).
- Users can request data deletion: **Yes** (in-app account deletion + the
  public account-deletion page). The page must be hosted before submission.
- Data collection required or optional: cloud sync/AI/pronunciation are
  optional in the sense that core learning works offline; using those features
  sends the data described above.

## Subprocessors to name in the listing / privacy label

- **Supabase** — auth, database sync, storage, Edge Functions (hosting).
- **DeepSeek** — AI conversation/grammar/writing evaluation (text).
- **OpenAI** — Whisper speech-to-text (pronunciation audio).

## Privacy policy URL

Host the pages in [docs/site](site/README.md) at stable public URLs and enter
the privacy-policy URL and account-deletion URL in Play Console. GitHub Pages
is supported by the included workflow.
