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

  @override
  String get writingKeyPhrasesFound => 'Key phrases found';

  @override
  String get writingKeyPhrasesMissing => 'Key phrases not found';

  @override
  String get writingKeywordCheckNote =>
      'Automatic keyword check only — it compares your words against the expected phrases and does not judge grammar, spelling, or style.';

  @override
  String get audioHearIt => 'Hear it';

  @override
  String get audioSlow => 'Slow';

  @override
  String get audioSlower => 'Slower';

  @override
  String get audioStop => 'Stop';

  @override
  String get audioPlayAgain => 'Play it again';

  @override
  String get audioPlayIt => 'Play it';

  @override
  String get audioHearTheWord => 'Hear the word';

  @override
  String get czechLetters => 'Czech letters';

  @override
  String get feedbackCorrect => 'Správně!';

  @override
  String get feedbackNotQuite => 'Not quite';

  @override
  String get feedbackAnswerShown => 'Answer shown';

  @override
  String get feedbackSkipped => 'Skipped — no score or heart change';

  @override
  String get feedbackViewGrammarRule => 'View grammar rule';

  @override
  String get answerCorrectLabel => 'Correct';

  @override
  String get lessonIntroduction => 'Introduction';

  @override
  String get lessonMissedQuestions => 'Missed questions';

  @override
  String lessonInARow(int count) {
    return '$count in a row';
  }

  @override
  String lessonXpTotal(int count) {
    return '$count XP';
  }

  @override
  String lessonXpAward(int count) {
    return '+$count XP';
  }

  @override
  String get lessonNewWords => 'New words';

  @override
  String get lessonStartPractice => 'Start practice';

  @override
  String get lessonGotItStartPractising => 'Got it — start practising';

  @override
  String get lessonSaving => 'Saving…';

  @override
  String get lessonNextQuestion => 'Next question';

  @override
  String get lessonReviewMistakes => 'Review mistakes';

  @override
  String get lessonFinish => 'Finish lesson';

  @override
  String lessonFinishUnit(int number) {
    return 'Finish unit $number';
  }

  @override
  String get lessonContinueLearning => 'Continue learning';

  @override
  String get lessonPracticeAgain => 'Practice again';

  @override
  String get lessonLockedTitle => 'Not open yet';

  @override
  String get lessonLockedBody =>
      'Finish the lessons before this one and it unlocks.';

  @override
  String get lessonBackToCurriculum => 'Back to curriculum';

  @override
  String get lessonNoExercises => 'No exercises found for this lesson.';

  @override
  String get lessonOutOfHeartsTitle => 'Out of hearts';

  @override
  String get lessonOutOfHeartsBody =>
      'Hearts refill on their own — one every 30 minutes. A review session of five or more cards earns one back now.';

  @override
  String get lessonReviewToEarnHeart => 'Review to earn a heart';

  @override
  String get lessonBadgeExam => 'Exam';

  @override
  String get statAccuracy => 'Accuracy';

  @override
  String get statXpEarned => 'XP earned';

  @override
  String get statCorrect => 'Correct';

  @override
  String get statMissed => 'Missed';

  @override
  String get statCards => 'Cards';

  @override
  String get statRecalled => 'Recalled';

  @override
  String get captionAccuracy => 'accuracy';

  @override
  String get captionRecall => 'recall';

  @override
  String get captionMatch => 'match';

  @override
  String get exerciseCheckAnswers => 'Check answers';

  @override
  String get exerciseCheckAll => 'Check all';

  @override
  String exerciseQuestionNumber(int number) {
    return 'Question $number';
  }

  @override
  String get exerciseAllCorrect => 'All correct';

  @override
  String get exerciseSomeAnswersWrong =>
      'Some answers are wrong — review them below.';

  @override
  String get exerciseSomePairsWrong => 'Some pairs are wrong';

  @override
  String exerciseCorrectOfTotal(int correct, int total) {
    return '$correct/$total correct';
  }

  @override
  String exerciseMatchedOfTotal(int matched, int total) {
    return '$matched/$total matched';
  }

  @override
  String get exerciseTapCzechThenEnglish =>
      'Tap a Czech word, then tap its English match.';

  @override
  String get exerciseTapWordsInOrder => 'Tap the words below in order';

  @override
  String get exerciseTypeWhatYouHeard => 'Type what you heard';

  @override
  String get exerciseRevealTranscript => 'Reveal transcript';

  @override
  String get exerciseGistFirstNote =>
      'Listen for the gist first. Replay or reveal the transcript only when you need support.';

  @override
  String get exerciseNoQuestions =>
      'This exercise has no questions configured.';

  @override
  String get exerciseSayInCzech => 'Say this in Czech';

  @override
  String get exerciseSayInEnglish => 'Say this in English';

  @override
  String get exerciseTypeInCzech => 'Type in Czech';

  @override
  String get exerciseTypeInEnglish => 'Type in English';

  @override
  String get labelEnglish => 'English';

  @override
  String get labelCzech => 'Czech';

  @override
  String get exerciseChooseCorrectForm => 'Choose the correct form';

  @override
  String get exerciseTypeCorrectSentence => 'Type the correct sentence';

  @override
  String get exerciseCorrectedSentence => 'Corrected sentence';

  @override
  String get exerciseShowHint => 'Show hint';

  @override
  String get exerciseErrorInHighlighted =>
      'The error is in one of the highlighted words above.';

  @override
  String exerciseDeclineWord(String word) {
    return 'Decline $word';
  }

  @override
  String get exerciseYourAnswer => 'Your answer';

  @override
  String get teachingKicker => 'Learn';

  @override
  String get teachingIntro => 'Intro';

  @override
  String get teachingLetterByLetter => 'Letter by letter';

  @override
  String get teachingTapAnyLetter => 'Tap any letter to hear it';

  @override
  String get teachingTapLineToHear => 'Tap a line to hear it';

  @override
  String get teachingPlayWholeSet => 'Play the whole set';

  @override
  String writingWriteAtLeast(int count) {
    return 'Write at least $count words.';
  }

  @override
  String get writingHint => 'Write your answer in Czech…';

  @override
  String get writingShowVocabSupport => 'Show vocabulary support';

  @override
  String get writingTryUsing => 'Try using';

  @override
  String get writingReviseNote =>
      'Revise: check the communicative goal, verb forms, case endings, word order, and register. Improve the message, not only its length.';

  @override
  String get writingReviewDraft => 'Review draft';

  @override
  String get writingSubmitRevision => 'Submit revision';

  @override
  String get writingCycleComplete => 'Writing cycle complete';

  @override
  String get writingReferenceAnswer => 'Reference answer';

  @override
  String writingWordCountMin(int count, int min) {
    return '$count words · minimum $min';
  }

  @override
  String writingWordCount(int count) {
    return '$count words';
  }

  @override
  String get speakingTryToSay => 'Try to say';

  @override
  String get speakingYouSaid => 'You said';

  @override
  String get speakingTapToSpeak => 'Tap to speak';

  @override
  String get speakingTapToRerecord => 'Tap to re-record';

  @override
  String get speakingRecordingTapToStop => 'Recording — tap to stop';

  @override
  String get pronTapToRecord => 'Tap to record';

  @override
  String get pronRecordedTapAgain => 'Recorded — tap to try again';

  @override
  String get pronListeningTapToStop => 'Listening — tap to stop';

  @override
  String get pronAnalysing => 'Analysing…';

  @override
  String get pronMicNotWorkingSkip => 'Mic not working? Skip';

  @override
  String get pronCantRecordSkip => 'Can\'t record right now? Skip';

  @override
  String get pronSkippedNote =>
      'Skipped — keep practising this one aloud with the listen button.';

  @override
  String get reviewSpacedRepetition => 'Spaced repetition';

  @override
  String reviewCardsLeft(int count) {
    return '$count left';
  }

  @override
  String get reviewRetrieveTheCzech => 'Retrieve the Czech';

  @override
  String get reviewSayItThenTypeIt => 'Say it, then type it';

  @override
  String get reviewOvertAttemptNote =>
      'Make an overt attempt before revealing.';

  @override
  String get reviewWhatDoesItMean => 'What does it mean?';

  @override
  String get reviewMeans => 'Means';

  @override
  String get reviewHowDoYouSayIt => 'How do you say it in Czech?';

  @override
  String get reviewCompleteCzechSentence => 'Complete the Czech sentence.';

  @override
  String get reviewDirectionEnToCz => 'EN → CZ';

  @override
  String get reviewDirectionListening => 'Listening';

  @override
  String get reviewHowWellRecalled =>
      'How well did you recall it? · sets when it returns';

  @override
  String get reviewAllCaughtUp => 'All caught up';

  @override
  String get reviewCheckAgain => 'Check again';

  @override
  String get reviewNoCardsAvailable => 'No cards available.';

  @override
  String get reviewDeckCleared => 'Deck cleared';

  @override
  String reviewCardsReviewed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nice work — $count cards reviewed',
      one: 'Nice work — $count card reviewed',
    );
    return '$_temp0';
  }

  @override
  String get reviewHeartEarned => '+1 heart earned';

  @override
  String get reviewHowItWent => 'How it went';

  @override
  String get reviewReschedulingNote =>
      'These cards are rescheduled with spaced repetition — each one comes back right when it is about to slip.';

  @override
  String get reviewGoAgain => 'Go again';

  @override
  String get reviewDone => 'Done';

  @override
  String get reviewIntervalSoon => 'Soon';

  @override
  String get chatTitle => 'AI Tutor';

  @override
  String get chatSubtitle =>
      'Real situations you will hit this week in Czechia. The tutor adapts to your level.';

  @override
  String get chatUnfinished => 'Unfinished';

  @override
  String get chatPickASituation => 'Pick a situation';

  @override
  String chatRoomCount(int count) {
    return '$count rooms';
  }

  @override
  String chatTurnsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count turns in',
      one: '$count turn in',
    );
    return '$_temp0';
  }

  @override
  String get chatBackToScenarios => 'Back to scenarios';

  @override
  String get chatTutorIsTyping => 'The tutor is typing';

  @override
  String get chatSpeakYourReply => 'Speak your reply';

  @override
  String get chatComposerHint => 'Napiš česky…';

  @override
  String get chatListeningHint => 'Listening… speak Czech';

  @override
  String get chatDeleteConversation => 'Delete conversation';

  @override
  String get exerciseAllAnsweredCorrectly =>
      'All questions answered correctly.';

  @override
  String get exerciseNoQuestionsAvailable =>
      'No questions available for this exercise.';

  @override
  String exerciseYouGotCorrect(int correct, int total) {
    return 'You got $correct/$total correct.';
  }

  @override
  String get pronFeedbackGood => 'Good pronunciation.';

  @override
  String get pronFeedbackRetry =>
      'Try again — focus on the highlighted sounds.';

  @override
  String get speakingFeedbackGood => 'Good — you said the right things.';

  @override
  String speakingFeedbackRetry(String phrases) {
    return 'Try again. Expected phrases include: $phrases';
  }

  @override
  String get recordingFailed => 'Recording failed. Please try again.';

  @override
  String writingWroteWords(int count) {
    return 'You wrote $count words.';
  }

  @override
  String writingMeetsMinimum(int min) {
    return 'Meets the $min-word minimum.';
  }

  @override
  String writingNeedsMinimum(int min) {
    return 'Needs at least $min words.';
  }

  @override
  String get writingGoodKeywordCoverage => 'Good keyword coverage.';

  @override
  String get writingKeyPhrasesNotDetected => 'Key phrases not detected.';

  @override
  String get writingUnscoredNote =>
      'Completed as unscored writing practice; no automatic proficiency claim is made.';

  @override
  String get writingRevisedDraft => 'You revised the first draft.';

  @override
  String translationAccentHint(String answer) {
    return 'Almost — watch your accent marks. The correct spelling is \"$answer\".';
  }

  @override
  String get dictationAccentHint =>
      'Almost — watch your accent marks. You had it right apart from the diacritics.';

  @override
  String get examResultsTitle => 'Exam results';

  @override
  String get examPracticeComplete => 'Practice complete';

  @override
  String get examPracticeTargetMet => 'Practice target met';

  @override
  String get examThresholdMet => 'Practice threshold met';

  @override
  String get examThresholdNotMet => 'Practice threshold not met';

  @override
  String get examPartlyUnscored => 'Practice completed — some tasks unscored';

  @override
  String examCourseTrack(String level) {
    return 'Course track $level';
  }

  @override
  String get examAccuracyCaveat =>
      'Lesson exercise accuracy only. This is not an official exam result or CEFR certification.';

  @override
  String examMockTitle(String level) {
    return 'Mock exam — $level';
  }

  @override
  String examPracticeExamTitle(String product, String level) {
    return '$product $level practice exam';
  }

  @override
  String get examFourSections =>
      'Four timed sections. The timer runs per section, and you can answer in order.';

  @override
  String get examInformalNote =>
      'This is informal practice, not an official exam result.';

  @override
  String get examSectionReading => 'Reading';

  @override
  String get examSectionReadingSub => 'Comprehension questions';

  @override
  String get examSectionListening => 'Listening';

  @override
  String get examSectionListeningSub => 'Audio, then questions';

  @override
  String get examSectionWriting => 'Writing';

  @override
  String get examSectionWritingSub => 'Practice feedback when available';

  @override
  String get examSectionSpeaking => 'Speaking';

  @override
  String get examSectionSpeakingSub => 'Transcript-based practice evidence';

  @override
  String examTotalTime(int minutes) {
    return 'Total time: $minutes minutes';
  }

  @override
  String get examDone => 'Done';

  @override
  String get examPlayAudio => 'Play the audio';

  @override
  String get feedbackStepSignal =>
      'Something needs attention. Try to notice what.';

  @override
  String get feedbackStepSelfRepair => 'Try again before asking for more help.';

  @override
  String get feedbackStepCue =>
      'Use the explanation as a cue, then repair your answer.';

  @override
  String get feedbackStepExplanation =>
      'Study the answer, then retrieve it once more.';

  @override
  String get feedbackStepImmediateVariant =>
      'Now apply the same idea to a variation.';

  @override
  String get feedbackStepSpacedAnalogue => 'A related task will return later.';

  @override
  String get feedbackStepNovelTask =>
      'Use what you remember in this new situation.';

  @override
  String examPaceTarget(String time) {
    return 'Pace target $time';
  }

  @override
  String get examOverPaceTarget => 'Over pace target';

  @override
  String get examPaceHint =>
      'Suggested pace only — practice continues when time runs out';

  @override
  String examPaceSemantics(String status) {
    return '$status. Practice continues after the target time.';
  }

  @override
  String examUnfinishedAttempt(String age) {
    return 'You have an unfinished attempt from $age.';
  }

  @override
  String get ageAMomentAgo => 'a moment ago';

  @override
  String ageMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String ageHoursAgo(int count) {
    return '$count h ago';
  }
}
