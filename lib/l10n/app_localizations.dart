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
  /// **'How well did you recall it? · sets when it returns'**
  String get reviewHowWellRecalled;

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
