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
const String kPrivacyPolicyVersion = '2026-07-31.1';

/// Bump when the cloud-speech consent wording changes.
const String kVoiceCloudConsentVersion = 'voice-cloud-v2';

const String kDeveloperName = 'Mahesh Pathak';

/// Where a learner reaches a human: data requests, and reports of AI output.
///
/// One constant because three places have to agree — the in-app policy, the
/// public pages under `docs/site/`, and the AI-reply report action. A contact
/// route that differs between them is the kind of thing a store reviewer
/// notices and a user gives up on.
const String kSupportEmail = 'email.czechify@gmail.com';

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
    'Czechify is developed and operated by $kDeveloperName. Any question '
        'about your data, or any request to exercise the rights described '
        'below, can be sent to $kSupportEmail.',
  ),
  LegalSection(
    'The short version',
    'Czechify never asks for your email address, your name, or any other '
        'personal detail in order to work. Your lessons, progress and chat '
        'history live on your device, and your progress is backed up to an '
        'anonymous account so you do not lose it.\n\n'
        'Pronunciation uses your device speech service by default. Optional cloud speech sends data '
        'to services outside the app, and every one of them is listed below. '
        'There is no advertising in this app and no tracking of you across '
        'other apps or websites.',
  ),
  LegalSection(
    'What stays on your device',
    'Your name, learning progress, streaks, badges, review schedule, exam '
        'results, chat history with the AI tutor, downloaded audio, and your '
        'settings are held in a local database on your device. Uninstalling '
        'the app removes them.',
  ),
  LegalSection(
    'Your account',
    'Czechify creates an account for you automatically the first time you '
        'open it. This account is anonymous: it is identified by your device, '
        'and it asks for no email address, no password, no name and no other '
        'personal detail. Its only purpose is to hold your progress so it is '
        'not lost.\n\n'
        'Your lesson progress, badges, streaks and review '
        'schedule are synchronised to that account regularly, so a broken or '
        'reset phone does not cost you your learning.\n\n'
        'If you want to move to a new device, or learn on more than one, you '
        'can add an email address and password to your existing account. That '
        'is the only point at which Czechify holds an email address, it is '
        'entirely your choice, and everything you have already learned carries '
        'across. You can export or delete all of it at any time under '
        'Settings, Account and data.',
  ),
  LegalSection(
    'Pronunciation and your voice',
    'Pronunciation practice records short clips of your speech.\n\n'
        'By default Czechify uses the speech-recognition service available on '
        'your device. Your operating-system provider controls how that service '
        'processes speech. Czechify does not send the recording to its own cloud '
        'speech service unless you explicitly enable the option in Settings.\n\n'
        'If you enable optional cloud pronunciation, Czechify sends the recording '
        'through our server to OpenAI in the United States and receiving a '
        'transcript back. Declining keeps device speech recognition available.\n\n'
        'Nothing is sent anywhere unless you accept that offer, and you can '
        'withdraw your agreement at any time from Settings — withdrawing is as '
        'easy as giving it, and takes effect immediately. When you do agree, '
        'we keep a record of when you agreed and to which version of this '
        'notice, so that both of us can check later what was actually agreed.\n\n'
        'OpenAI states that data submitted through its API is not used to '
        'train its models and is retained only for a limited period for abuse '
        'monitoring. Recordings are not stored on our servers after the '
        'transcript is returned.',
  ),
  LegalSection(
    'AI tutor',
    'Messages you send to the AI tutor, and writing you submit for feedback, '
        'are forwarded through our server to DeepSeek, which processes them '
        'outside the European Economic Area. Your conversation history itself '
        'stays on your device. Please do not include sensitive personal '
        'information in messages to the tutor.\n\n'
        'The tutor is a language model, so it can occasionally produce '
        'something wrong, inappropriate, or offensive. If it does, tap the '
        'flag on that reply to report it. A report sends us the tutor\'s own '
        'words and the scenario you were in — not your side of the '
        'conversation, unless you choose to describe it yourself.',
  ),
  LegalSection(
    'Audio lessons',
    'Spoken Czech in the course is pre-recorded. Your device downloads those '
        'audio files from our storage and keeps them for offline use. '
        'Requesting an audio file tells our server which file was requested, '
        'but sends nothing about you.',
  ),
  LegalSection(
    'Your rights',
    'You can access, export, correct, or delete your data. Export and '
        'deletion are built into the app under Settings, Account and data; '
        'deletion there removes both the local and the cloud copy. You may '
        'also object to processing, ask for it to be restricted, or complain '
        'to your national data protection authority.',
  ),
  LegalSection(
    'Children',
    'Czechify is not directed at children under 16. Czechify does not know your '
        'age, so the cloud pronunciation control asks you to confirm eligibility. '
        'Anyone under 16 must use it only with permission from a parent or guardian.',
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
    'Record yourself and get feedback on the sounds Czech learners find '
        'hardest — ř, č, š, ž, ě and the long vowels — with the analysis '
        'using device speech recognition by default, with optional cloud transcription.',
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
