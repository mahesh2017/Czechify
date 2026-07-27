// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Czechify';

  @override
  String get check => 'Check';

  @override
  String get continueLabel => 'Continue';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get nextPhrase => 'Next Phrase';

  @override
  String get skip => 'Skip';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get goHome => 'Go Home';

  @override
  String get startExam => 'Start Exam';

  @override
  String get resumeExam => 'Resume Exam';

  @override
  String get discardAndStartOver => 'Discard and start over';

  @override
  String get startRecording => 'Start recording';

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get listen => 'Listen';

  @override
  String get pronunciationLab => 'Pronunciation Lab';

  @override
  String get sayThis => 'Say this:';

  @override
  String get tapMicrophoneHint => 'Tap the microphone and say the phrase';

  @override
  String get analyzingPronunciation => 'Analyzing your pronunciation...';

  @override
  String get onDeviceRecognitionNote =>
      'Using on-device recognition — results may be less accurate.';

  @override
  String get navHome => 'Home';

  @override
  String get navLearn => 'Learn';

  @override
  String get navReview => 'Review';

  @override
  String get navChat => 'Chat';

  @override
  String get navStats => 'Stats';

  @override
  String get settings => 'Settings';

  @override
  String get settingsYourName => 'Your name';

  @override
  String get settingsDailyGoal => 'Daily goal';

  @override
  String settingsXpPerDay(int count) {
    return '$count XP per day';
  }

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsSoundEffects => 'Sound effects';

  @override
  String get settingsVibration => 'Vibration';

  @override
  String get settingsHearts => 'Hearts in lessons';

  @override
  String get settingsTestVoice => 'Test voice';

  @override
  String get settingsVoiceMale => 'Male';

  @override
  String get settingsVoiceFemale => 'Female';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsAbout => 'About Czechify';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsClearAudioCache => 'Clear audio cache';

  @override
  String get homeYourProgress => 'Your progress';

  @override
  String get homeBrowseCurriculum => 'Browse curriculum';

  @override
  String get homeGrammarReference => 'Grammar reference';

  @override
  String get homeMockExam => 'Mock exam';

  @override
  String get homeAiChat => 'AI Chat';

  @override
  String get homeSpeak => 'Speak';

  @override
  String get homeStartFirstLesson => 'Start your first lesson';

  @override
  String get homeAllCaughtUp => 'All caught up!';

  @override
  String homeDayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count day streak',
      one: '$count day streak',
    );
    return '$_temp0';
  }

  @override
  String homeHeartsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hearts remaining',
      one: '$count heart remaining',
    );
    return '$_temp0';
  }

  @override
  String get reviewShowAnswer => 'Show Answer';

  @override
  String get reviewTapToReveal => 'Tap to reveal';

  @override
  String get reviewRatingAgain => 'Again';

  @override
  String get reviewRatingHard => 'Hard';

  @override
  String get reviewRatingGood => 'Good';

  @override
  String get reviewRatingEasy => 'Easy';

  @override
  String get reviewEndTitle => 'End review?';

  @override
  String get reviewEndBody =>
      'Your progress will be saved. You can continue later.';

  @override
  String get reviewStay => 'Stay';

  @override
  String get reviewEnd => 'End';

  @override
  String get reviewNoCardsDue => 'No cards due for review right now.';

  @override
  String reviewCardOf(int current, int total) {
    return 'Card $current of $total';
  }

  @override
  String get lessonLeaveTitle => 'Leave lesson?';

  @override
  String get lessonLeaveBody =>
      'You\'ll go back to the curriculum. The answers you\'ve already given are saved.';

  @override
  String get lessonLeave => 'Leave';

  @override
  String lessonQuestionOf(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get errorFailedToLoad => 'Could not load this content.';

  @override
  String get errorCheckConnection => 'Check your connection and try again.';

  @override
  String get a11yBack => 'Back';

  @override
  String get a11yClose => 'Close';

  @override
  String get a11yPlayAudio => 'Play audio';

  @override
  String get a11ySettings => 'Settings';

  @override
  String a11yHearts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hearts left',
      one: '$count heart left',
    );
    return '$_temp0';
  }

  @override
  String a11yStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count day streak',
      one: '$count day streak',
    );
    return '$_temp0';
  }

  @override
  String a11yRateCard(String rating) {
    return 'Rate this card: $rating';
  }

  @override
  String a11yLessonProgress(int current, int total) {
    return 'Lesson progress: question $current of $total';
  }
}
