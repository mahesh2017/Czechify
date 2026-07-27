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
