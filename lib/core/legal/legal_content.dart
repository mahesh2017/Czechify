/// Legal and informational copy shown inside the app.
///
/// Kept in one place, and versioned, for a specific reason: when a learner
/// consents to something, the record has to say *what wording they saw*.
/// "User consented" is close to worthless in a dispute — GDPR Article 7(1)
/// puts the burden on the controller to demonstrate consent, and that means
/// being able to reproduce the exact text. A stored version string that is
/// generated from the same constant the screen renders cannot drift from it.
library;

import 'package:flutter/widgets.dart' show IconData;

/// Bump whenever the privacy policy text changes in a way that affects what a
/// learner is agreeing to. Consent records store this value.
const String kPrivacyPolicyVersion = '2026-08-30.1';

/// Bump when the cloud-speech consent wording changes.
const String kVoiceCloudConsentVersion = 'voice-cloud-v3';

const String kDeveloperName = 'Mahesh Pathak';

/// Where a learner reaches a human: data requests, and reports of AI output.
///
/// One constant because three places have to agree — the in-app policy, the
/// public pages under `docs/site/`, and the AI-reply report action. A contact
/// route that differs between them is the kind of thing a store reviewer
/// notices and a user gives up on.
const String kSupportEmail = 'email.czechify@gmail.com';

/// Canonical public pages used by the app and the Play Console listing.
///
/// Keeping them beside the legal copy prevents a future domain/path change
/// from leaving Settings, About, and the store metadata pointing at different
/// policies.
const String kWebsiteUrl = 'https://eminentsite.cz/czechify/';
const String kPrivacyPolicyUrl = 'https://eminentsite.cz/czechify/privacy.html';
const String kAccountDeletionUrl =
    'https://eminentsite.cz/czechify/delete-account.html';
const String kGooglePlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.eminentsite.czechify';

class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading;
  final String body;
}

