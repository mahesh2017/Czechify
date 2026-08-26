import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('en'),
  ];

  /// Application name shown in the task switcher
  ///
  /// In en, this message translates to:
  /// **'Czechify'**
  String get appTitle;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @nextPhrase.
  ///
  /// In en, this message translates to:
  /// **'Next Phrase'**
  String get nextPhrase;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get goHome;

  /// No description provided for @startExam.
  ///
  /// In en, this message translates to:
  /// **'Start Exam'**
  String get startExam;

  /// No description provided for @resumeExam.
  ///
  /// In en, this message translates to:
  /// **'Resume Exam'**
  String get resumeExam;

  /// No description provided for @discardAndStartOver.
  ///
  /// In en, this message translates to:
  /// **'Discard and start over'**
  String get discardAndStartOver;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get startRecording;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get stopRecording;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @pronunciationLab.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation Lab'**
  String get pronunciationLab;

  /// No description provided for @sayThis.
  ///
  /// In en, this message translates to:
  /// **'Say this:'**
  String get sayThis;

  /// No description provided for @tapMicrophoneHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone and say the phrase'**
  String get tapMicrophoneHint;

  /// No description provided for @analyzingPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your pronunciation...'**
  String get analyzingPronunciation;

  /// No description provided for @onDeviceRecognitionNote.
  ///
  /// In en, this message translates to:
  /// **'Using on-device recognition — results may be less accurate.'**
  String get onDeviceRecognitionNote;

  /// Bottom navigation label. Keep short — it sits under an icon in a five-item bar.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get navLearn;

  /// No description provided for @navReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get navReview;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get settingsYourName;

  /// No description provided for @settingsDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get settingsDailyGoal;

  /// No description provided for @settingsXpPerDay.
  ///
  /// In en, this message translates to:
  /// **'{count} XP per day'**
  String settingsXpPerDay(int count);

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Language of the app's own interface, not the language being learned.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsSoundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get settingsSoundEffects;

  /// No description provided for @settingsVibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get settingsVibration;

  /// No description provided for @settingsHearts.
  ///
  /// In en, this message translates to:
  /// **'Hearts in lessons'**
  String get settingsHearts;

  /// No description provided for @settingsTestVoice.
  ///
  /// In en, this message translates to:
  /// **'Test voice'**
  String get settingsTestVoice;

  /// No description provided for @settingsVoiceMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get settingsVoiceMale;

  /// No description provided for @settingsVoiceFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get settingsVoiceFemale;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About Czechify'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsClearAudioCache.
  ///
  /// In en, this message translates to:
  /// **'Clear audio cache'**
  String get settingsClearAudioCache;

  /// No description provided for @settingsFirstName.
  ///
  /// In en, this message translates to:
  /// **'Your first name'**
  String get settingsFirstName;

  /// No description provided for @settingsSwitchLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to {level}?'**
  String settingsSwitchLevelTitle(String level);

  /// No description provided for @settingsSwitchLevel.
  ///
  /// In en, this message translates to:
  /// **'Switch to {level}'**
  String settingsSwitchLevel(String level);

  /// No description provided for @settingsSwitchUpBody.
  ///
  /// In en, this message translates to:
  /// **'A2 opens from its first unit, and everything you have already finished in A1 stays open. The tutor will pitch its Czech higher.\n\nA2 audio will download now, which needs a connection and a few megabytes.'**
  String get settingsSwitchUpBody;

  /// No description provided for @settingsSwitchDownBody.
  ///
  /// In en, this message translates to:
  /// **'The tutor will pitch its Czech lower and A1 audio will be kept on your device.\n\nUnits you have already unlocked stay unlocked — going back to revise costs you nothing.'**
  String get settingsSwitchDownBody;

  /// No description provided for @settingsLevelOpened.
  ///
  /// In en, this message translates to:
  /// **'{level} is now open.'**
  String settingsLevelOpened(String level);

  /// No description provided for @settingsLevelSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to {level}. Units you had already unlocked stay open.'**
  String settingsLevelSwitched(String level);

  /// No description provided for @settingsProfileGroup.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfileGroup;

  /// No description provided for @settingsNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsNotSet;

  /// No description provided for @settingsAccountGroup.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountGroup;

  /// No description provided for @settingsAccountDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Account, sign in & data'**
  String get settingsAccountDataTitle;

  /// No description provided for @settingsAccountDataBody.
  ///
  /// In en, this message translates to:
  /// **'Protect, recover, export, or delete your data'**
  String get settingsAccountDataBody;

  /// No description provided for @settingsAppearanceGroup.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceGroup;

  /// No description provided for @settingsLearningGroup.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get settingsLearningGroup;

  /// No description provided for @settingsCourseLevel.
  ///
  /// In en, this message translates to:
  /// **'Course level'**
  String get settingsCourseLevel;

  /// No description provided for @settingsA1Beginner.
  ///
  /// In en, this message translates to:
  /// **'A1 · beginner'**
  String get settingsA1Beginner;

  /// No description provided for @settingsA2UpperBeginner.
  ///
  /// In en, this message translates to:
  /// **'A2 · upper beginner'**
  String get settingsA2UpperBeginner;

  /// No description provided for @settingsHeartsBody.
  ///
  /// In en, this message translates to:
  /// **'Off = practice freely'**
  String get settingsHeartsBody;

  /// No description provided for @settingsSoundBody.
  ///
  /// In en, this message translates to:
  /// **'Answers and celebrations'**
  String get settingsSoundBody;

  /// No description provided for @settingsHapticsBody.
  ///
  /// In en, this message translates to:
  /// **'A tap you can feel'**
  String get settingsHapticsBody;

  /// No description provided for @settingsRemindersGroup.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsRemindersGroup;

  /// No description provided for @settingsAudioGroup.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsAudioGroup;

  /// No description provided for @settingsSpeechRate.
  ///
  /// In en, this message translates to:
  /// **'Speech rate'**
  String get settingsSpeechRate;

  /// No description provided for @settingsSpeechRateBody.
  ///
  /// In en, this message translates to:
  /// **'1x is the pace the lessons were recorded at'**
  String get settingsSpeechRateBody;

  /// No description provided for @settingsTestVoiceBody.
  ///
  /// In en, this message translates to:
  /// **'Play a sample Czech phrase'**
  String get settingsTestVoiceBody;

  /// No description provided for @settingsCloudPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Optional cloud pronunciation'**
  String get settingsCloudPronunciation;

  /// No description provided for @settingsCloudPronunciationBody.
  ///
  /// In en, this message translates to:
  /// **'Off = your phone checks it. On = clearer scoring, recording sent for transcription'**
  String get settingsCloudPronunciationBody;

  /// No description provided for @settingsRetrySync.
  ///
  /// In en, this message translates to:
  /// **'Retry failed sync'**
  String get settingsRetrySync;

  /// No description provided for @settingsRetryingItems.
  ///
  /// In en, this message translates to:
  /// **'Retrying {count} item(s)'**
  String settingsRetryingItems(int count);

  /// No description provided for @settingsClearAudioBody.
  ///
  /// In en, this message translates to:
  /// **'Remove cached audio files'**
  String get settingsClearAudioBody;

  /// No description provided for @settingsAudioCleared.
  ///
  /// In en, this message translates to:
  /// **'Audio cache cleared'**
  String get settingsAudioCleared;

  /// No description provided for @settingsAccountDataGroup.
  ///
  /// In en, this message translates to:
  /// **'Account & data'**
  String get settingsAccountDataGroup;

  /// No description provided for @settingsExportDelete.
  ///
  /// In en, this message translates to:
  /// **'Export & deletion'**
  String get settingsExportDelete;

  /// No description provided for @settingsExportDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Export or delete your data'**
  String get settingsExportDeleteBody;

  /// No description provided for @settingsAboutGroup.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutGroup;

  /// No description provided for @settingsAboutBody.
  ///
  /// In en, this message translates to:
  /// **'What the app does · by {name}'**
  String settingsAboutBody(String name);

  /// No description provided for @settingsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Read in full, in the app'**
  String get settingsPrivacyBody;

  /// No description provided for @settingsDownloadConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to save {subject}'**
  String settingsDownloadConnectTitle(String subject);

  /// No description provided for @settingsDownloadSavingTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving {subject}'**
  String settingsDownloadSavingTitle(String subject);

  /// No description provided for @settingsDownloadOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'{subject} is not saved on your device yet, and there is no connection right now. Connect to Wi-Fi or mobile data and try again — it is only a few megabytes.'**
  String settingsDownloadOfflineBody(String subject);

  /// No description provided for @settingsDownloadingClips.
  ///
  /// In en, this message translates to:
  /// **'Downloading {count} clips so this works offline too.'**
  String settingsDownloadingClips(int count);

  /// No description provided for @settingsNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get settingsNotNow;

  /// No description provided for @settingsHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get settingsHide;

  /// No description provided for @settingsUnitsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} units'**
  String settingsUnitsCount(int count);

  /// No description provided for @settingsLevelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get settingsLevelBeginner;

  /// No description provided for @settingsLevelUpperBeginner.
  ///
  /// In en, this message translates to:
  /// **'Upper beginner'**
  String get settingsLevelUpperBeginner;

  /// No description provided for @settingsLevelA1Audience.
  ///
  /// In en, this message translates to:
  /// **'Start here if you are new to Czech.'**
  String get settingsLevelA1Audience;

  /// No description provided for @settingsLevelCurrent.
  ///
  /// In en, this message translates to:
  /// **'This is your level'**
  String get settingsLevelCurrent;

  /// No description provided for @settingsTeacherVoice.
  ///
  /// In en, this message translates to:
  /// **'Teacher\'s voice'**
  String get settingsTeacherVoice;

  /// No description provided for @settingsAudioSubject.
  ///
  /// In en, this message translates to:
  /// **'{level} audio'**
  String settingsAudioSubject(String level);

  /// No description provided for @settingsVoiceSubjectMale.
  ///
  /// In en, this message translates to:
  /// **'the male voice'**
  String get settingsVoiceSubjectMale;

  /// No description provided for @settingsVoiceSubjectFemale.
  ///
  /// In en, this message translates to:
  /// **'the female voice'**
  String get settingsVoiceSubjectFemale;

  /// No description provided for @settingsChooseLevel.
  ///
  /// In en, this message translates to:
  /// **'Choose your course level'**
  String get settingsChooseLevel;

  /// No description provided for @settingsChooseLevelBody.
  ///
  /// In en, this message translates to:
  /// **'You can change this later. Nothing you have finished is lost either way.'**
  String get settingsChooseLevelBody;

  /// No description provided for @settingsLevelA1Body.
  ///
  /// In en, this message translates to:
  /// **'Start from Czech sounds and spelling. Meet people, say who you are and what you do, ask for what you need, handle numbers, time and everyday errands.'**
  String get settingsLevelA1Body;

  /// No description provided for @settingsLevelA2Body.
  ///
  /// In en, this message translates to:
  /// **'Talk about what happened and what you plan to do, give directions and preferences, compare and choose, and deal with shops, appointments and things going wrong.'**
  String get settingsLevelA2Body;

  /// No description provided for @settingsLevelA2Audience.
  ///
  /// In en, this message translates to:
  /// **'Choose this if you can already introduce yourself and hold a simple present-tense conversation.'**
  String get settingsLevelA2Audience;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account & data'**
  String get accountTitle;

  /// No description provided for @accountCloudUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud account unavailable'**
  String get accountCloudUnavailableTitle;

  /// No description provided for @accountCloudUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The app is offline or cloud configuration is unavailable.'**
  String get accountCloudUnavailableBody;

  /// No description provided for @accountReviewerAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviewer access active'**
  String get accountReviewerAccessTitle;

  /// No description provided for @accountReviewerAccessBody.
  ///
  /// In en, this message translates to:
  /// **'All course units and lessons are available on this account.'**
  String get accountReviewerAccessBody;

  /// No description provided for @accountGoogleConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Google account connected'**
  String get accountGoogleConnectedTitle;

  /// No description provided for @accountGoogleConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'You can use Google to sign in and recover your learning progress.'**
  String get accountGoogleConnectedBody;

  /// No description provided for @accountProtectWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Protect progress with email'**
  String get accountProtectWithEmail;

  /// No description provided for @accountSignInExisting.
  ///
  /// In en, this message translates to:
  /// **'Sign in to an existing account'**
  String get accountSignInExisting;

  /// No description provided for @accountSetOrChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Set or change password'**
  String get accountSetOrChangePassword;

  /// No description provided for @accountSendRecovery.
  ///
  /// In en, this message translates to:
  /// **'Send password recovery email'**
  String get accountSendRecovery;

  /// No description provided for @accountYourData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get accountYourData;

  /// No description provided for @accountExportJson.
  ///
  /// In en, this message translates to:
  /// **'Export my data as JSON'**
  String get accountExportJson;

  /// No description provided for @accountDeleteCloudLocal.
  ///
  /// In en, this message translates to:
  /// **'Delete cloud account and local data'**
  String get accountDeleteCloudLocal;

  /// No description provided for @accountDeletionInstructions.
  ///
  /// In en, this message translates to:
  /// **'Account deletion instructions online'**
  String get accountDeletionInstructions;

  /// No description provided for @accountRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'The request could not be completed. Try again.'**
  String get accountRequestFailed;

  /// No description provided for @accountGoogleLinkedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Google account connected. Your progress is protected.'**
  String get accountGoogleLinkedSuccess;

  /// No description provided for @accountGoogleAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'This Google account is already connected.'**
  String get accountGoogleAlreadyLinked;

  /// No description provided for @accountGoogleDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'this Google account'**
  String get accountGoogleDefaultLabel;

  /// No description provided for @accountUseExistingTitle.
  ///
  /// In en, this message translates to:
  /// **'Use existing Czechify account?'**
  String get accountUseExistingTitle;

  /// No description provided for @accountUseExistingBody.
  ///
  /// In en, this message translates to:
  /// **'{account} already has a Czechify account. This device will replace its local learner progress with that account’s synced progress. Export first if you need a copy.'**
  String accountUseExistingBody(String account);

  /// No description provided for @accountSignInReplace.
  ///
  /// In en, this message translates to:
  /// **'Sign in and replace'**
  String get accountSignInReplace;

  /// No description provided for @accountGoogleRecovered.
  ///
  /// In en, this message translates to:
  /// **'Google account recovered and synchronized.'**
  String get accountGoogleRecovered;

  /// No description provided for @accountGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in could not be completed. Try again.'**
  String get accountGoogleFailed;

  /// No description provided for @accountProtectProgress.
  ///
  /// In en, this message translates to:
  /// **'Protect progress'**
  String get accountProtectProgress;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmail;

  /// No description provided for @accountVerificationSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent. Open its link, then set a password here.'**
  String get accountVerificationSent;

  /// No description provided for @accountSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get accountSetPassword;

  /// No description provided for @accountPasswordMinimum.
  ///
  /// In en, this message translates to:
  /// **'Password (at least 8 characters)'**
  String get accountPasswordMinimum;

  /// No description provided for @accountPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get accountPasswordTooShort;

  /// No description provided for @accountPasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get accountPasswordUpdated;

  /// No description provided for @accountReplaceLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace local learner data?'**
  String get accountReplaceLocalTitle;

  /// No description provided for @accountReplaceLocalBody.
  ///
  /// In en, this message translates to:
  /// **'This device will remove its current learner progress, sign in, and download the selected account. Export first if you need a copy.'**
  String get accountReplaceLocalBody;

  /// No description provided for @accountRecovered.
  ///
  /// In en, this message translates to:
  /// **'Account recovered and synchronized.'**
  String get accountRecovered;

  /// No description provided for @accountPasswordRecovery.
  ///
  /// In en, this message translates to:
  /// **'Password recovery'**
  String get accountPasswordRecovery;

  /// No description provided for @accountAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'Account email'**
  String get accountAccountEmail;

  /// No description provided for @accountRecoverySent.
  ///
  /// In en, this message translates to:
  /// **'If that account exists, a recovery email has been sent.'**
  String get accountRecoverySent;

  /// No description provided for @accountExportPrepared.
  ///
  /// In en, this message translates to:
  /// **'Export prepared.'**
  String get accountExportPrepared;

  /// No description provided for @accountPermanentDelete.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete account'**
  String get accountPermanentDelete;

  /// No description provided for @accountDeletePhrase.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE MY ACCOUNT'**
  String get accountDeletePhrase;

  /// No description provided for @accountPhraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'Confirmation phrase did not match.'**
  String get accountPhraseMismatch;

  /// No description provided for @accountConfirmIdentity.
  ///
  /// In en, this message translates to:
  /// **'Confirm it is you'**
  String get accountConfirmIdentity;

  /// No description provided for @accountPassword.
  ///
  /// In en, this message translates to:
  /// **'Account password'**
  String get accountPassword;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Cloud account and learner data deleted.'**
  String get accountDeleted;

  /// No description provided for @accountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountSignIn;

  /// No description provided for @accountAnonymousTitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous account'**
  String get accountAnonymousTitle;

  /// No description provided for @accountProtectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Protected account'**
  String get accountProtectedTitle;

  /// No description provided for @accountAnonymousBody.
  ///
  /// In en, this message translates to:
  /// **'Progress syncs on this installation, but cannot be recovered on another device until you connect Google or link an email.'**
  String get accountAnonymousBody;

  /// No description provided for @accountEmailLinked.
  ///
  /// In en, this message translates to:
  /// **'Email identity linked'**
  String get accountEmailLinked;

  /// No description provided for @accountSignInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get accountSignInGoogle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Learn Czech properly — CEFR A1 to A2'**
  String get aboutTagline;

  /// No description provided for @aboutFeatures.
  ///
  /// In en, this message translates to:
  /// **'What Czechify gives you'**
  String get aboutFeatures;

  /// No description provided for @aboutFeatureCourseTitle.
  ///
  /// In en, this message translates to:
  /// **'A complete A1 to A2 course'**
  String get aboutFeatureCourseTitle;

  /// No description provided for @aboutFeatureCourseBody.
  ///
  /// In en, this message translates to:
  /// **'31 units, 61 lessons and over 770 exercises, following the CEFR levels from complete beginner to elementary. Each unit builds on the one before, and nothing is skipped.'**
  String get aboutFeatureCourseBody;

  /// No description provided for @aboutFeatureAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Every Czech word spoken aloud'**
  String get aboutFeatureAudioTitle;

  /// No description provided for @aboutFeatureAudioBody.
  ///
  /// In en, this message translates to:
  /// **'Nearly 3,000 phrases recorded in studio quality, in a male or female voice you choose. The first units are saved to your device so they work without a connection.'**
  String get aboutFeatureAudioBody;

  /// No description provided for @aboutFeaturePronunciationTitle.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation practice'**
  String get aboutFeaturePronunciationTitle;

  /// No description provided for @aboutFeaturePronunciationBody.
  ///
  /// In en, this message translates to:
  /// **'Read a prompted phrase and see how closely the words recognised by speech recognition match the target. This can flag missed or unclear words, but it does not diagnose individual Czech sounds or replace feedback from a teacher. Device speech recognition is the default; cloud transcription is optional.'**
  String get aboutFeaturePronunciationBody;

  /// No description provided for @aboutFeatureTutorTitle.
  ///
  /// In en, this message translates to:
  /// **'AI conversation tutor'**
  String get aboutFeatureTutorTitle;

  /// No description provided for @aboutFeatureTutorBody.
  ///
  /// In en, this message translates to:
  /// **'Practise real situations — ordering food, asking directions, introducing yourself — with a tutor that replies in Czech at your level and explains what you got wrong.'**
  String get aboutFeatureTutorBody;

  /// No description provided for @aboutFeatureReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Spaced repetition that remembers for you'**
  String get aboutFeatureReviewTitle;

  /// No description provided for @aboutFeatureReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Words you find difficult come back more often, words you know fade away. Reviews are scheduled so you revisit each item just before you would have forgotten it.'**
  String get aboutFeatureReviewBody;

  /// No description provided for @aboutFeatureGrammarTitle.
  ///
  /// In en, this message translates to:
  /// **'Grammar you can actually look up'**
  String get aboutFeatureGrammarTitle;

  /// No description provided for @aboutFeatureGrammarBody.
  ///
  /// In en, this message translates to:
  /// **'Declension and conjugation tables, per-unit grammar notes and cheat sheets, all available offline and unlocked as you reach each unit.'**
  String get aboutFeatureGrammarBody;

  /// No description provided for @aboutFeatureExamTitle.
  ///
  /// In en, this message translates to:
  /// **'Exam preparation'**
  String get aboutFeatureExamTitle;

  /// No description provided for @aboutFeatureExamBody.
  ///
  /// In en, this message translates to:
  /// **'Dedicated A1 and A2 exam units with graded practice covering reading, listening, writing and speaking. These are unverified practice activities, not official exam results.'**
  String get aboutFeatureExamBody;

  /// No description provided for @aboutFeatureProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress worth watching'**
  String get aboutFeatureProgressTitle;

  /// No description provided for @aboutFeatureProgressBody.
  ///
  /// In en, this message translates to:
  /// **'Streaks, daily goals, badges and per-skill statistics, so you can see what is improving and what needs work.'**
  String get aboutFeatureProgressBody;

  /// No description provided for @aboutYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get aboutYourAccount;

  /// No description provided for @aboutAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Czechify creates an anonymous account automatically — no email, password or name required. Progress syncs to that account. Connect Google or add an email and password if you want to recover it or use it on another device.'**
  String get aboutAccountBody;

  /// No description provided for @aboutDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get aboutDeveloper;

  /// No description provided for @aboutDeveloperBody.
  ///
  /// In en, this message translates to:
  /// **'Designed, built and maintained by {name}.'**
  String aboutDeveloperBody(String name);

  /// No description provided for @aboutOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get aboutOnline;

  /// No description provided for @aboutOfficialWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official Czechify website'**
  String get aboutOfficialWebsite;

  /// No description provided for @aboutOnlinePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Online privacy policy'**
  String get aboutOnlinePrivacy;

  /// No description provided for @aboutUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get aboutUpdates;

  /// No description provided for @updateCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheckTitle;

  /// No description provided for @updateCheckBody.
  ///
  /// In en, this message translates to:
  /// **'Get the latest Czechify version from Google Play'**
  String get updateCheckBody;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'A Czechify update is available'**
  String get updateAvailableTitle;

  /// No description provided for @updateBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get updateBadgeLabel;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Get the latest improvements and fixes. You can continue learning while the update downloads.'**
  String get updateAvailableBody;

  /// No description provided for @updateNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get updateNotNow;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading the update… You can continue learning.'**
  String get updateDownloading;

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'Update ready. Restart Czechify to finish installing it.'**
  String get updateReady;

  /// No description provided for @updateRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart now'**
  String get updateRestart;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Czechify is up to date.'**
  String get updateUpToDate;

  /// No description provided for @updateCancelled.
  ///
  /// In en, this message translates to:
  /// **'The update was cancelled.'**
  String get updateCancelled;

  /// No description provided for @updateStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Google Play couldn\'t install the update. Try again later.'**
  String get updateStartFailed;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Google Play couldn\'t check for updates. Try again later.'**
  String get updateCheckFailed;

  /// No description provided for @updateUnsupported.
  ///
  /// In en, this message translates to:
  /// **'In-app updates are available for Czechify installations from Google Play on Android.'**
  String get updateUnsupported;

  /// No description provided for @updateCheckAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'An update check is already running.'**
  String get updateCheckAlreadyRunning;

  /// No description provided for @updatePlayStoreOnlyBody.
  ///
  /// In en, this message translates to:
  /// **'The update is available, but Google Play can\'t install it inside Czechify right now. Open Google Play to update.'**
  String get updatePlayStoreOnlyBody;

  /// No description provided for @updateOpenPlayStore.
  ///
  /// In en, this message translates to:
  /// **'Open Google Play'**
  String get updateOpenPlayStore;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @privacyVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String privacyVersion(String version);

  /// No description provided for @privacyViewOnline.
  ///
  /// In en, this message translates to:
  /// **'View privacy policy on the Czechify website'**
  String get privacyViewOnline;

  /// No description provided for @homeYourProgress.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get homeYourProgress;

  /// No description provided for @homeBrowseCurriculum.
  ///
  /// In en, this message translates to:
  /// **'Browse curriculum'**
  String get homeBrowseCurriculum;

  /// No description provided for @homeGrammarReference.
  ///
  /// In en, this message translates to:
  /// **'Grammar reference'**
  String get homeGrammarReference;

  /// No description provided for @homeMockExam.
  ///
  /// In en, this message translates to:
  /// **'Mock exam'**
  String get homeMockExam;

  /// No description provided for @homeAiChat.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get homeAiChat;

  /// No description provided for @homeSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get homeSpeak;

  /// No description provided for @homeStartFirstLesson.
  ///
  /// In en, this message translates to:
  /// **'Start your first lesson'**
  String get homeStartFirstLesson;

  /// No description provided for @homeAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get homeAllCaughtUp;

  /// No description provided for @homeRetryLessonA11y.
  ///
  /// In en, this message translates to:
  /// **'Lesson {lesson} · try it again'**
  String homeRetryLessonA11y(int lesson);

  /// No description provided for @homeDayStreak.
  ///
  /// In en, this message translates to:
  /// **'{count,plural,=1{{count} day streak}other{{count} day streak}}'**
  String homeDayStreak(int count);

  /// No description provided for @homeHeartsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count,plural,=1{{count} heart remaining}other{{count} hearts remaining}}'**
  String homeHeartsRemaining(int count);

  /// No description provided for @reviewShowAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show Answer'**
  String get reviewShowAnswer;

  /// No description provided for @reviewTapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal'**
  String get reviewTapToReveal;

  /// No description provided for @reviewTypeAnswerFirst.
  ///
  /// In en, this message translates to:
  /// **'Type your answer first'**
  String get reviewTypeAnswerFirst;

  /// No description provided for @reviewRatingAgain.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get reviewRatingAgain;

  /// No description provided for @reviewRatingHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get reviewRatingHard;

  /// No description provided for @reviewRatingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get reviewRatingGood;

  /// No description provided for @reviewRatingEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get reviewRatingEasy;

  /// No description provided for @reviewEndTitle.
  ///
  /// In en, this message translates to:
  /// **'End review?'**
  String get reviewEndTitle;

  /// No description provided for @reviewEndBody.
  ///
  /// In en, this message translates to:
  /// **'Your progress will be saved. You can continue later.'**
  String get reviewEndBody;

  /// No description provided for @reviewStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get reviewStay;

  /// No description provided for @reviewEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get reviewEnd;

  /// No description provided for @reviewNoCardsDue.
  ///
  /// In en, this message translates to:
  /// **'No cards due for review right now.'**
  String get reviewNoCardsDue;

  /// No description provided for @reviewCardOf.
  ///
  /// In en, this message translates to:
  /// **'Card {current} of {total}'**
  String reviewCardOf(int current, int total);

  /// No description provided for @lessonLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave lesson?'**
  String get lessonLeaveTitle;

  /// No description provided for @lessonLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll go back to the curriculum. The answers you\'ve already given are saved.'**
  String get lessonLeaveBody;

  /// No description provided for @lessonLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get lessonLeave;

  /// No description provided for @lessonQuestionOf.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String lessonQuestionOf(int current, int total);

  /// No description provided for @errorFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load this content.'**
  String get errorFailedToLoad;

  /// No description provided for @errorCheckConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get errorCheckConnection;

  /// No description provided for @a11yBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get a11yBack;

  /// No description provided for @a11yClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get a11yClose;

  /// No description provided for @a11yPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get a11yPlayAudio;

  /// No description provided for @a11ySettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get a11ySettings;

  /// No description provided for @a11yHearts.
  ///
  /// In en, this message translates to:
  /// **'{count,plural,=1{{count} heart left}other{{count} hearts left}}'**
  String a11yHearts(int count);

  /// No description provided for @a11yStreak.
  ///
  /// In en, this message translates to:
  /// **'{count,plural,=1{{count} day streak}other{{count} day streak}}'**
  String a11yStreak(int count);

  /// No description provided for @a11yRateCard.
  ///
  /// In en, this message translates to:
  /// **'Rate this card: {rating}'**
  String a11yRateCard(String rating);

  /// No description provided for @a11yLessonProgress.
  ///
  /// In en, this message translates to:
  /// **'Lesson progress: question {current} of {total}'**
  String a11yLessonProgress(int current, int total);

  /// No description provided for @writingKeyPhrasesFound.
  ///
  /// In en, this message translates to:
  /// **'Key phrases found'**
  String get writingKeyPhrasesFound;

  /// No description provided for @writingKeyPhrasesMissing.
  ///
  /// In en, this message translates to:
  /// **'Key phrases not found'**
  String get writingKeyPhrasesMissing;

  /// No description provided for @writingKeywordCheckNote.
  ///
  /// In en, this message translates to:
  /// **'Automatic keyword check only — it compares your words against the expected phrases and does not judge grammar, spelling, or style.'**
  String get writingKeywordCheckNote;

  /// No description provided for @audioHearIt.
  ///
  /// In en, this message translates to:
  /// **'Hear it'**
  String get audioHearIt;

  /// No description provided for @audioSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get audioSlow;

  /// No description provided for @audioSlower.
  ///
  /// In en, this message translates to:
  /// **'Slower'**
  String get audioSlower;

  /// No description provided for @audioStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get audioStop;

  /// No description provided for @audioPlayAgain.
  ///
  /// In en, this message translates to:
  /// **'Play it again'**
  String get audioPlayAgain;

  /// No description provided for @audioPlayIt.
  ///
  /// In en, this message translates to:
  /// **'Play it'**
  String get audioPlayIt;

  /// No description provided for @audioHearTheWord.
  ///
  /// In en, this message translates to:
  /// **'Hear the word'**
  String get audioHearTheWord;

  /// No description provided for @czechLetters.
  ///
  /// In en, this message translates to:
  /// **'Czech letters'**
  String get czechLetters;

  /// No description provided for @feedbackCorrect.
  ///
  /// In en, this message translates to:
  /// **'Správně!'**
  String get feedbackCorrect;

  /// No description provided for @feedbackNotQuite.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get feedbackNotQuite;

  /// No description provided for @feedbackAnswerShown.
  ///
  /// In en, this message translates to:
  /// **'Answer shown'**
  String get feedbackAnswerShown;

  /// No description provided for @feedbackSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped — no score or heart change'**
  String get feedbackSkipped;

  /// No description provided for @feedbackViewGrammarRule.
  ///
  /// In en, this message translates to:
  /// **'View grammar rule'**
  String get feedbackViewGrammarRule;

  /// No description provided for @answerCorrectLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get answerCorrectLabel;

  /// No description provided for @lessonIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get lessonIntroduction;

  /// No description provided for @lessonGoal.
  ///
  /// In en, this message translates to:
  /// **'Lesson goal'**
  String get lessonGoal;

  /// No description provided for @lessonGoalByEnd.
  ///
  /// In en, this message translates to:
  /// **'By the end, you’ll be able to {goal}'**
  String lessonGoalByEnd(String goal);

  /// No description provided for @lessonMissedQuestions.
  ///
  /// In en, this message translates to:
  /// **'Missed questions'**
  String get lessonMissedQuestions;

  /// No description provided for @lessonInARow.
  ///
  /// In en, this message translates to:
  /// **'{count} in a row'**
  String lessonInARow(int count);

  /// No description provided for @lessonXpTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} XP'**
  String lessonXpTotal(int count);

  /// No description provided for @lessonXpAward.
  ///
  /// In en, this message translates to:
  /// **'+{count} XP'**
  String lessonXpAward(int count);

  /// No description provided for @lessonNewWords.
  ///
  /// In en, this message translates to:
  /// **'New words'**
  String get lessonNewWords;

  /// No description provided for @lessonStartPractice.
  ///
  /// In en, this message translates to:
  /// **'Start practice'**
  String get lessonStartPractice;

  /// No description provided for @lessonNowICan.
  ///
  /// In en, this message translates to:
  /// **'Now I can'**
  String get lessonNowICan;

  /// No description provided for @lessonKeepPractising.
  ///
  /// In en, this message translates to:
  /// **'Keep practising'**
  String get lessonKeepPractising;

  /// No description provided for @lessonGotItStartPractising.
  ///
  /// In en, this message translates to:
  /// **'Got it — start practising'**
  String get lessonGotItStartPractising;

  /// No description provided for @lessonSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get lessonSaving;

  /// No description provided for @lessonNextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get lessonNextQuestion;

  /// No description provided for @lessonReviewMistakes.
  ///
  /// In en, this message translates to:
  /// **'Review mistakes'**
  String get lessonReviewMistakes;

  /// No description provided for @lessonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish lesson'**
  String get lessonFinish;

  /// No description provided for @lessonFinishUnit.
  ///
  /// In en, this message translates to:
  /// **'Finish unit {number}'**
  String lessonFinishUnit(int number);

  /// No description provided for @lessonContinueLearning.
  ///
  /// In en, this message translates to:
  /// **'Continue learning'**
  String get lessonContinueLearning;

  /// No description provided for @lessonPracticeAgain.
  ///
  /// In en, this message translates to:
  /// **'Practice again'**
  String get lessonPracticeAgain;

  /// No description provided for @lessonLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not open yet'**
  String get lessonLockedTitle;

  /// No description provided for @lessonLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Finish the lessons before this one and it unlocks.'**
  String get lessonLockedBody;

  /// No description provided for @lessonBackToCurriculum.
  ///
  /// In en, this message translates to:
  /// **'Back to curriculum'**
  String get lessonBackToCurriculum;

  /// No description provided for @lessonNoExercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises found for this lesson.'**
  String get lessonNoExercises;

  /// No description provided for @lessonOutOfHeartsTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of hearts'**
  String get lessonOutOfHeartsTitle;

  /// No description provided for @lessonOutOfHeartsBody.
  ///
  /// In en, this message translates to:
  /// **'Hearts refill on their own — one every 30 minutes. A review session of five or more cards earns one back now.'**
  String get lessonOutOfHeartsBody;

  /// No description provided for @lessonReviewToEarnHeart.
  ///
  /// In en, this message translates to:
  /// **'Review to earn a heart'**
  String get lessonReviewToEarnHeart;

  /// No description provided for @lessonBadgeExam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get lessonBadgeExam;

  /// No description provided for @statAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get statAccuracy;

  /// No description provided for @statXpEarned.
  ///
  /// In en, this message translates to:
  /// **'XP earned'**
  String get statXpEarned;

  /// No description provided for @statCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get statCorrect;

  /// No description provided for @statMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statMissed;

  /// No description provided for @statCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get statCards;

  /// No description provided for @statRecalled.
  ///
  /// In en, this message translates to:
  /// **'Recalled'**
  String get statRecalled;

  /// No description provided for @captionAccuracy.
  ///
  /// In en, this message translates to:
  /// **'accuracy'**
  String get captionAccuracy;

  /// No description provided for @captionRecall.
  ///
  /// In en, this message translates to:
  /// **'recall'**
  String get captionRecall;

  /// No description provided for @captionMatch.
  ///
  /// In en, this message translates to:
  /// **'match'**
  String get captionMatch;

  /// No description provided for @exerciseCheckAnswers.
  ///
  /// In en, this message translates to:
  /// **'Check answers'**
  String get exerciseCheckAnswers;

  /// No description provided for @exerciseCheckAll.
  ///
  /// In en, this message translates to:
  /// **'Check all'**
  String get exerciseCheckAll;

  /// No description provided for @exerciseQuestionNumber.
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String exerciseQuestionNumber(int number);

  /// No description provided for @exerciseAllCorrect.
  ///
  /// In en, this message translates to:
  /// **'All correct'**
  String get exerciseAllCorrect;

  /// No description provided for @exerciseSomeAnswersWrong.
  ///
  /// In en, this message translates to:
  /// **'Some answers are wrong — review them below.'**
  String get exerciseSomeAnswersWrong;

  /// No description provided for @exerciseSomePairsWrong.
  ///
  /// In en, this message translates to:
  /// **'Some pairs are wrong'**
  String get exerciseSomePairsWrong;

  /// No description provided for @exerciseCorrectOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{correct}/{total} correct'**
  String exerciseCorrectOfTotal(int correct, int total);

  /// No description provided for @exerciseMatchedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{matched}/{total} matched'**
  String exerciseMatchedOfTotal(int matched, int total);

  /// No description provided for @exerciseTapCzechThenEnglish.
  ///
  /// In en, this message translates to:
  /// **'Tap a Czech word, then tap its English match.'**
  String get exerciseTapCzechThenEnglish;

  /// No description provided for @exerciseTapWordsInOrder.
  ///
  /// In en, this message translates to:
  /// **'Tap the words below in order'**
  String get exerciseTapWordsInOrder;

  /// No description provided for @exerciseTypeWhatYouHeard.
  ///
  /// In en, this message translates to:
  /// **'Type what you heard'**
  String get exerciseTypeWhatYouHeard;

  /// No description provided for @exerciseRevealTranscript.
  ///
  /// In en, this message translates to:
  /// **'Reveal transcript'**
  String get exerciseRevealTranscript;

  /// No description provided for @exerciseGistFirstNote.
  ///
  /// In en, this message translates to:
  /// **'Listen for the gist first. Replay or reveal the transcript only when you need support.'**
  String get exerciseGistFirstNote;

  /// No description provided for @exerciseNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'This exercise has no questions configured.'**
  String get exerciseNoQuestions;

  /// No description provided for @exerciseSayInCzech.
  ///
  /// In en, this message translates to:
  /// **'Say this in Czech'**
  String get exerciseSayInCzech;

  /// No description provided for @exerciseSayInEnglish.
  ///
  /// In en, this message translates to:
  /// **'Say this in English'**
  String get exerciseSayInEnglish;

  /// No description provided for @exerciseTypeInCzech.
  ///
  /// In en, this message translates to:
  /// **'Type in Czech'**
  String get exerciseTypeInCzech;

  /// No description provided for @exerciseTypeInEnglish.
  ///
  /// In en, this message translates to:
  /// **'Type in English'**
  String get exerciseTypeInEnglish;

  /// No description provided for @labelEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get labelEnglish;

  /// No description provided for @labelCzech.
  ///
  /// In en, this message translates to:
  /// **'Czech'**
  String get labelCzech;

  /// No description provided for @exerciseChooseCorrectForm.
  ///
  /// In en, this message translates to:
  /// **'Choose the correct form'**
  String get exerciseChooseCorrectForm;

  /// No description provided for @exerciseTypeCorrectSentence.
  ///
  /// In en, this message translates to:
  /// **'Type the correct sentence'**
  String get exerciseTypeCorrectSentence;

  /// No description provided for @exerciseCorrectedSentence.
  ///
  /// In en, this message translates to:
  /// **'Corrected sentence'**
  String get exerciseCorrectedSentence;

  /// No description provided for @exerciseShowHint.
  ///
  /// In en, this message translates to:
  /// **'Show hint'**
  String get exerciseShowHint;

  /// No description provided for @exerciseErrorInHighlighted.
  ///
  /// In en, this message translates to:
  /// **'The error is in one of the highlighted words above.'**
  String get exerciseErrorInHighlighted;

  /// No description provided for @exerciseDeclineWord.
  ///
  /// In en, this message translates to:
  /// **'Decline {word}'**
  String exerciseDeclineWord(String word);

  /// No description provided for @exerciseYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get exerciseYourAnswer;

  /// No description provided for @teachingKicker.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get teachingKicker;

  /// No description provided for @teachingIntro.
  ///
  /// In en, this message translates to:
  /// **'Intro'**
  String get teachingIntro;

  /// No description provided for @teachingLetterByLetter.
  ///
  /// In en, this message translates to:
  /// **'Letter by letter'**
  String get teachingLetterByLetter;

  /// No description provided for @teachingTapAnyLetter.
  ///
  /// In en, this message translates to:
  /// **'Tap any letter to hear it'**
  String get teachingTapAnyLetter;

  /// No description provided for @teachingTapLineToHear.
  ///
  /// In en, this message translates to:
  /// **'Tap a line to hear it'**
  String get teachingTapLineToHear;

  /// No description provided for @teachingPlayWholeSet.
  ///
  /// In en, this message translates to:
  /// **'Play the whole set'**
  String get teachingPlayWholeSet;

  /// No description provided for @writingWriteAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Write at least {count} words.'**
  String writingWriteAtLeast(int count);

  /// No description provided for @writingHint.
  ///
  /// In en, this message translates to:
  /// **'Write your answer in Czech…'**
  String get writingHint;

  /// No description provided for @writingShowVocabSupport.
  ///
  /// In en, this message translates to:
  /// **'Show vocabulary support'**
  String get writingShowVocabSupport;

  /// No description provided for @writingTryUsing.
  ///
  /// In en, this message translates to:
  /// **'Try using'**
  String get writingTryUsing;

  /// No description provided for @writingReviseNote.
  ///
  /// In en, this message translates to:
  /// **'Revise: check the communicative goal, verb forms, case endings, word order, and register. Improve the message, not only its length.'**
  String get writingReviseNote;

  /// No description provided for @writingReviewDraft.
  ///
  /// In en, this message translates to:
  /// **'Review draft'**
  String get writingReviewDraft;

  /// No description provided for @writingSubmitRevision.
  ///
  /// In en, this message translates to:
  /// **'Submit revision'**
  String get writingSubmitRevision;

  /// No description provided for @writingCycleComplete.
  ///
  /// In en, this message translates to:
  /// **'Writing cycle complete'**
  String get writingCycleComplete;

  /// No description provided for @writingReferenceAnswer.
  ///
  /// In en, this message translates to:
  /// **'Reference answer'**
  String get writingReferenceAnswer;

  /// No description provided for @writingWordCountMin.
  ///
  /// In en, this message translates to:
  /// **'{count} words · minimum {min}'**
  String writingWordCountMin(int count, int min);

  /// No description provided for @writingWordCount.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String writingWordCount(int count);

  /// No description provided for @speakingTryToSay.
  ///
  /// In en, this message translates to:
  /// **'Try to say'**
  String get speakingTryToSay;

  /// No description provided for @speakingYouSaid.
  ///
  /// In en, this message translates to:
  /// **'You said'**
  String get speakingYouSaid;

  /// No description provided for @speakingTapToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap to speak'**
  String get speakingTapToSpeak;

  /// No description provided for @speakingTapToRerecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to re-record'**
  String get speakingTapToRerecord;

  /// No description provided for @speakingRecordingTapToStop.
  ///
  /// In en, this message translates to:
  /// **'Recording — tap to stop'**
  String get speakingRecordingTapToStop;

  /// No description provided for @pronTapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get pronTapToRecord;

  /// No description provided for @pronRecordedTapAgain.
  ///
  /// In en, this message translates to:
  /// **'Recorded — tap to try again'**
  String get pronRecordedTapAgain;

  /// No description provided for @pronListeningTapToStop.
  ///
  /// In en, this message translates to:
  /// **'Listening — tap to stop'**
  String get pronListeningTapToStop;

  /// No description provided for @pronAnalysing.
  ///
  /// In en, this message translates to:
  /// **'Analysing…'**
  String get pronAnalysing;

  /// No description provided for @pronMicNotWorkingSkip.
  ///
  /// In en, this message translates to:
  /// **'Mic not working? Skip'**
  String get pronMicNotWorkingSkip;

  /// No description provided for @pronCantRecordSkip.
  ///
  /// In en, this message translates to:
  /// **'Can\'t record right now? Skip'**
  String get pronCantRecordSkip;

  /// No description provided for @pronSkippedNote.
  ///
  /// In en, this message translates to:
  /// **'Skipped — keep practising this one aloud with the listen button.'**
  String get pronSkippedNote;

  /// No description provided for @reviewSpacedRepetition.
  ///
  /// In en, this message translates to:
  /// **'Spaced repetition'**
  String get reviewSpacedRepetition;

  /// No description provided for @reviewCardsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String reviewCardsLeft(int count);

  /// No description provided for @reviewRetrieveTheCzech.
  ///
  /// In en, this message translates to:
  /// **'Retrieve the Czech'**
  String get reviewRetrieveTheCzech;

  /// No description provided for @reviewSayItThenTypeIt.
  ///
  /// In en, this message translates to:
  /// **'Say it, then type it'**
  String get reviewSayItThenTypeIt;

  /// No description provided for @reviewOvertAttemptNote.
  ///
  /// In en, this message translates to:
  /// **'Make an overt attempt before revealing.'**
  String get reviewOvertAttemptNote;

  /// No description provided for @reviewWhatDoesItMean.
  ///
  /// In en, this message translates to:
  /// **'What does it mean?'**
  String get reviewWhatDoesItMean;

  /// No description provided for @reviewInASentence.
  ///
  /// In en, this message translates to:
  /// **'In a sentence'**
  String get reviewInASentence;

  /// No description provided for @reviewNeedAHint.
  ///
  /// In en, this message translates to:
  /// **'Say it out loud · need a hint?'**
  String get reviewNeedAHint;

  /// No description provided for @reviewHintStartsWith.
  ///
  /// In en, this message translates to:
  /// **'Starts with “{start}”'**
  String reviewHintStartsWith(String start);

  /// No description provided for @reviewMeans.
  ///
  /// In en, this message translates to:
  /// **'Means'**
  String get reviewMeans;

  /// No description provided for @reviewHowDoYouSayIt.
  ///
  /// In en, this message translates to:
  /// **'How do you say it in Czech?'**
  String get reviewHowDoYouSayIt;

  /// No description provided for @reviewCompleteCzechSentence.
  ///
  /// In en, this message translates to:
  /// **'Complete the Czech sentence.'**
  String get reviewCompleteCzechSentence;

  /// No description provided for @reviewDirectionEnToCz.
  ///
  /// In en, this message translates to:
  /// **'EN → CZ'**
  String get reviewDirectionEnToCz;

  /// No description provided for @reviewDirectionListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get reviewDirectionListening;

  /// No description provided for @reviewHowWellRecalled.
  ///
  /// In en, this message translates to:
  /// **'How well did you remember it?'**
  String get reviewHowWellRecalled;

  /// No description provided for @reviewChooseRatingToContinue.
  ///
  /// In en, this message translates to:
  /// **'Choose one to schedule this card and continue to the next.'**
  String get reviewChooseRatingToContinue;

  /// No description provided for @reviewAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get reviewAllCaughtUp;

  /// No description provided for @reviewCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get reviewCheckAgain;

  /// No description provided for @reviewNoCardsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No cards available.'**
  String get reviewNoCardsAvailable;

  /// No description provided for @reviewDeckCleared.
  ///
  /// In en, this message translates to:
  /// **'Deck cleared'**
  String get reviewDeckCleared;

  /// No description provided for @reviewCardsReviewed.
  ///
  /// In en, this message translates to:
  /// **'{count,plural,=1{Nice work — {count} card reviewed}other{Nice work — {count} cards reviewed}}'**
  String reviewCardsReviewed(int count);

  /// No description provided for @reviewHeartEarned.
  ///
  /// In en, this message translates to:
  /// **'+1 heart earned'**
  String get reviewHeartEarned;

  /// No description provided for @reviewHowItWent.
  ///
  /// In en, this message translates to:
  /// **'How it went'**
  String get reviewHowItWent;

  /// No description provided for @reviewReschedulingNote.
  ///
  /// In en, this message translates to:
  /// **'These cards are rescheduled with spaced repetition — each one comes back right when it is about to slip.'**
  String get reviewReschedulingNote;

  /// No description provided for @reviewGoAgain.
  ///
  /// In en, this message translates to:
  /// **'Go again'**
  String get reviewGoAgain;

  /// No description provided for @reviewDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reviewDone;

  /// No description provided for @reviewIntervalSoon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get reviewIntervalSoon;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Tutor'**
  String get chatTitle;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Real situations you will hit this week in Czechia. The tutor adapts to your level.'**
  String get chatSubtitle;

  /// No description provided for @chatUnfinished.
  ///
  /// In en, this message translates to:
  /// **'Unfinished'**
  String get chatUnfinished;

  /// No description provided for @chatPickASituation.
  ///
  /// In en, this message translates to:
  /// **'Pick a situation'**
  String get chatPickASituation;

  /// No description provided for @chatRoomCount.
  ///
  /// In en, this message translates to:
  /// **'{count} rooms'**
  String chatRoomCount(int count);

  /// No description provided for @chatTurnsIn.
  ///
  /// In en, this message translates to:
  /// **'{count,plural,=1{{count} turn in}other{{count} turns in}}'**
  String chatTurnsIn(int count);

  /// No description provided for @chatBackToScenarios.
  ///
  /// In en, this message translates to:
  /// **'Back to scenarios'**
  String get chatBackToScenarios;

  /// No description provided for @chatTutorIsTyping.
  ///
  /// In en, this message translates to:
  /// **'The tutor is typing'**
  String get chatTutorIsTyping;

  /// No description provided for @chatSpeakYourReply.
  ///
  /// In en, this message translates to:
  /// **'Speak your reply'**
  String get chatSpeakYourReply;

  /// No description provided for @chatComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Napiš česky…'**
  String get chatComposerHint;

  /// No description provided for @chatListeningHint.
  ///
  /// In en, this message translates to:
  /// **'Listening… speak Czech'**
  String get chatListeningHint;

  /// No description provided for @chatDeleteConversation.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation'**
  String get chatDeleteConversation;

  /// No description provided for @chatDeleteConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get chatDeleteConversationTitle;

  /// No description provided for @chatDeleteConversationBody.
  ///
  /// In en, this message translates to:
  /// **'Your chat about “{scenario}” will be permanently removed. This cannot be undone.'**
  String chatDeleteConversationBody(String scenario);

  /// No description provided for @chatDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDelete;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get chatYesterday;

  /// No description provided for @chatDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String chatDaysAgo(int count);

  /// No description provided for @chatReportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks — your report is on its way.'**
  String get chatReportSent;

  /// No description provided for @chatReportReply.
  ///
  /// In en, this message translates to:
  /// **'Report this reply'**
  String get chatReportReply;

  /// No description provided for @chatNoRepliesLeft.
  ///
  /// In en, this message translates to:
  /// **'No tutor replies left today.'**
  String get chatNoRepliesLeft;

  /// No description provided for @chatRepliesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count,plural,=1{{count} tutor reply left today.}other{{count} tutor replies left today.}}'**
  String chatRepliesLeft(int count);

  /// No description provided for @chatAddedToReview.
  ///
  /// In en, this message translates to:
  /// **'Added “{word}” to your review deck'**
  String chatAddedToReview(String word);

  /// No description provided for @chatAlreadyInReview.
  ///
  /// In en, this message translates to:
  /// **'“{word}” is already in your deck'**
  String chatAlreadyInReview(String word);

  /// No description provided for @exerciseAllAnsweredCorrectly.
  ///
  /// In en, this message translates to:
  /// **'All questions answered correctly.'**
  String get exerciseAllAnsweredCorrectly;

  /// No description provided for @exerciseNoQuestionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No questions available for this exercise.'**
  String get exerciseNoQuestionsAvailable;

  /// No description provided for @exerciseYouGotCorrect.
  ///
  /// In en, this message translates to:
  /// **'You got {correct}/{total} correct.'**
  String exerciseYouGotCorrect(int correct, int total);

  /// No description provided for @pronFeedbackGood.
  ///
  /// In en, this message translates to:
  /// **'Good pronunciation.'**
  String get pronFeedbackGood;

  /// No description provided for @pronFeedbackRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again — focus on the highlighted sounds.'**
  String get pronFeedbackRetry;

  /// No description provided for @speakingFeedbackGood.
  ///
  /// In en, this message translates to:
  /// **'Good — you said the right things.'**
  String get speakingFeedbackGood;

  /// No description provided for @speakingFeedbackRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again. Expected phrases include: {phrases}'**
  String speakingFeedbackRetry(String phrases);

  /// No description provided for @recordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed. Please try again.'**
  String get recordingFailed;

  /// No description provided for @writingWroteWords.
  ///
  /// In en, this message translates to:
  /// **'You wrote {count} words.'**
  String writingWroteWords(int count);

  /// No description provided for @writingMeetsMinimum.
  ///
  /// In en, this message translates to:
  /// **'Meets the {min}-word minimum.'**
  String writingMeetsMinimum(int min);

  /// No description provided for @writingNeedsMinimum.
  ///
  /// In en, this message translates to:
  /// **'Needs at least {min} words.'**
  String writingNeedsMinimum(int min);

  /// No description provided for @writingGoodKeywordCoverage.
  ///
  /// In en, this message translates to:
  /// **'Good keyword coverage.'**
  String get writingGoodKeywordCoverage;

  /// No description provided for @writingKeyPhrasesNotDetected.
  ///
  /// In en, this message translates to:
  /// **'Key phrases not detected.'**
  String get writingKeyPhrasesNotDetected;

  /// No description provided for @writingUnscoredNote.
  ///
  /// In en, this message translates to:
  /// **'Completed as unscored writing practice; no automatic proficiency claim is made.'**
  String get writingUnscoredNote;

  /// No description provided for @writingRevisedDraft.
  ///
  /// In en, this message translates to:
  /// **'You revised the first draft.'**
  String get writingRevisedDraft;

  /// No description provided for @translationAccentHint.
  ///
  /// In en, this message translates to:
  /// **'Almost — watch your accent marks. The correct spelling is \"{answer}\".'**
  String translationAccentHint(String answer);

  /// No description provided for @dictationAccentHint.
  ///
  /// In en, this message translates to:
  /// **'Almost — watch your accent marks. You had it right apart from the diacritics.'**
  String get dictationAccentHint;

  /// No description provided for @examResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Exam results'**
  String get examResultsTitle;

  /// No description provided for @examPracticeComplete.
  ///
  /// In en, this message translates to:
  /// **'Practice complete'**
  String get examPracticeComplete;

  /// No description provided for @examPracticeTargetMet.
  ///
  /// In en, this message translates to:
  /// **'Practice target met'**
  String get examPracticeTargetMet;

  /// No description provided for @examThresholdMet.
  ///
  /// In en, this message translates to:
  /// **'Practice threshold met'**
  String get examThresholdMet;

  /// No description provided for @examThresholdNotMet.
  ///
  /// In en, this message translates to:
  /// **'Practice threshold not met'**
  String get examThresholdNotMet;

  /// No description provided for @examPartlyUnscored.
  ///
  /// In en, this message translates to:
  /// **'Practice completed — some tasks unscored'**
  String get examPartlyUnscored;

  /// No description provided for @examCourseTrack.
  ///
  /// In en, this message translates to:
  /// **'Course track {level}'**
  String examCourseTrack(String level);

  /// No description provided for @examAccuracyCaveat.
  ///
  /// In en, this message translates to:
  /// **'Lesson exercise accuracy only. This is not an official exam result or CEFR certification.'**
  String get examAccuracyCaveat;

  /// No description provided for @examMockTitle.
  ///
  /// In en, this message translates to:
  /// **'Mock exam — {level}'**
  String examMockTitle(String level);

  /// No description provided for @examPracticeExamTitle.
  ///
  /// In en, this message translates to:
  /// **'{product} {level} practice exam'**
  String examPracticeExamTitle(String product, String level);

  /// No description provided for @examFourSections.
  ///
  /// In en, this message translates to:
  /// **'Four timed sections. The timer runs per section, and you can answer in order.'**
  String get examFourSections;

  /// No description provided for @examInformalNote.
  ///
  /// In en, this message translates to:
  /// **'This is informal practice, not an official exam result.'**
  String get examInformalNote;

  /// No description provided for @examSectionReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get examSectionReading;

  /// No description provided for @examSectionReadingSub.
  ///
  /// In en, this message translates to:
  /// **'Comprehension questions'**
  String get examSectionReadingSub;

  /// No description provided for @examSectionListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get examSectionListening;

  /// No description provided for @examSectionListeningSub.
  ///
  /// In en, this message translates to:
  /// **'Audio, then questions'**
  String get examSectionListeningSub;

  /// No description provided for @examSectionWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get examSectionWriting;

  /// No description provided for @examSectionWritingSub.
  ///
  /// In en, this message translates to:
  /// **'Practice feedback when available'**
  String get examSectionWritingSub;

  /// No description provided for @examSectionSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get examSectionSpeaking;

  /// No description provided for @examSectionSpeakingSub.
  ///
  /// In en, this message translates to:
  /// **'Transcript-based practice evidence'**
  String get examSectionSpeakingSub;

  /// No description provided for @examTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total time: {minutes} minutes'**
  String examTotalTime(int minutes);

  /// No description provided for @examDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get examDone;

  /// No description provided for @examPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Play the audio'**
  String get examPlayAudio;

  /// No description provided for @feedbackStepSignal.
  ///
  /// In en, this message translates to:
  /// **'Something needs attention. Try to notice what.'**
  String get feedbackStepSignal;

  /// No description provided for @feedbackStepSelfRepair.
  ///
  /// In en, this message translates to:
  /// **'Try again before asking for more help.'**
  String get feedbackStepSelfRepair;

  /// No description provided for @feedbackStepCue.
  ///
  /// In en, this message translates to:
  /// **'Use the explanation as a cue, then repair your answer.'**
  String get feedbackStepCue;

  /// No description provided for @feedbackStepExplanation.
  ///
  /// In en, this message translates to:
  /// **'Study the answer, then retrieve it once more.'**
  String get feedbackStepExplanation;

  /// No description provided for @feedbackStepImmediateVariant.
  ///
  /// In en, this message translates to:
  /// **'Now apply the same idea to a variation.'**
  String get feedbackStepImmediateVariant;

  /// No description provided for @feedbackStepSpacedAnalogue.
  ///
  /// In en, this message translates to:
  /// **'A related task will return later.'**
  String get feedbackStepSpacedAnalogue;

  /// No description provided for @feedbackStepNovelTask.
  ///
  /// In en, this message translates to:
  /// **'Use what you remember in this new situation.'**
  String get feedbackStepNovelTask;

  /// No description provided for @examPaceTarget.
  ///
  /// In en, this message translates to:
  /// **'Pace target {time}'**
  String examPaceTarget(String time);

  /// No description provided for @examOverPaceTarget.
  ///
  /// In en, this message translates to:
  /// **'Over pace target'**
  String get examOverPaceTarget;

  /// No description provided for @examPaceHint.
  ///
  /// In en, this message translates to:
  /// **'Suggested pace only — practice continues when time runs out'**
  String get examPaceHint;

  /// No description provided for @examPaceSemantics.
  ///
  /// In en, this message translates to:
  /// **'{status}. Practice continues after the target time.'**
  String examPaceSemantics(String status);

  /// No description provided for @examUnfinishedAttempt.
  ///
  /// In en, this message translates to:
  /// **'You have an unfinished attempt from {age}.'**
  String examUnfinishedAttempt(String age);

  /// No description provided for @ageAMomentAgo.
  ///
  /// In en, this message translates to:
  /// **'a moment ago'**
  String get ageAMomentAgo;

  /// No description provided for @ageMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String ageMinutesAgo(int count);

  /// No description provided for @ageHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String ageHoursAgo(int count);

  /// No description provided for @copybookTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily copybook'**
  String get copybookTitle;

  /// No description provided for @copybookHeading.
  ///
  /// In en, this message translates to:
  /// **'Write Czech by hand'**
  String get copybookHeading;

  /// No description provided for @copybookBody.
  ///
  /// In en, this message translates to:
  /// **'Copy each useful word and its sentence on paper. Mark it when you can form every diacritic clearly.'**
  String get copybookBody;

  /// No description provided for @copybookImageLabel.
  ///
  /// In en, this message translates to:
  /// **'An open handwriting notebook overlooking Prague'**
  String get copybookImageLabel;

  /// No description provided for @copybookLoadError.
  ///
  /// In en, this message translates to:
  /// **'Today’s words could not be loaded.'**
  String get copybookLoadError;

  /// No description provided for @copybookTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get copybookTryAgain;

  /// No description provided for @copybookOfflineEmpty.
  ///
  /// In en, this message translates to:
  /// **'Complete offline setup to make curriculum words available.'**
  String get copybookOfflineEmpty;

  /// No description provided for @copybookComplete.
  ///
  /// In en, this message translates to:
  /// **'Today’s page is complete. A new curriculum-based selection arrives tomorrow.'**
  String get copybookComplete;

  /// No description provided for @streakProtected.
  ///
  /// In en, this message translates to:
  /// **'Streak protected'**
  String get streakProtected;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'{count}-day streak'**
  String streakDays(int count);

  /// No description provided for @streakStartNew.
  ///
  /// In en, this message translates to:
  /// **'Start a new streak'**
  String get streakStartNew;

  /// No description provided for @streakProtectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your freeze covered one missed day and kept your {count}-day streak intact. Complete practice today to earn the next freeze.'**
  String streakProtectedBody(int count);

  /// No description provided for @streakActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Your streak is active today. Complete meaningful practice each day to keep it going.'**
  String get streakActiveBody;

  /// No description provided for @streakEndedBody.
  ///
  /// In en, this message translates to:
  /// **'Your previous streak has ended. One completed learning activity starts a fresh one—no penalty, just a new day.'**
  String get streakEndedBody;

  /// No description provided for @streakKeepLearning.
  ///
  /// In en, this message translates to:
  /// **'Keep learning'**
  String get streakKeepLearning;

  /// No description provided for @streakBeginAgain.
  ///
  /// In en, this message translates to:
  /// **'Begin again'**
  String get streakBeginAgain;

  /// No description provided for @pathA1Foundations.
  ///
  /// In en, this message translates to:
  /// **'A1 Foundations'**
  String get pathA1Foundations;

  /// No description provided for @pathA1Everyday.
  ///
  /// In en, this message translates to:
  /// **'A1 Everyday Czech'**
  String get pathA1Everyday;

  /// No description provided for @pathA2Grammar.
  ///
  /// In en, this message translates to:
  /// **'A2 Grammar expansion'**
  String get pathA2Grammar;

  /// No description provided for @pathA2RealLife.
  ///
  /// In en, this message translates to:
  /// **'A2 Real-life Czech'**
  String get pathA2RealLife;

  /// No description provided for @pathExamConsolidation.
  ///
  /// In en, this message translates to:
  /// **'{level} Exam and consolidation'**
  String pathExamConsolidation(String level);

  /// No description provided for @pathFallbackPayoff.
  ///
  /// In en, this message translates to:
  /// **'Build confidence for the next Czech task.'**
  String get pathFallbackPayoff;

  /// No description provided for @homeSmallWin.
  ///
  /// In en, this message translates to:
  /// **'A small Czech win is waiting for you.'**
  String get homeSmallWin;

  /// No description provided for @homeProgressToday.
  ///
  /// In en, this message translates to:
  /// **'You have already made Czech progress today.'**
  String get homeProgressToday;

  /// No description provided for @homeDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get homeDailyGoal;

  /// No description provided for @homeGoalDone.
  ///
  /// In en, this message translates to:
  /// **'Done for today. Anything else is a bonus.'**
  String get homeGoalDone;

  /// No description provided for @homeGoalStart.
  ///
  /// In en, this message translates to:
  /// **'One short lesson gets today moving.'**
  String get homeGoalStart;

  /// No description provided for @homeContinueLearning.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE LEARNING'**
  String get homeContinueLearning;

  /// No description provided for @homeCompleteLesson.
  ///
  /// In en, this message translates to:
  /// **'Complete one lesson'**
  String get homeCompleteLesson;

  /// No description provided for @homeReviewFive.
  ///
  /// In en, this message translates to:
  /// **'Review five cards'**
  String get homeReviewFive;

  /// No description provided for @homeSpeakTwoMinutes.
  ///
  /// In en, this message translates to:
  /// **'Speak for two minutes'**
  String get homeSpeakTwoMinutes;

  /// No description provided for @homeSmallSteps.
  ///
  /// In en, this message translates to:
  /// **'Today, in small steps'**
  String get homeSmallSteps;

  /// No description provided for @homeDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get homeDone;

  /// No description provided for @homeMethodOfDay.
  ///
  /// In en, this message translates to:
  /// **'METHOD OF THE DAY'**
  String get homeMethodOfDay;

  /// No description provided for @homeWriteBeforeType.
  ///
  /// In en, this message translates to:
  /// **'Write it before you type it'**
  String get homeWriteBeforeType;

  /// No description provided for @homeCopybookCta.
  ///
  /// In en, this message translates to:
  /// **'Open today’s copybook'**
  String get homeCopybookCta;

  /// No description provided for @homeXpRemaining.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP to your daily rhythm.'**
  String homeXpRemaining(int xp);

  /// No description provided for @homeFreezeLeft.
  ///
  /// In en, this message translates to:
  /// **'1 freeze left'**
  String get homeFreezeLeft;

  /// No description provided for @homeTotalXp.
  ///
  /// In en, this message translates to:
  /// **'{xp} total XP'**
  String homeTotalXp(int xp);

  /// No description provided for @homeMethodBody.
  ///
  /// In en, this message translates to:
  /// **'Handwriting slows Czech down just enough to make endings and diacritics visible.'**
  String get homeMethodBody;

  /// No description provided for @homeUnlockedComplete.
  ///
  /// In en, this message translates to:
  /// **'Every unlocked lesson is complete.'**
  String get homeUnlockedComplete;

  /// No description provided for @homeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get homeLoading;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingEditableLater.
  ///
  /// In en, this message translates to:
  /// **'All of this is editable later in Settings.'**
  String get onboardingEditableLater;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingStartLearning.
  ///
  /// In en, this message translates to:
  /// **'Start learning'**
  String get onboardingStartLearning;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip — set this up later'**
  String get onboardingSkip;

  /// No description provided for @onboardingNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should Lenka call you?'**
  String get onboardingNameTitle;

  /// No description provided for @onboardingNameBody.
  ///
  /// In en, this message translates to:
  /// **'Optional. Used to greet you in Czech, and it never leaves your device.'**
  String get onboardingNameBody;

  /// No description provided for @onboardingFirstName.
  ///
  /// In en, this message translates to:
  /// **'FIRST NAME'**
  String get onboardingFirstName;

  /// No description provided for @onboardingLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'What’s your Czech level?'**
  String get onboardingLevelTitle;

  /// No description provided for @onboardingLevelBody.
  ///
  /// In en, this message translates to:
  /// **'This sets your AI tutor’s difficulty. Lessons always start from Unit 1 so nothing is skipped.'**
  String get onboardingLevelBody;

  /// No description provided for @onboardingBeginner.
  ///
  /// In en, this message translates to:
  /// **'Complete beginner'**
  String get onboardingBeginner;

  /// No description provided for @onboardingBeginnerBody.
  ///
  /// In en, this message translates to:
  /// **'I don’t know any Czech yet'**
  String get onboardingBeginnerBody;

  /// No description provided for @onboardingA1.
  ///
  /// In en, this message translates to:
  /// **'Some Czech (A1)'**
  String get onboardingA1;

  /// No description provided for @onboardingA1Body.
  ///
  /// In en, this message translates to:
  /// **'I know basic greetings and simple phrases'**
  String get onboardingA1Body;

  /// No description provided for @onboardingA2.
  ///
  /// In en, this message translates to:
  /// **'Intermediate (A2)'**
  String get onboardingA2;

  /// No description provided for @onboardingA2Body.
  ///
  /// In en, this message translates to:
  /// **'I can have basic conversations'**
  String get onboardingA2Body;

  /// No description provided for @onboardingTakePlacement.
  ///
  /// In en, this message translates to:
  /// **'Not sure? Take a placement test'**
  String get onboardingTakePlacement;

  /// No description provided for @onboardingVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your teacher’s voice'**
  String get onboardingVoiceTitle;

  /// No description provided for @onboardingVoiceBody.
  ///
  /// In en, this message translates to:
  /// **'Every Czech word in the course is spoken by this voice. Tap to hear each one — you can change it any time from Settings.'**
  String get onboardingVoiceBody;

  /// No description provided for @onboardingFemaleVoice.
  ///
  /// In en, this message translates to:
  /// **'Female voice'**
  String get onboardingFemaleVoice;

  /// No description provided for @onboardingMaleVoice.
  ///
  /// In en, this message translates to:
  /// **'Male voice'**
  String get onboardingMaleVoice;

  /// No description provided for @onboardingVoiceSample.
  ///
  /// In en, this message translates to:
  /// **'Tap to hear a sample'**
  String get onboardingVoiceSample;

  /// No description provided for @onboardingNativeVoices.
  ///
  /// In en, this message translates to:
  /// **'Both are studio-recorded native Czech.'**
  String get onboardingNativeVoices;

  /// No description provided for @onboardingGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Set your daily goal'**
  String get onboardingGoalTitle;

  /// No description provided for @onboardingGoalBody.
  ///
  /// In en, this message translates to:
  /// **'How much do you want to practice each day?'**
  String get onboardingGoalBody;

  /// No description provided for @onboardingPlanReady.
  ///
  /// In en, this message translates to:
  /// **'Your plan is ready'**
  String get onboardingPlanReady;

  /// No description provided for @onboardingPlanBody.
  ///
  /// In en, this message translates to:
  /// **'Unit 1 starts with the sounds of Czech — including the one only Czech has.'**
  String get onboardingPlanBody;

  /// No description provided for @onboardingName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get onboardingName;

  /// No description provided for @onboardingLearner.
  ///
  /// In en, this message translates to:
  /// **'Learner'**
  String get onboardingLearner;

  /// No description provided for @onboardingStartingPoint.
  ///
  /// In en, this message translates to:
  /// **'Starting point'**
  String get onboardingStartingPoint;

  /// No description provided for @onboardingTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get onboardingTeacher;

  /// No description provided for @onboardingFirstUnit.
  ///
  /// In en, this message translates to:
  /// **'First unit'**
  String get onboardingFirstUnit;

  /// No description provided for @onboardingSoundsOfCzech.
  ///
  /// In en, this message translates to:
  /// **'The sounds of Czech'**
  String get onboardingSoundsOfCzech;

  /// No description provided for @scenarioCasual.
  ///
  /// In en, this message translates to:
  /// **'Casual Chat'**
  String get scenarioCasual;

  /// No description provided for @scenarioCasualBody.
  ///
  /// In en, this message translates to:
  /// **'Everyday small talk — greetings, weather, how are you'**
  String get scenarioCasualBody;

  /// No description provided for @scenarioRestaurant.
  ///
  /// In en, this message translates to:
  /// **'At the Restaurant'**
  String get scenarioRestaurant;

  /// No description provided for @scenarioRestaurantBody.
  ///
  /// In en, this message translates to:
  /// **'Order food, ask about menu, pay the bill'**
  String get scenarioRestaurantBody;

  /// No description provided for @scenarioDirections.
  ///
  /// In en, this message translates to:
  /// **'Asking Directions'**
  String get scenarioDirections;

  /// No description provided for @scenarioDirectionsBody.
  ///
  /// In en, this message translates to:
  /// **'Ask for and give directions in the city'**
  String get scenarioDirectionsBody;

  /// No description provided for @scenarioShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get scenarioShopping;

  /// No description provided for @scenarioShoppingBody.
  ///
  /// In en, this message translates to:
  /// **'Buy items, ask prices, negotiate'**
  String get scenarioShoppingBody;

  /// No description provided for @scenarioDoctor.
  ///
  /// In en, this message translates to:
  /// **'At the Doctor'**
  String get scenarioDoctor;

  /// No description provided for @scenarioDoctorBody.
  ///
  /// In en, this message translates to:
  /// **'Describe symptoms, make an appointment'**
  String get scenarioDoctorBody;

  /// No description provided for @scenarioInterview.
  ///
  /// In en, this message translates to:
  /// **'Job Interview'**
  String get scenarioInterview;

  /// No description provided for @scenarioInterviewBody.
  ///
  /// In en, this message translates to:
  /// **'Practice a basic job interview in Czech'**
  String get scenarioInterviewBody;

  /// No description provided for @scenarioCafeImage.
  ///
  /// In en, this message translates to:
  /// **'A learner ordering at a Prague café'**
  String get scenarioCafeImage;

  /// No description provided for @scenarioDirectionsImage.
  ///
  /// In en, this message translates to:
  /// **'A learner asking for directions beside a Prague tram'**
  String get scenarioDirectionsImage;

  /// No description provided for @scenarioShoppingImage.
  ///
  /// In en, this message translates to:
  /// **'A learner shopping at a Czech neighborhood market'**
  String get scenarioShoppingImage;

  /// No description provided for @scenarioRestaurantImage.
  ///
  /// In en, this message translates to:
  /// **'A learner ordering at a Czech restaurant'**
  String get scenarioRestaurantImage;

  /// No description provided for @scenarioDoctorImage.
  ///
  /// In en, this message translates to:
  /// **'A learner speaking with a doctor'**
  String get scenarioDoctorImage;

  /// No description provided for @scenarioInterviewImage.
  ///
  /// In en, this message translates to:
  /// **'A learner taking part in a job interview'**
  String get scenarioInterviewImage;

  /// No description provided for @onboardingTagline.
  ///
  /// In en, this message translates to:
  /// **'Czech that\nactually\nsticks.'**
  String get onboardingTagline;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Built for people living in Czechia — from your first word to the A1 exam.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingHeroImage.
  ///
  /// In en, this message translates to:
  /// **'A learner practising Czech with a tutor at a Prague café'**
  String get onboardingHeroImage;

  /// No description provided for @onboardingOffline.
  ///
  /// In en, this message translates to:
  /// **'Works offline — lessons and audio live on your phone'**
  String get onboardingOffline;

  /// No description provided for @onboardingStartFree.
  ///
  /// In en, this message translates to:
  /// **'Start learning free'**
  String get onboardingStartFree;

  /// No description provided for @onboardingHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get onboardingHaveAccount;

  /// No description provided for @homeSpeakTitle.
  ///
  /// In en, this message translates to:
  /// **'Say it out loud'**
  String get homeSpeakTitle;

  /// No description provided for @homeSpeakReviews.
  ///
  /// In en, this message translates to:
  /// **'Two minutes of Czech, then {count} reviews.'**
  String homeSpeakReviews(int count);

  /// No description provided for @homeSpeakSound.
  ///
  /// In en, this message translates to:
  /// **'Two minutes of ř — the sound worth practising.'**
  String get homeSpeakSound;

  /// No description provided for @chatVoiceRetry.
  ///
  /// In en, this message translates to:
  /// **'I didn’t catch that. Try again somewhere quieter, or type your reply.'**
  String get chatVoiceRetry;

  /// No description provided for @chatVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input is unavailable. You can still type every reply.'**
  String get chatVoiceUnavailable;

  /// No description provided for @chatDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get chatDismiss;

  /// No description provided for @curriculumPathTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Czech path'**
  String get curriculumPathTitle;

  /// No description provided for @curriculumAddingLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons for this level are being added.'**
  String get curriculumAddingLessons;

  /// No description provided for @curriculumA1Complete.
  ///
  /// In en, this message translates to:
  /// **'That’s the complete A1 track. Finish it and A2 opens.'**
  String get curriculumA1Complete;

  /// No description provided for @curriculumA2Complete.
  ///
  /// In en, this message translates to:
  /// **'That’s the complete A2 track.'**
  String get curriculumA2Complete;

  /// No description provided for @curriculumUnit.
  ///
  /// In en, this message translates to:
  /// **'UNIT {number}'**
  String curriculumUnit(int number);

  /// No description provided for @curriculumInProgress.
  ///
  /// In en, this message translates to:
  /// **'IN PROGRESS'**
  String get curriculumInProgress;

  /// No description provided for @curriculumUnitOf.
  ///
  /// In en, this message translates to:
  /// **'Unit {number} of {total} · {level}'**
  String curriculumUnitOf(int number, int total, String level);

  /// No description provided for @curriculumUnlocksAfter.
  ///
  /// In en, this message translates to:
  /// **'Unlocks after unit {number}'**
  String curriculumUnlocksAfter(int number);

  /// No description provided for @curriculumLessonCount.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} lessons'**
  String curriculumLessonCount(int done, int total);

  /// No description provided for @curriculumStateDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get curriculumStateDone;

  /// No description provided for @curriculumStateReady.
  ///
  /// In en, this message translates to:
  /// **'Ready now'**
  String get curriculumStateReady;

  /// No description provided for @curriculumStateLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get curriculumStateLocked;

  /// No description provided for @curriculumNextUp.
  ///
  /// In en, this message translates to:
  /// **'NEXT UP'**
  String get curriculumNextUp;

  /// No description provided for @curriculumMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get curriculumMap;

  /// No description provided for @curriculumList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get curriculumList;

  /// No description provided for @lessonTypeLesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get lessonTypeLesson;

  /// No description provided for @lessonTypePractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get lessonTypePractice;

  /// No description provided for @lessonTypeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get lessonTypeApply;

  /// No description provided for @lessonTypeReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get lessonTypeReview;

  /// No description provided for @settingsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get settingsDone;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Czech'**
  String get statsTitle;

  /// No description provided for @statsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where you are, and what to work on next.'**
  String get statsSubtitle;

  /// No description provided for @statsCourseActivityInfo.
  ///
  /// In en, this message translates to:
  /// **'Course activity shows what you have practised. It is not a CEFR certification.'**
  String get statsCourseActivityInfo;

  /// No description provided for @statsAboutNumber.
  ///
  /// In en, this message translates to:
  /// **'About this number'**
  String get statsAboutNumber;

  /// No description provided for @statsAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get statsAchievements;

  /// No description provided for @statsAchievementsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your first achievements are already within reach.'**
  String get statsAchievementsEmpty;

  /// No description provided for @statsCourseProgress.
  ///
  /// In en, this message translates to:
  /// **'Course progress'**
  String get statsCourseProgress;

  /// No description provided for @statsCourseProgressBody.
  ///
  /// In en, this message translates to:
  /// **'Required lessons completed at each course level.'**
  String get statsCourseProgressBody;

  /// No description provided for @statsPracticeNext.
  ///
  /// In en, this message translates to:
  /// **'Practise next'**
  String get statsPracticeNext;

  /// No description provided for @statsPracticeNextDefault.
  ///
  /// In en, this message translates to:
  /// **'Continue with your next lesson to build a clearer picture of your strengths.'**
  String get statsPracticeNextDefault;

  /// No description provided for @statsPracticeNextConcept.
  ///
  /// In en, this message translates to:
  /// **'Your recent answers suggest revisiting {concept}.'**
  String statsPracticeNextConcept(String concept);

  /// No description provided for @statsContinueLearning.
  ///
  /// In en, this message translates to:
  /// **'Continue learning'**
  String get statsContinueLearning;

  /// No description provided for @statsConceptsToRevisit.
  ///
  /// In en, this message translates to:
  /// **'Topics to revisit'**
  String get statsConceptsToRevisit;

  /// No description provided for @statsConceptsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Topics that were difficult on the first try. Successful retries are shown separately.'**
  String get statsConceptsExplanation;

  /// No description provided for @statsNoConceptErrors.
  ///
  /// In en, this message translates to:
  /// **'No difficult topics recorded yet.'**
  String get statsNoConceptErrors;

  /// No description provided for @statsErrorsRepaired.
  ///
  /// In en, this message translates to:
  /// **'{errors} difficult · {repaired} improved'**
  String statsErrorsRepaired(int errors, int repaired);

  /// No description provided for @statsSkillPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice by skill'**
  String get statsSkillPractice;

  /// No description provided for @statsSkillExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your accuracy the first time you answered each type of exercise.'**
  String get statsSkillExplanation;

  /// No description provided for @statsNoSkillEvidence.
  ///
  /// In en, this message translates to:
  /// **'Complete lesson exercises to see skill progress here.'**
  String get statsNoSkillEvidence;

  /// No description provided for @statsAttemptEvidence.
  ///
  /// In en, this message translates to:
  /// **'{depth} · {attempts} first attempts · {repair} after retry'**
  String statsAttemptEvidence(String depth, int attempts, String repair);

  /// No description provided for @statsDayStreak.
  ///
  /// In en, this message translates to:
  /// **'Day streak'**
  String get statsDayStreak;

  /// No description provided for @statsTotalXp.
  ///
  /// In en, this message translates to:
  /// **'Total XP'**
  String get statsTotalXp;

  /// No description provided for @statsLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get statsLongestStreak;

  /// No description provided for @statsHearts.
  ///
  /// In en, this message translates to:
  /// **'Hearts'**
  String get statsHearts;

  /// No description provided for @statsNoLessonsYet.
  ///
  /// In en, this message translates to:
  /// **'Complete a lesson to start seeing your progress.'**
  String get statsNoLessonsYet;

  /// No description provided for @statsUnitProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress by unit'**
  String get statsUnitProgress;

  /// No description provided for @statsUnitProgressBody.
  ///
  /// In en, this message translates to:
  /// **'Your best lesson results across the required lessons in each unit.'**
  String get statsUnitProgressBody;

  /// No description provided for @statsA1Units.
  ///
  /// In en, this message translates to:
  /// **'A1 units'**
  String get statsA1Units;

  /// No description provided for @statsA2Units.
  ///
  /// In en, this message translates to:
  /// **'A2 units'**
  String get statsA2Units;

  /// No description provided for @placementTitle.
  ///
  /// In en, this message translates to:
  /// **'Find my starting point'**
  String get placementTitle;

  /// No description provided for @placementSuggestedUnit.
  ///
  /// In en, this message translates to:
  /// **'Suggested starting unit: {unit}'**
  String placementSuggestedUnit(int unit);

  /// No description provided for @placementProvisional.
  ///
  /// In en, this message translates to:
  /// **'Provisional, not a CEFR result — it adjusts from your own performance.'**
  String get placementProvisional;

  /// No description provided for @placementChooseUnit.
  ///
  /// In en, this message translates to:
  /// **'Choose a different starting unit'**
  String get placementChooseUnit;

  /// No description provided for @placementUseStart.
  ///
  /// In en, this message translates to:
  /// **'Use this starting point'**
  String get placementUseStart;

  /// No description provided for @placementAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Czech answer'**
  String get placementAnswerLabel;

  /// No description provided for @placementNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get placementNext;

  /// No description provided for @placementFinishLater.
  ///
  /// In en, this message translates to:
  /// **'Finish later'**
  String get placementFinishLater;

  /// No description provided for @placementAdaptiveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question {count} · adaptive test'**
  String placementAdaptiveQuestion(int count);

  /// No description provided for @reviewNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get reviewNew;

  /// No description provided for @reviewLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get reviewLearning;

  /// No description provided for @reviewReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewReview;

  /// No description provided for @reviewDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get reviewDue;

  /// No description provided for @lessonMeetWords.
  ///
  /// In en, this message translates to:
  /// **'Meet these words first. Tap each one to hear it, then practise using it.'**
  String get lessonMeetWords;

  /// No description provided for @teachingLookAndGuess.
  ///
  /// In en, this message translates to:
  /// **'Look at the picture. What do you think this Czech word means?'**
  String get teachingLookAndGuess;

  /// No description provided for @teachingTapWordMeaning.
  ///
  /// In en, this message translates to:
  /// **'Tap the Czech word to reveal its meaning'**
  String get teachingTapWordMeaning;

  /// No description provided for @teachingMeaning.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get teachingMeaning;

  /// No description provided for @teachingInSentence.
  ///
  /// In en, this message translates to:
  /// **'Now hear it in a useful sentence'**
  String get teachingInSentence;

  /// No description provided for @teachingTapSentenceTranslation.
  ///
  /// In en, this message translates to:
  /// **'Tap the sentence to reveal the translation'**
  String get teachingTapSentenceTranslation;

  /// No description provided for @teachingNextWord.
  ///
  /// In en, this message translates to:
  /// **'Next word'**
  String get teachingNextWord;

  /// No description provided for @teachingSeeExample.
  ///
  /// In en, this message translates to:
  /// **'See it in a sentence'**
  String get teachingSeeExample;

  /// No description provided for @teachingStartExercises.
  ///
  /// In en, this message translates to:
  /// **'Start practice exercises'**
  String get teachingStartExercises;

  /// No description provided for @teachingWordProgress.
  ///
  /// In en, this message translates to:
  /// **'Word {current} of {total}'**
  String teachingWordProgress(int current, int total);

  /// No description provided for @a11yTapToFlipCard.
  ///
  /// In en, this message translates to:
  /// **'Tap to flip card'**
  String get a11yTapToFlipCard;

  /// No description provided for @a11yPlayPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Play pronunciation'**
  String get a11yPlayPronunciation;

  /// No description provided for @a11yTapToHear.
  ///
  /// In en, this message translates to:
  /// **'Tap to hear: {text}'**
  String a11yTapToHear(String text);

  /// No description provided for @a11yTapToHearSentence.
  ///
  /// In en, this message translates to:
  /// **'Tap to hear the sentence'**
  String get a11yTapToHearSentence;

  /// No description provided for @a11yInsertCharacter.
  ///
  /// In en, this message translates to:
  /// **'Insert character: {char}'**
  String a11yInsertCharacter(String char);

  /// No description provided for @a11yAddVocabToDeck.
  ///
  /// In en, this message translates to:
  /// **'Add to review deck'**
  String get a11yAddVocabToDeck;

  /// No description provided for @a11yScenarioCard.
  ///
  /// In en, this message translates to:
  /// **'Scenario: {title}. {description}'**
  String a11yScenarioCard(String title, String description);

  /// No description provided for @a11yFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback: {title}'**
  String a11yFeedback(String title);

  /// No description provided for @a11yContinueButton.
  ///
  /// In en, this message translates to:
  /// **'{label} button'**
  String a11yContinueButton(String label);

  /// No description provided for @a11ySendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get a11ySendMessage;

  /// No description provided for @reminderStepTitle.
  ///
  /// In en, this message translates to:
  /// **'When should we nudge you?'**
  String get reminderStepTitle;

  /// No description provided for @reminderStepBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a time and we\'ll send a gentle reminder around that time to practice Czech.'**
  String get reminderStepBody;

  /// No description provided for @reminderStepToggle.
  ///
  /// In en, this message translates to:
  /// **'Yes, remind me daily'**
  String get reminderStepToggle;

  /// No description provided for @reminderStepCatchUp.
  ///
  /// In en, this message translates to:
  /// **'Plus a gentle evening nudge at 21:30 if you haven\'t studied yet.'**
  String get reminderStepCatchUp;

  /// No description provided for @reminderStepChangeAnytime.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in Settings.'**
  String get reminderStepChangeAnytime;

  /// No description provided for @reminderSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Study Reminders'**
  String get reminderSettingsTitle;

  /// No description provided for @reminderSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll remind you around your chosen time. Plus a gentle evening nudge if you haven\'t studied yet.'**
  String get reminderSettingsBody;

  /// No description provided for @reminderTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTimeLabel;

  /// No description provided for @reminderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Reminders on'**
  String get reminderEnabled;

  /// No description provided for @reminderDisabled.
  ///
  /// In en, this message translates to:
  /// **'Reminders off'**
  String get reminderDisabled;

  /// No description provided for @reminderCatchUpLabel.
  ///
  /// In en, this message translates to:
  /// **'Evening catch-up'**
  String get reminderCatchUpLabel;

  /// No description provided for @reminderCatchUpSuppressed.
  ///
  /// In en, this message translates to:
  /// **'Evening catch-up is off because your reminder time is close to 21:30.'**
  String get reminderCatchUpSuppressed;

  /// No description provided for @reminderPermissionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked. Open Settings → Notifications → Czechify to enable.'**
  String get reminderPermissionBlocked;

  /// No description provided for @reminderOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get reminderOpenSettings;

  /// No description provided for @reminderSettingsEntryBanner.
  ///
  /// In en, this message translates to:
  /// **'Get daily reminders to keep your streak going.'**
  String get reminderSettingsEntryBanner;

  /// No description provided for @pronTipExcellent.
  ///
  /// In en, this message translates to:
  /// **'Great! Excellent pronunciation.'**
  String get pronTipExcellent;

  /// No description provided for @pronTipUnrecognisable.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t match the phrase — listen again and try once more.'**
  String get pronTipUnrecognisable;

  /// No description provided for @pronTipRolledRAsPlainR.
  ///
  /// In en, this message translates to:
  /// **'Your “ř” came out as a plain “r”. Keep the tongue trilling but press it closer to the ridge so it buzzes.'**
  String get pronTipRolledRAsPlainR;

  /// No description provided for @pronTipRolledR.
  ///
  /// In en, this message translates to:
  /// **'Work on “ř” — trill the tongue and add a buzz at the same time.'**
  String get pronTipRolledR;

  /// No description provided for @pronTipSofteningE.
  ///
  /// In en, this message translates to:
  /// **'The “ě” softens the consonant before it (dě → d+ye).'**
  String get pronTipSofteningE;

  /// No description provided for @pronTipVowelLength.
  ///
  /// In en, this message translates to:
  /// **'Czech distinguishes short and long vowels. Lengthen the vowel.'**
  String get pronTipVowelLength;

  /// No description provided for @pronTipVowelTooShort.
  ///
  /// In en, this message translates to:
  /// **'“{sound}” is a long vowel — hold it about twice as long. Czech uses length to change meaning (byt vs být).'**
  String pronTipVowelTooShort(String sound);

  /// No description provided for @pronTipVowelTooLong.
  ///
  /// In en, this message translates to:
  /// **'“{sound}” is short here — you lengthened it.'**
  String pronTipVowelTooLong(String sound);

  /// No description provided for @pronTipPalatal.
  ///
  /// In en, this message translates to:
  /// **'“{sound}” is palatal — press the middle of the tongue against the hard palate.'**
  String pronTipPalatal(String sound);

  /// No description provided for @pronTipSoundDropped.
  ///
  /// In en, this message translates to:
  /// **'You dropped the “{sound}” sound.'**
  String pronTipSoundDropped(String sound);

  /// No description provided for @pronTipSoundSubstituted.
  ///
  /// In en, this message translates to:
  /// **'“{sound}” came out closer to “{heard}”.'**
  String pronTipSoundSubstituted(String sound, String heard);

  /// No description provided for @pronTipRepeatWord.
  ///
  /// In en, this message translates to:
  /// **'Listen again and repeat “{word}” carefully.'**
  String pronTipRepeatWord(String word);

  /// No description provided for @pronTipCheckSound.
  ///
  /// In en, this message translates to:
  /// **'Check the “{sound}” sound in “{word}”.'**
  String pronTipCheckSound(String sound, String word);

  /// No description provided for @rankBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get rankBronze;

  /// No description provided for @rankSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get rankSilver;

  /// No description provided for @rankGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get rankGold;

  /// No description provided for @rankPlatinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum'**
  String get rankPlatinum;

  /// No description provided for @rankDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get rankDiamond;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['cs', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
