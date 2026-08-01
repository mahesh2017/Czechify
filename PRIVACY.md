# Privacy Policy

**Last updated:** July 24, 2026

Czechify ("the App") is built with privacy in mind. This policy explains what data the App handles and how.

## Local Data

The App stores curriculum content and learning data locally using SQLite,
SharedPreferences, secure storage, and audio files. This includes lesson
progress, scores, XP, streaks, hearts, badges, vocabulary/SRS state, AI chat
history, and settings.

## Supabase Account, Curriculum, and Sync

When the App is built with its backend enabled, it connects to Supabase and
automatically creates or restores an anonymous account. Supabase provides the
published curriculum and stores selected learning state for synchronization:

- lesson completion, scores, and attempt counts;
- earned badge identifiers;
- streak and exam-completion counters; and
- vocabulary and grammar review scheduling state.

The anonymous Supabase user ID and an installation-specific device ID are
attached to synchronized records. Settings, locally stored chat history, and
audio recordings are not currently synchronized. You can link a verified email
to preserve the same cloud identity, sign in on another device, export local
and cloud learning data as JSON, or delete the cloud account and local learner
data from **Settings → Account & data**. Temporary export files are deleted
after the platform share/save flow completes. Supabase operational backups and
logs may remain for their documented retention periods.

## AI Features

When you use the AI conversation tutor, grammar check, or writing evaluation,
the relevant learner text and recent conversation context are sent over HTTPS
to a Supabase Edge Function and then to DeepSeek for processing. The App uses a
server-managed API credential; users do not provide their own AI key.

The Edge Function authenticates the anonymous/user session, enforces daily and
short-window request quotas, and returns the model response. The App stores the
resulting chat messages locally. Do not include sensitive personal information
in AI prompts.

## Speech & Microphone (Optional)

The App offers pronunciation practice that records short audio clips and
transcribes them to score your pronunciation:

- Microphone access is requested only when you use pronunciation features.
- **Cloud transcription (default when the backend is enabled):** the recorded
  audio clip is sent over HTTPS to a Supabase Edge Function, which forwards it
  to **OpenAI's Whisper** speech-to-text API and returns a transcription with
  word-level confidence. The App uses a server-managed API credential; users do
  not provide their own key. The audio leaves your device for this processing.
- **On-device fallback:** when the backend or a cloud session is unavailable,
  the App falls back to the operating system's speech recognition, which may
  run on-device or via Apple/Google services depending on your platform,
  installed language support, device settings, and network.
- The App does not intentionally retain the microphone recording after
  transcription. The recording is deleted from the device once processed;
  OpenAI, Apple, and Google govern their services under their own terms.
- Do not record sensitive personal information during pronunciation practice.

## Internet Access

The App accesses the internet for Supabase authentication, curriculum delivery,
learning-state sync, course audio, AI features, and supported speech/audio
fallbacks.

## Analytics & Tracking

The App does **not** currently include analytics, advertising, or crash-reporting
SDKs. Supabase and DeepSeek may generate operational/security logs under their
own terms when their services are used.

## Children's Privacy

The App is intended for general audiences and does not knowingly collect personal information from children under 13.

## Changes

We may update this policy. Changes will be reflected in the App.

## Contact

This app is maintained as an open educational project. For questions, open an issue on GitHub: [github.com/mahesh2017/Czechify](https://github.com/mahesh2017/Czechify)