/// Shown in full inside the app — never a link out to a website. A learner
/// should not have to leave the app, or have a browser, to read what happens
/// to their data.
const List<LegalSection> kPrivacyPolicy = [
  LegalSection(
    'Who is responsible',
    'Czechify is operated by $kDeveloperName, Příčná 1892/4, Nové Město, '
        '110 00 Praha, Czechia. He is the data controller. Privacy questions '
        'and rights requests can be sent to $kSupportEmail. No data protection '
        'officer has been appointed because Czechify\'s current processing '
        'does not require one.',
  ),
  LegalSection(
    'The short version',
    'Czechify automatically creates an anonymous cloud account and syncs '
        'learning data to it. You may optionally connect Google or link an '
        'email address. The '
        'optional learner profile (name, level, study goal, focus, pace and '
        'reminder preference) and placement result sync so a recovered '
        'account is ready on another device. AI chat history, exam results, '
        'device settings and downloaded lesson audio stay on your device. AI tutor '
        'text and optional cloud-pronunciation audio leave the device as '
        'described below.\n\n'
        'There are no ads, third-party analytics or crash-reporting SDKs, and '
        'no cross-app or cross-site tracking.',
  ),
  LegalSection(
    'What we process and why',
    'To provide Czechify under GDPR Article 6(1)(b), we process an anonymous '
        'account ID, installation ID, synced lesson completion and scores, XP, '
        'streaks, badges, review/SRS state, custom cards and gamification '
        'state, placement result, and the optional learner profile and reminder '
        'preference you choose, plus any support or reviewer '
        'curriculum-access entitlement. Study goals such as residence, work or '
        'family are optional and are used only to shape your learning plan. '
        'If you link email, Supabase also processes your email and password '
        'credential for sign-in and recovery; Czechify never receives the '
        'plain-text password. If you connect Google, Google and Supabase '
        'process the selected account email, provider account identifier and '
        'basic profile fields for authentication. Czechify requests no access '
        'to Google Drive, contacts or other Google content.\n\n'
        'When you request AI tutoring, correction or writing evaluation, the '
        'text and recent context are processed to perform that request under '
        'Article 6(1)(b). When you enable cloud speech, a short recording is '
        'processed on consent under Article 6(1)(a).\n\n'
        'Daily usage counters and ordinary network/security metadata such as '
        'IP address, user agent, time and status are processed for the '
        'legitimate interests in security, abuse prevention and reliable '
        'operation under Article 6(1)(f). Privacy requests are processed to '
        'meet legal obligations under Article 6(1)(c).',
  ),
  LegalSection(
    'Local data and your account',
    'AI conversation history, exam results, visual/device settings, notification '
        'permission and scheduled notification identifiers, device consent '
        'history and downloaded lesson audio are local. Your optional name, '
        'learning goal, level, focus, study pace, teacher choice, reminder '
        'preference, placement and learning progress also have a local copy and '
        'are synced to your account. Authentication tokens use Android Keystore '
        'or Apple Keychain facilities, and Android app backup is disabled.\n\n'
        'The first time you use Czechify, it creates a random anonymous '
        'Supabase user ID without asking for an email, password or name. You '
        'can optionally connect Google or link an email and password for '
        'recovery and multi-device use. After account deletion, continuing to use the app '
        'creates a new, empty anonymous account; deleted progress is not '
        'restored.',
  ),
  LegalSection(
    'Pronunciation and your voice',
    'By default, Czechify uses your device speech-recognition service. It may '
        'process speech locally or through your operating-system provider, '
        'depending on the device and its settings.\n\n'
        'Cloud speech is off until you allow it. When enabled, a short clip is '
        'sent over encrypted connections through Supabase to OpenAI in the '
        'United States. Czechify does not persist the recording or transcript '
        'in its cloud database and removes its temporary local recording after '
        'the attempt. OpenAI says API data is not used for model training by '
        'default and may be retained for abuse monitoring for up to 30 days '
        'unless zero data retention applies.\n\n'
        'You can switch cloud speech off at any time. Withdrawal affects '
        'future recordings and does not make earlier processing unlawful. A '
        'local consent record stores the time, decision and notice version '
        'until app data is cleared.',
  ),
  LegalSection(
    'AI tutor',
    'Messages, recent context and writing you submit are relayed through '
        'Supabase to Scaleway SAS, which runs the selected DeepSeek V4 Flash '
        'model on Scaleway infrastructure in Paris, France. The request body does not '
        'contain your Czechify account ID or linked email. Your full history '
        'stays on the device. Scaleway says the model creator cannot access '
        'prompts or outputs and they are not used for model training. Never '
        'submit sensitive personal information.\n\n'
        'AI output can be inaccurate or inappropriate and is not professional '
        'advice. It does not make legal or similarly significant decisions '
        'about you. Reporting a reply opens your email app with the tutor '
        'output, scenario, time, reason and any note you add.',
  ),
  LegalSection(
    'Recipients and transfers',
    'Supabase processes authentication, synced data, storage, Edge Functions, '
        'quotas and infrastructure logs. Czechify\'s primary project data is '
        'in Paris, France, within the European Union. Supabase\'s Data '
        'Processing Addendum uses Standard Contractual Clauses where required '
        'for onward transfers.\n\n'
        'OpenAI Ireland Ltd/OpenAI, L.L.C. processes cloud-speech clips. Its '
        'Data Processing Addendum uses adequacy decisions and Standard '
        'Contractual Clauses for restricted transfers. Scaleway processes AI '
        'text in Paris, France, without sending it to the model creator or '
        'another model service. Google processes optional Google account '
        'authentication. Google Gmail and '
        'your email provider process privacy emails or reports you choose to '
        'send, which may involve the United States.\n\n'
        'Lesson audio and curriculum are downloaded from Supabase Storage. The '
        'request identifies the file and includes ordinary network metadata.',
  ),
  LegalSection(
    'Retention and deletion',
    'Local learner data remains until in-app deletion, clearing app storage or '
        'uninstalling. Downloaded non-personal lesson audio is removed '
        'separately through Settings, Downloads, Clear audio cache, by '
        'clearing storage, or by uninstalling. Cloud account data remains '
        'until deletion; unlinked anonymous accounts are scheduled for '
        'deletion after 90 inactive days. Provider backups and security logs '
        'expire under their time-limited schedules.\n\n'
        'OpenAI may retain API data for up to 30 days unless zero retention '
        'applies. Scaleway\'s default Zero Data Retention policy says prompts '
        'and outputs are not retained in ordinary operation. Anonymised usage '
        'metadata may remain up to six months; relevant request content may be '
        'kept up to two weeks in rare error, security, harmful-content or '
        'misuse investigations. AI reports/support mail are kept while '
        'handled and normally '
        'no longer than 12 months afterwards; minimal proof of a completed '
        'privacy request may be kept up to three years unless law or a legal '
        'claim requires longer.',
  ),
  LegalSection(
    'Security',
    'Czechify uses HTTPS/TLS, owner-scoped database row-level security, '
        'authenticated Edge Functions, server-side provider secrets, rate '
        'limits and secure operating-system session storage. No internet '
        'service can promise absolute security. Contact us if you suspect a '
        'problem.',
  ),
  LegalSection(
    'Your rights',
    'Subject to GDPR conditions, you may request access, correction, deletion, '
        'restriction or portability, object to legitimate-interest processing, '
        'and withdraw consent without affecting processing that was lawful '
        'before withdrawal. Export and deletion are under Settings, Account '
        'and data. External deletion instructions are on the Czechify website. '
        'We normally respond within one month.\n\n'
        'You may complain to the Czech Úřad pro ochranu osobních údajů '
        '(uoou.gov.cz), Pplk. Sochora 27, 170 00 Praha 7, or the competent '
        'authority where you live or work.',
  ),
  LegalSection(
    'Children',
    'Czechify is not directed to children under 16 and should be used/listed '
        'for ages 16 and over. Czechify does not collect a birth date. A person '
        'under 16 must not enable cloud speech or submit personal data to an AI '
        'feature. Contact $kSupportEmail if you believe a child has done so.',
  ),
  LegalSection(
    'Changes',
    'This policy is version $kPrivacyPolicyVersion. If it changes in a way '
        'that affects what you have agreed to, you will be asked again rather '
        'than opted in silently.',
  ),
];

