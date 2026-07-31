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
  String get reviewInASentence => 'In a sentence';

  @override
  String get reviewNeedAHint => 'Say it out loud · need a hint?';

  @override
  String reviewHintStartsWith(String start) {
    return 'Starts with “$start”';
  }

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

  @override
  String get copybookTitle => 'Daily copybook';

  @override
  String get copybookHeading => 'Write Czech by hand';

  @override
  String get copybookBody =>
      'Copy each useful word and its sentence on paper. Mark it when you can form every diacritic clearly.';

  @override
  String get copybookImageLabel =>
      'An open handwriting notebook overlooking Prague';

  @override
  String get copybookLoadError => 'Today’s words could not be loaded.';

  @override
  String get copybookTryAgain => 'Try again';

  @override
  String get copybookOfflineEmpty =>
      'Complete offline setup to make curriculum words available.';

  @override
  String get copybookComplete =>
      'Today’s page is complete. A new curriculum-based selection arrives tomorrow.';

  @override
  String get streakProtected => 'Streak protected';

  @override
  String streakDays(int count) {
    return '$count-day streak';
  }

  @override
  String get streakStartNew => 'Start a new streak';

  @override
  String streakProtectedBody(int count) {
    return 'Your freeze covered one missed day and kept your $count-day streak intact. Complete practice today to earn the next freeze.';
  }

  @override
  String get streakActiveBody =>
      'Your streak is active today. Complete meaningful practice each day to keep it going.';

  @override
  String get streakEndedBody =>
      'Your previous streak has ended. One completed learning activity starts a fresh one—no penalty, just a new day.';

  @override
  String get streakKeepLearning => 'Keep learning';

  @override
  String get streakBeginAgain => 'Begin again';

  @override
  String get pathA1Foundations => 'A1 Foundations';

  @override
  String get pathA1Everyday => 'A1 Everyday Czech';

  @override
  String get pathA2Grammar => 'A2 Grammar expansion';

  @override
  String get pathA2RealLife => 'A2 Real-life Czech';

  @override
  String pathExamConsolidation(String level) {
    return '$level Exam and consolidation';
  }

  @override
  String get pathFallbackPayoff => 'Build confidence for the next Czech task.';

  @override
  String get homeSmallWin => 'A small Czech win is waiting for you.';

  @override
  String get homeProgressToday => 'You have already made Czech progress today.';

  @override
  String get homeDailyGoal => 'Daily goal';

  @override
  String get homeGoalDone => 'Done for today. Anything else is a bonus.';

  @override
  String get homeGoalStart => 'One short lesson gets today moving.';

  @override
  String get homeContinueLearning => 'CONTINUE LEARNING';

  @override
  String get homeCompleteLesson => 'Complete one lesson';

  @override
  String get homeReviewFive => 'Review five cards';

  @override
  String get homeSpeakTwoMinutes => 'Speak for two minutes';

  @override
  String get homeSmallSteps => 'Today, in small steps';

  @override
  String get homeDone => 'Done';

  @override
  String get homeMethodOfDay => 'METHOD OF THE DAY';

  @override
  String get homeWriteBeforeType => 'Write it before you type it';

  @override
  String get homeCopybookCta => 'Open today’s copybook';

  @override
  String homeXpRemaining(int xp) {
    return '$xp XP to your daily rhythm.';
  }

  @override
  String get homeFreezeLeft => '1 freeze left';

  @override
  String homeTotalXp(int xp) {
    return '$xp total XP';
  }

  @override
  String get homeMethodBody =>
      'Handwriting slows Czech down just enough to make endings and diacritics visible.';

  @override
  String get homeUnlockedComplete => 'Every unlocked lesson is complete.';

  @override
  String get homeLoading => 'Loading…';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingEditableLater =>
      'All of this is editable later in Settings.';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingStartLearning => 'Start learning';

  @override
  String get onboardingSkip => 'Skip — set this up later';

  @override
  String get onboardingNameTitle => 'What should Lenka call you?';

  @override
  String get onboardingNameBody =>
      'Optional. Used to greet you in Czech, and it never leaves your device.';

  @override
  String get onboardingFirstName => 'FIRST NAME';

  @override
  String get onboardingLevelTitle => 'What’s your Czech level?';

  @override
  String get onboardingLevelBody =>
      'This sets your AI tutor’s difficulty. Lessons always start from Unit 1 so nothing is skipped.';

  @override
  String get onboardingBeginner => 'Complete beginner';

  @override
  String get onboardingBeginnerBody => 'I don’t know any Czech yet';

  @override
  String get onboardingA1 => 'Some Czech (A1)';

  @override
  String get onboardingA1Body => 'I know basic greetings and simple phrases';

  @override
  String get onboardingA2 => 'Intermediate (A2)';

  @override
  String get onboardingA2Body => 'I can have basic conversations';

  @override
  String get onboardingTakePlacement => 'Not sure? Take a placement test';

  @override
  String get onboardingVoiceTitle => 'Choose your teacher’s voice';

  @override
  String get onboardingVoiceBody =>
      'Every Czech word in the course is spoken by this voice. Tap to hear each one — you can change it any time from Settings.';

  @override
  String get onboardingFemaleVoice => 'Female voice';

  @override
  String get onboardingMaleVoice => 'Male voice';

  @override
  String get onboardingVoiceSample => 'Tap to hear a sample';

  @override
  String get onboardingNativeVoices => 'Both are studio-recorded native Czech.';

  @override
  String get onboardingGoalTitle => 'Set your daily goal';

  @override
  String get onboardingGoalBody => 'How much do you want to practice each day?';

  @override
  String get onboardingPlanReady => 'Your plan is ready';

  @override
  String get onboardingPlanBody =>
      'Unit 1 starts with the sounds of Czech — including the one only Czech has.';

  @override
  String get onboardingName => 'Name';

  @override
  String get onboardingLearner => 'Learner';

  @override
  String get onboardingStartingPoint => 'Starting point';

  @override
  String get onboardingTeacher => 'Teacher';

  @override
  String get onboardingFirstUnit => 'First unit';

  @override
  String get onboardingSoundsOfCzech => 'The sounds of Czech';

  @override
  String get scenarioCasual => 'Casual Chat';

  @override
  String get scenarioCasualBody =>
      'Everyday small talk — greetings, weather, how are you';

  @override
  String get scenarioRestaurant => 'At the Restaurant';

  @override
  String get scenarioRestaurantBody =>
      'Order food, ask about menu, pay the bill';

  @override
  String get scenarioDirections => 'Asking Directions';

  @override
  String get scenarioDirectionsBody =>
      'Ask for and give directions in the city';

  @override
  String get scenarioShopping => 'Shopping';

  @override
  String get scenarioShoppingBody => 'Buy items, ask prices, negotiate';

  @override
  String get scenarioDoctor => 'At the Doctor';

  @override
  String get scenarioDoctorBody => 'Describe symptoms, make an appointment';

  @override
  String get scenarioInterview => 'Job Interview';

  @override
  String get scenarioInterviewBody => 'Practice a basic job interview in Czech';

  @override
  String get scenarioCafeImage => 'A learner ordering at a Prague café';

  @override
  String get scenarioDirectionsImage =>
      'A learner asking for directions beside a Prague tram';

  @override
  String get scenarioShoppingImage =>
      'A learner shopping at a Czech neighborhood market';

  @override
  String get scenarioRestaurantImage =>
      'A learner ordering at a Czech restaurant';

  @override
  String get scenarioDoctorImage => 'A learner speaking with a doctor';

  @override
  String get scenarioInterviewImage =>
      'A learner taking part in a job interview';

  @override
  String get onboardingTagline => 'Czech that\nactually\nsticks.';

  @override
  String get onboardingWelcomeBody =>
      'Built for people living in Czechia — from your first word to the A1 exam.';

  @override
  String get onboardingHeroImage =>
      'A learner practising Czech with a tutor at a Prague café';

  @override
  String get onboardingOffline =>
      'Works offline — lessons and audio live on your phone';

  @override
  String get onboardingStartFree => 'Start learning free';

  @override
  String get onboardingHaveAccount => 'I already have an account';

  @override
  String get homeSpeakTitle => 'Say it out loud';

  @override
  String homeSpeakReviews(int count) {
    return 'Two minutes of Czech, then $count reviews.';
  }

  @override
  String get homeSpeakSound => 'Two minutes of ř — the sound worth practising.';

  @override
  String get chatVoiceRetry =>
      'I didn’t catch that. Try again somewhere quieter, or type your reply.';

  @override
  String get chatVoiceUnavailable =>
      'Voice input is unavailable. You can still type every reply.';

  @override
  String get chatDismiss => 'Dismiss';

  @override
  String get curriculumPathTitle => 'Your Czech path';

  @override
  String get curriculumAddingLessons =>
      'Lessons for this level are being added.';

  @override
  String get curriculumA1Complete =>
      'That’s the complete A1 track. Finish it and A2 opens.';

  @override
  String get curriculumA2Complete => 'That’s the complete A2 track.';

  @override
  String curriculumUnit(int number) {
    return 'UNIT $number';
  }

  @override
  String get curriculumInProgress => 'IN PROGRESS';

  @override
  String curriculumUnitOf(int number, int total, String level) {
    return 'Unit $number of $total · $level';
  }

  @override
  String curriculumUnlocksAfter(int number) {
    return 'Unlocks after unit $number';
  }

  @override
  String curriculumLessonCount(int done, int total) {
    return '$done / $total lessons';
  }

  @override
  String get curriculumStateDone => 'Done';

  @override
  String get curriculumStateReady => 'Ready now';

  @override
  String get curriculumStateLocked => 'Locked';

  @override
  String get curriculumNextUp => 'NEXT UP';

  @override
  String get curriculumMap => 'Map';

  @override
  String get curriculumList => 'List';

  @override
  String get lessonTypeLesson => 'Lesson';

  @override
  String get lessonTypePractice => 'Practice';

  @override
  String get lessonTypeApply => 'Apply';

  @override
  String get lessonTypeReview => 'Review';

  @override
  String get settingsDone => 'Done';

  @override
  String get statsTitle => 'Your Czech';

  @override
  String get statsSubtitle => 'Where you are, and what to work on next.';

  @override
  String get statsCourseActivityInfo =>
      'Course activity shows what you have practised. It is not a CEFR certification.';

  @override
  String get statsAboutNumber => 'About this number';

  @override
  String get statsAchievements => 'Achievements';

  @override
  String get statsAchievementsEmpty =>
      'Your first achievements are already within reach.';

  @override
  String get placementTitle => 'Find my starting point';

  @override
  String placementSuggestedUnit(int unit) {
    return 'Suggested starting unit: $unit';
  }

  @override
  String get placementProvisional =>
      'Provisional, not a CEFR result — it adjusts from your own performance.';

  @override
  String get placementChooseUnit => 'Choose a different starting unit';

  @override
  String get placementUseStart => 'Use this starting point';

  @override
  String get placementAnswerLabel => 'Your Czech answer';

  @override
  String get placementNext => 'Next';

  @override
  String get placementFinishLater => 'Finish later';

  @override
  String get reviewNew => 'New';

  @override
  String get reviewLearning => 'Learning';

  @override
  String get reviewReview => 'Review';

  @override
  String get reviewDue => 'Due';

  @override
  String get lessonMeetWords =>
      'Meet these words first. Tap each one to hear it, then practise using it.';

  @override
  String get teachingLookAndGuess =>
      'Look at the picture. What do you think this Czech word means?';

  @override
  String get teachingTapWordMeaning =>
      'Tap the Czech word to reveal its meaning';

  @override
  String get teachingMeaning => 'Meaning';

  @override
  String get teachingInSentence => 'Now hear it in a useful sentence';

  @override
  String get teachingTapSentenceTranslation =>
      'Tap the sentence to reveal the translation';

  @override
  String get teachingNextWord => 'Next word';

  @override
  String get teachingSeeExample => 'See it in a sentence';

  @override
  String get teachingStartExercises => 'Start practice exercises';

  @override
  String teachingWordProgress(int current, int total) {
    return 'Word $current of $total';
  }

  @override
  String get a11yTapToFlipCard => 'Tap to flip card';

  @override
  String get a11yPlayPronunciation => 'Play pronunciation';

  @override
  String a11yTapToHear(String text) {
    return 'Tap to hear: $text';
  }

  @override
  String get a11yTapToHearSentence => 'Tap to hear the sentence';

  @override
  String a11yInsertCharacter(String char) {
    return 'Insert character: $char';
  }

  @override
  String get a11yAddVocabToDeck => 'Add to review deck';

  @override
  String a11yScenarioCard(String title, String description) {
    return 'Scenario: $title. $description';
  }

  @override
  String a11yFeedback(String title) {
    return 'Feedback: $title';
  }

  @override
  String a11yContinueButton(String label) {
    return '$label button';
  }

  @override
  String get a11ySendMessage => 'Send message';
}