class AppFeature {
  const AppFeature(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const List<AppFeature> kAppFeatures = [
  AppFeature(
    IconData(0xe80c, fontFamily: 'MaterialIcons'), // school
    'A complete A1 to A2 course',
    '31 units, 61 lessons and over 770 exercises, following the CEFR levels '
        'from complete beginner to elementary. Each unit builds on the one '
        'before, and nothing is skipped.',
  ),
  AppFeature(
    IconData(0xe050, fontFamily: 'MaterialIcons'), // volume_up
    'Every Czech word spoken aloud',
    'Nearly 3,000 phrases recorded in studio quality, in a male or female '
        'voice you choose. The first units are saved to your device so they '
        'work without a connection.',
  ),
  AppFeature(
    IconData(0xe029, fontFamily: 'MaterialIcons'), // mic
    'Pronunciation practice',
    'Read a prompted phrase and see how closely the words recognised by '
        'speech recognition match the target. This can flag missed or unclear '
        'words, but it does not diagnose individual Czech sounds or replace '
        'feedback from a teacher. Device speech recognition is the default; '
        'cloud transcription is optional.',
  ),
  AppFeature(
    IconData(0xe0b7, fontFamily: 'MaterialIcons'), // chat
    'AI conversation tutor',
    'Practise real situations — ordering food, asking directions, '
        'introducing yourself — with a tutor that replies in Czech at your '
        'level and explains what you got wrong.',
  ),
  AppFeature(
    IconData(0xe8f0, fontFamily: 'MaterialIcons'), // trending_up
    'Spaced repetition that remembers for you',
    'Words you find difficult come back more often, words you know fade '
        'away. Reviews are scheduled so you revisit each item just before you '
        'would have forgotten it.',
  ),
  AppFeature(
    IconData(0xe3c9, fontFamily: 'MaterialIcons'), // edit
    'Grammar you can actually look up',
    'Declension and conjugation tables, per-unit grammar notes and cheat '
        'sheets, all available offline and unlocked as you reach each unit.',
  ),
  AppFeature(
    IconData(0xe1a3, fontFamily: 'MaterialIcons'), // fact_check
    'Exam preparation',
    'Dedicated A1 and A2 exam units with graded practice covering reading, '
        'listening, writing and speaking. These are unverified practice activities, not official exam results.',
  ),
  AppFeature(
    IconData(0xe409, fontFamily: 'MaterialIcons'), // insights
    'Progress worth watching',
    'Streaks, daily goals, badges and per-skill statistics, so you can see '
        'what is improving and what needs work.',
  ),
];
