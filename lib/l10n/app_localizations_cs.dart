// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'Czechify';

  @override
  String get check => 'Zkontrolovat';

  @override
  String get continueLabel => 'Pokračovat';

  @override
  String get tryAgain => 'Zkusit znovu';

  @override
  String get nextPhrase => 'Další fráze';

  @override
  String get skip => 'Přeskočit';

  @override
  String get retry => 'Znovu';

  @override
  String get cancel => 'Zrušit';

  @override
  String get save => 'Uložit';

  @override
  String get goHome => 'Zpět domů';

  @override
  String get startExam => 'Spustit test';

  @override
  String get resumeExam => 'Pokračovat v testu';

  @override
  String get discardAndStartOver => 'Zahodit a začít znovu';

  @override
  String get startRecording => 'Spustit nahrávání';

  @override
  String get stopRecording => 'Zastavit nahrávání';

  @override
  String get listen => 'Poslechnout';

  @override
  String get pronunciationLab => 'Trénink výslovnosti';

  @override
  String get sayThis => 'Řekněte:';

  @override
  String get tapMicrophoneHint => 'Klepněte na mikrofon a vyslovte frázi';

  @override
  String get analyzingPronunciation => 'Analyzuji výslovnost…';

  @override
  String get onDeviceRecognitionNote =>
      'Používá se rozpoznávání přímo v zařízení — výsledky mohou být méně přesné.';

  @override
  String get navHome => 'Domů';

  @override
  String get navLearn => 'Učit se';

  @override
  String get navReview => 'Opakování';

  @override
  String get navChat => 'Konverzace';

  @override
  String get navStats => 'Statistiky';

  @override
  String get settings => 'Nastavení';

  @override
  String get settingsYourName => 'Vaše jméno';

  @override
  String get settingsDailyGoal => 'Denní cíl';

  @override
  String settingsXpPerDay(int count) {
    return '$count XP denně';
  }

  @override
  String get settingsTheme => 'Vzhled';

  @override
  String get settingsThemeSystem => 'Podle systému';

  @override
  String get settingsThemeLight => 'Světlý';

  @override
  String get settingsThemeDark => 'Tmavý';

  @override
  String get settingsLanguage => 'Jazyk aplikace';

  @override
  String get settingsLanguageSystem => 'Podle systému';

  @override
  String get settingsSoundEffects => 'Zvukové efekty';

  @override
  String get settingsVibration => 'Vibrace';

  @override
  String get settingsHearts => 'Srdíčka v lekcích';

  @override
  String get settingsTestVoice => 'Vyzkoušet hlas';

  @override
  String get settingsVoiceMale => 'Mužský';

  @override
  String get settingsVoiceFemale => 'Ženský';

  @override
  String get settingsAccount => 'Účet';

  @override
  String get settingsPrivacyPolicy => 'Zásady ochrany osobních údajů';

  @override
  String get settingsAbout => 'O aplikaci Czechify';

  @override
  String get settingsVersion => 'Verze';

  @override
  String get settingsClearAudioCache => 'Vymazat mezipaměť zvuku';

  @override
  String get homeYourProgress => 'Váš pokrok';

  @override
  String get homeBrowseCurriculum => 'Procházet kurz';

  @override
  String get homeGrammarReference => 'Přehled gramatiky';

  @override
  String get homeMockExam => 'Zkušební test';

  @override
  String get homeAiChat => 'Konverzace s AI';

  @override
  String get homeSpeak => 'Mluvit';

  @override
  String get homeStartFirstLesson => 'Začněte první lekci';

  @override
  String get homeAllCaughtUp => 'Vše hotovo!';

  @override
  String homeDayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dní v řadě',
      few: '$count dny v řadě',
      one: '$count den v řadě',
    );
    return '$_temp0';
  }

  @override
  String homeHeartsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zbývá $count srdíček',
      few: 'Zbývají $count srdíčka',
      one: 'Zbývá $count srdíčko',
    );
    return '$_temp0';
  }

  @override
  String get reviewShowAnswer => 'Zobrazit odpověď';

  @override
  String get reviewTapToReveal => 'Klepnutím zobrazíte';

  @override
  String get reviewRatingAgain => 'Znovu';

  @override
  String get reviewRatingHard => 'Těžké';

  @override
  String get reviewRatingGood => 'Dobré';

  @override
  String get reviewRatingEasy => 'Snadné';

  @override
  String get reviewEndTitle => 'Ukončit opakování?';

  @override
  String get reviewEndBody =>
      'Váš pokrok bude uložen. Můžete pokračovat později.';

  @override
  String get reviewStay => 'Zůstat';

  @override
  String get reviewEnd => 'Ukončit';

  @override
  String get reviewNoCardsDue => 'Teď nejsou žádné karty k opakování.';

  @override
  String reviewCardOf(int current, int total) {
    return 'Karta $current z $total';
  }

  @override
  String get lessonLeaveTitle => 'Opustit lekci?';

  @override
  String get lessonLeaveBody =>
      'Vrátíte se do kurzu. Odpovědi, které jste už zadali, zůstanou uložené.';

  @override
  String get lessonLeave => 'Odejít';

  @override
  String lessonQuestionOf(int current, int total) {
    return 'Otázka $current z $total';
  }

  @override
  String get errorFailedToLoad => 'Tento obsah se nepodařilo načíst.';

  @override
  String get errorCheckConnection =>
      'Zkontrolujte připojení a zkuste to znovu.';

  @override
  String get a11yBack => 'Zpět';

  @override
  String get a11yClose => 'Zavřít';

  @override
  String get a11yPlayAudio => 'Přehrát zvuk';

  @override
  String get a11ySettings => 'Nastavení';

  @override
  String a11yHearts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zbývá $count srdíček',
      few: 'Zbývají $count srdíčka',
      one: 'Zbývá $count srdíčko',
    );
    return '$_temp0';
  }

  @override
  String a11yStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dní v řadě',
      few: '$count dny v řadě',
      one: '$count den v řadě',
    );
    return '$_temp0';
  }

  @override
  String a11yRateCard(String rating) {
    return 'Ohodnotit kartu: $rating';
  }

  @override
  String a11yLessonProgress(int current, int total) {
    return 'Postup lekcí: otázka $current z $total';
  }

  @override
  String get writingKeyPhrasesFound => 'Klíčové fráze nalezeny';

  @override
  String get writingKeyPhrasesMissing => 'Klíčové fráze nenalezeny';

  @override
  String get writingKeywordCheckNote =>
      'Pouze automatická kontrola klíčových slov — porovnává vaše slova s očekávanými frázemi a nehodnotí gramatiku, pravopis ani styl.';

  @override
  String get audioHearIt => 'Přehrát';

  @override
  String get audioSlow => 'Pomalu';

  @override
  String get audioSlower => 'Pomaleji';

  @override
  String get audioStop => 'Zastavit';

  @override
  String get audioPlayAgain => 'Přehrát znovu';

  @override
  String get audioPlayIt => 'Přehrát';

  @override
  String get audioHearTheWord => 'Poslechnout slovo';

  @override
  String get czechLetters => 'České znaky';

  @override
  String get feedbackCorrect => 'Správně!';

  @override
  String get feedbackNotQuite => 'Ještě ne';

  @override
  String get feedbackAnswerShown => 'Zobrazená odpověď';

  @override
  String get feedbackSkipped => 'Přeskočeno — bez bodů a bez ztráty srdíčka';

  @override
  String get feedbackViewGrammarRule => 'Zobrazit gramatické pravidlo';

  @override
  String get answerCorrectLabel => 'Správná odpověď';

  @override
  String get lessonIntroduction => 'Úvod';

  @override
  String get lessonMissedQuestions => 'Chybné otázky';

  @override
  String lessonInARow(int count) {
    return '$count v řadě';
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
  String get lessonNewWords => 'Nová slova';

  @override
  String get lessonStartPractice => 'Začít procvičovat';

  @override
  String get lessonGotItStartPractising => 'Rozumím — jdeme procvičovat';

  @override
  String get lessonSaving => 'Ukládám…';

  @override
  String get lessonNextQuestion => 'Další otázka';

  @override
  String get lessonReviewMistakes => 'Projít chyby';

  @override
  String get lessonFinish => 'Dokončit lekci';

  @override
  String lessonFinishUnit(int number) {
    return 'Dokončit kapitolu $number';
  }

  @override
  String get lessonContinueLearning => 'Pokračovat v učení';

  @override
  String get lessonPracticeAgain => 'Procvičit znovu';

  @override
  String get lessonLockedTitle => 'Ještě není otevřená';

  @override
  String get lessonLockedBody => 'Dokončete předchozí lekce a tato se otevře.';

  @override
  String get lessonBackToCurriculum => 'Zpět do kurzu';

  @override
  String get lessonNoExercises => 'Pro tuto lekci nejsou žádná cvičení.';

  @override
  String get lessonOutOfHeartsTitle => 'Došla srdíčka';

  @override
  String get lessonOutOfHeartsBody =>
      'Srdíčka se sama obnovují — jedno za 30 minut. Opakování pěti a více karet vám jedno vrátí hned.';

  @override
  String get lessonReviewToEarnHeart => 'Opakováním získat srdíčko';

  @override
  String get lessonBadgeExam => 'Test';

  @override
  String get statAccuracy => 'Úspěšnost';

  @override
  String get statXpEarned => 'Získané XP';

  @override
  String get statCorrect => 'Správně';

  @override
  String get statMissed => 'Chyby';

  @override
  String get statCards => 'Karty';

  @override
  String get statRecalled => 'Vybaveno';

  @override
  String get captionAccuracy => 'úspěšnost';

  @override
  String get captionRecall => 'vybavení';

  @override
  String get captionMatch => 'shoda';

  @override
  String get exerciseCheckAnswers => 'Zkontrolovat odpovědi';

  @override
  String get exerciseCheckAll => 'Zkontrolovat vše';

  @override
  String exerciseQuestionNumber(int number) {
    return 'Otázka $number';
  }

  @override
  String get exerciseAllCorrect => 'Vše správně';

  @override
  String get exerciseSomeAnswersWrong =>
      'Některé odpovědi jsou chybné — projděte je níže.';

  @override
  String get exerciseSomePairsWrong => 'Některé páry jsou chybné';

  @override
  String exerciseCorrectOfTotal(int correct, int total) {
    return '$correct z $total správně';
  }

  @override
  String exerciseMatchedOfTotal(int matched, int total) {
    return 'Spárováno $matched z $total';
  }

  @override
  String get exerciseTapCzechThenEnglish =>
      'Klepněte na české slovo a pak na jeho anglický překlad.';

  @override
  String get exerciseTapWordsInOrder =>
      'Klepejte na slova níže ve správném pořadí';

  @override
  String get exerciseTypeWhatYouHeard => 'Napište, co jste slyšeli';

  @override
  String get exerciseRevealTranscript => 'Zobrazit přepis';

  @override
  String get exerciseGistFirstNote =>
      'Nejdřív poslouchejte kvůli smyslu. Přehrání znovu nebo přepis použijte jen když potřebujete pomoct.';

  @override
  String get exerciseNoQuestions => 'Toto cvičení nemá nastavené žádné otázky.';

  @override
  String get exerciseSayInCzech => 'Řekněte to česky';

  @override
  String get exerciseSayInEnglish => 'Řekněte to anglicky';

  @override
  String get exerciseTypeInCzech => 'Pište česky';

  @override
  String get exerciseTypeInEnglish => 'Pište anglicky';

  @override
  String get labelEnglish => 'Anglicky';

  @override
  String get labelCzech => 'Česky';

  @override
  String get exerciseChooseCorrectForm => 'Vyberte správný tvar';

  @override
  String get exerciseTypeCorrectSentence => 'Napište správnou větu';

  @override
  String get exerciseCorrectedSentence => 'Opravená věta';

  @override
  String get exerciseShowHint => 'Zobrazit nápovědu';

  @override
  String get exerciseErrorInHighlighted =>
      'Chyba je v jednom ze zvýrazněných slov výše.';

  @override
  String exerciseDeclineWord(String word) {
    return 'Skloňujte $word';
  }

  @override
  String get exerciseYourAnswer => 'Vaše odpověď';

  @override
  String get teachingKicker => 'Nová látka';

  @override
  String get teachingIntro => 'Úvod';

  @override
  String get teachingLetterByLetter => 'Písmeno po písmenu';

  @override
  String get teachingTapAnyLetter => 'Klepnutím na písmeno si ho poslechnete';

  @override
  String get teachingTapLineToHear => 'Klepnutím na řádek si ho poslechnete';

  @override
  String get teachingPlayWholeSet => 'Přehrát celou sadu';

  @override
  String writingWriteAtLeast(int count) {
    return 'Napište alespoň $count slov.';
  }

  @override
  String get writingHint => 'Napište odpověď česky…';

  @override
  String get writingShowVocabSupport => 'Zobrazit pomocná slova';

  @override
  String get writingTryUsing => 'Zkuste použít';

  @override
  String get writingReviseNote =>
      'Revize: zkontrolujte komunikační cíl, tvary sloves, koncovky pádů, slovosled a styl. Vylepšete sdělení, nejen jeho délku.';

  @override
  String get writingReviewDraft => 'Projít koncept';

  @override
  String get writingSubmitRevision => 'Odeslat opravu';

  @override
  String get writingCycleComplete => 'Cvičení psaní dokončeno';

  @override
  String get writingReferenceAnswer => 'Vzorová odpověď';

  @override
  String writingWordCountMin(int count, int min) {
    return '$count slov · minimum $min';
  }

  @override
  String writingWordCount(int count) {
    return '$count slov';
  }

  @override
  String get speakingTryToSay => 'Zkuste říct';

  @override
  String get speakingYouSaid => 'Řekli jste';

  @override
  String get speakingTapToSpeak => 'Klepnutím začnete mluvit';

  @override
  String get speakingTapToRerecord => 'Klepnutím nahrajete znovu';

  @override
  String get speakingRecordingTapToStop => 'Nahrávám — klepnutím zastavíte';

  @override
  String get pronTapToRecord => 'Klepnutím nahrajete';

  @override
  String get pronRecordedTapAgain => 'Nahráno — klepnutím zkusíte znovu';

  @override
  String get pronListeningTapToStop => 'Poslouchám — klepnutím zastavíte';

  @override
  String get pronAnalysing => 'Analyzuji…';

  @override
  String get pronMicNotWorkingSkip => 'Nefunguje mikrofon? Přeskočit';

  @override
  String get pronCantRecordSkip => 'Teď nemůžete nahrávat? Přeskočit';

  @override
  String get pronSkippedNote =>
      'Přeskočeno — procvičujte to dál nahlas pomocí tlačítka pro přehrání.';

  @override
  String get reviewSpacedRepetition => 'Rozložené opakování';

  @override
  String reviewCardsLeft(int count) {
    return 'Zbývá $count';
  }

  @override
  String get reviewRetrieveTheCzech => 'Vybavte si české slovo';

  @override
  String get reviewSayItThenTypeIt => 'Řekněte to a pak napište';

  @override
  String get reviewOvertAttemptNote =>
      'Zkuste odpovědět dřív, než si odpověď zobrazíte.';

  @override
  String get reviewWhatDoesItMean => 'Co to znamená?';

  @override
  String get reviewInASentence => 'Ve větě';

  @override
  String get reviewNeedAHint => 'Řekni to nahlas · potřebuješ nápovědu?';

  @override
  String reviewHintStartsWith(String start) {
    return 'Začíná na „$start“';
  }

  @override
  String get reviewMeans => 'Znamená';

  @override
  String get reviewHowDoYouSayIt => 'Jak se to řekne česky?';

  @override
  String get reviewCompleteCzechSentence => 'Doplňte českou větu.';

  @override
  String get reviewDirectionEnToCz => 'EN → CZ';

  @override
  String get reviewDirectionListening => 'Poslech';

  @override
  String get reviewHowWellRecalled =>
      'Jak dobře jste si to vybavili? · určuje, kdy se karta vrátí';

  @override
  String get reviewAllCaughtUp => 'Vše hotovo';

  @override
  String get reviewCheckAgain => 'Zkontrolovat znovu';

  @override
  String get reviewNoCardsAvailable => 'Žádné karty nejsou k dispozici.';

  @override
  String get reviewDeckCleared => 'Balíček hotov';

  @override
  String reviewCardsReviewed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dobrá práce — $count zopakovaných karet',
      few: 'Dobrá práce — $count zopakované karty',
      one: 'Dobrá práce — $count zopakovaná karta',
    );
    return '$_temp0';
  }

  @override
  String get reviewHeartEarned => 'Získáno +1 srdíčko';

  @override
  String get reviewHowItWent => 'Jak to šlo';

  @override
  String get reviewReschedulingNote =>
      'Karty se plánují metodou rozloženého opakování — každá se vrátí přesně ve chvíli, kdy byste ji začali zapomínat.';

  @override
  String get reviewGoAgain => 'Ještě jednou';

  @override
  String get reviewDone => 'Hotovo';

  @override
  String get reviewIntervalSoon => 'Brzy';

  @override
  String get chatTitle => 'Konverzace s AI';

  @override
  String get chatSubtitle =>
      'Reálné situace, na které tento týden v Česku narazíte. Lektor se přizpůsobí vaší úrovni.';

  @override
  String get chatUnfinished => 'Nedokončené';

  @override
  String get chatPickASituation => 'Vyberte situaci';

  @override
  String chatRoomCount(int count) {
    return '$count situací';
  }

  @override
  String chatTurnsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replik',
      few: '$count repliky',
      one: '$count replika',
    );
    return '$_temp0';
  }

  @override
  String get chatBackToScenarios => 'Zpět na situace';

  @override
  String get chatTutorIsTyping => 'Lektor píše';

  @override
  String get chatSpeakYourReply => 'Řekněte odpověď';

  @override
  String get chatComposerHint => 'Napiš česky…';

  @override
  String get chatListeningHint => 'Poslouchám… mluvte česky';

  @override
  String get chatDeleteConversation => 'Smazat konverzaci';

  @override
  String get exerciseAllAnsweredCorrectly => 'Všechny otázky správně.';

  @override
  String get exerciseNoQuestionsAvailable =>
      'Pro toto cvičení nejsou k dispozici žádné otázky.';

  @override
  String exerciseYouGotCorrect(int correct, int total) {
    return 'Máte $correct z $total správně.';
  }

  @override
  String get pronFeedbackGood => 'Dobrá výslovnost.';

  @override
  String get pronFeedbackRetry =>
      'Zkuste to znovu — soustřeďte se na zvýrazněné zvuky.';

  @override
  String get speakingFeedbackGood => 'Dobře — řekli jste to podstatné.';

  @override
  String speakingFeedbackRetry(String phrases) {
    return 'Zkuste to znovu. Očekávané fráze: $phrases';
  }

  @override
  String get recordingFailed =>
      'Nahrávání se nepovedlo. Zkuste to prosím znovu.';

  @override
  String writingWroteWords(int count) {
    return 'Napsali jste $count slov.';
  }

  @override
  String writingMeetsMinimum(int min) {
    return 'Splňuje minimum $min slov.';
  }

  @override
  String writingNeedsMinimum(int min) {
    return 'Potřebuje alespoň $min slov.';
  }

  @override
  String get writingGoodKeywordCoverage => 'Dobré pokrytí klíčových slov.';

  @override
  String get writingKeyPhrasesNotDetected => 'Klíčové fráze nenalezeny.';

  @override
  String get writingUnscoredNote =>
      'Dokončeno jako nebodované cvičení psaní; žádné automatické hodnocení úrovně se nedělá.';

  @override
  String get writingRevisedDraft => 'Upravili jste první koncept.';

  @override
  String translationAccentHint(String answer) {
    return 'Skoro — pozor na diakritiku. Správně se to píše „$answer\".';
  }

  @override
  String get dictationAccentHint =>
      'Skoro — pozor na diakritiku. Jinak jste to měli správně.';

  @override
  String get examResultsTitle => 'Výsledky testu';

  @override
  String get examPracticeComplete => 'Cvičení dokončeno';

  @override
  String get examPracticeTargetMet => 'Cvičný cíl splněn';

  @override
  String get examThresholdMet => 'Cvičná hranice splněna';

  @override
  String get examThresholdNotMet => 'Cvičná hranice nesplněna';

  @override
  String get examPartlyUnscored =>
      'Cvičení dokončeno — některé úlohy nebyly bodovány';

  @override
  String examCourseTrack(String level) {
    return 'Úroveň kurzu $level';
  }

  @override
  String get examAccuracyCaveat =>
      'Jde pouze o úspěšnost ve cvičeních. Není to oficiální výsledek zkoušky ani certifikace CEFR.';

  @override
  String examMockTitle(String level) {
    return 'Zkušební test — $level';
  }

  @override
  String examPracticeExamTitle(String product, String level) {
    return 'Zkušební test $product $level';
  }

  @override
  String get examFourSections =>
      'Čtyři části na čas. Časomíra běží pro každou část zvlášť a odpovídat můžete postupně.';

  @override
  String get examInformalNote =>
      'Jde o neformální cvičení, ne o oficiální výsledek zkoušky.';

  @override
  String get examSectionReading => 'Čtení';

  @override
  String get examSectionReadingSub => 'Otázky k porozumění';

  @override
  String get examSectionListening => 'Poslech';

  @override
  String get examSectionListeningSub => 'Nahrávka a pak otázky';

  @override
  String get examSectionWriting => 'Psaní';

  @override
  String get examSectionWritingSub => 'Zpětná vazba, když je dostupná';

  @override
  String get examSectionSpeaking => 'Mluvení';

  @override
  String get examSectionSpeakingSub => 'Podklady z přepisu nahrávky';

  @override
  String examTotalTime(int minutes) {
    return 'Celkový čas: $minutes minut';
  }

  @override
  String get examDone => 'Hotovo';

  @override
  String get examPlayAudio => 'Přehrát nahrávku';

  @override
  String get feedbackStepSignal => 'Něco tu nesedí. Zkuste si všimnout čeho.';

  @override
  String get feedbackStepSelfRepair =>
      'Zkuste to znovu, než si vyžádáte další pomoc.';

  @override
  String get feedbackStepCue =>
      'Použijte vysvětlení jako nápovědu a opravte odpověď.';

  @override
  String get feedbackStepExplanation =>
      'Prostudujte odpověď a pak si ji vybavte ještě jednou.';

  @override
  String get feedbackStepImmediateVariant =>
      'Teď použijte stejnou myšlenku na variantu.';

  @override
  String get feedbackStepSpacedAnalogue => 'Podobná úloha se vrátí později.';

  @override
  String get feedbackStepNovelTask =>
      'Použijte, co si pamatujete, v této nové situaci.';

  @override
  String examPaceTarget(String time) {
    return 'Cílové tempo $time';
  }

  @override
  String get examOverPaceTarget => 'Nad cílovým tempem';

  @override
  String get examPaceHint =>
      'Jen doporučené tempo — cvičení pokračuje, i když čas vyprší';

  @override
  String examPaceSemantics(String status) {
    return '$status. Cvičení pokračuje i po cílovém čase.';
  }

  @override
  String examUnfinishedAttempt(String age) {
    return 'Máte nedokončený pokus z $age.';
  }

  @override
  String get ageAMomentAgo => 'před chvílí';

  @override
  String ageMinutesAgo(int count) {
    return 'před $count min';
  }

  @override
  String ageHoursAgo(int count) {
    return 'před $count h';
  }

  @override
  String get copybookTitle => 'Denní písanka';

  @override
  String get copybookHeading => 'Pište česky rukou';

  @override
  String get copybookBody =>
      'Opište si každé užitečné slovo i větu na papír. Označte je, až zvládnete zřetelně napsat všechnu diakritiku.';

  @override
  String get copybookImageLabel =>
      'Otevřený sešit na psaní s výhledem na Prahu';

  @override
  String get copybookLoadError => 'Dnešní slova se nepodařilo načíst.';

  @override
  String get copybookTryAgain => 'Zkusit znovu';

  @override
  String get copybookOfflineEmpty =>
      'Dokončete offline nastavení, aby byla slova z kurzu dostupná.';

  @override
  String get copybookComplete =>
      'Dnešní stránka je hotová. Zítra dostanete nový výběr z kurzu.';

  @override
  String get streakProtected => 'Série je chráněná';

  @override
  String streakDays(int count) {
    return 'Série: $count dní';
  }

  @override
  String get streakStartNew => 'Začněte novou sérii';

  @override
  String streakProtectedBody(int count) {
    return 'Zmrazení pokrylo jeden vynechaný den a zachovalo vaši sérii $count dní. Dnešním procvičováním získáte další zmrazení.';
  }

  @override
  String get streakActiveBody =>
      'Dnešní série je aktivní. Udržujte ji každý den smysluplným procvičováním.';

  @override
  String get streakEndedBody =>
      'Předchozí série skončila. Jedna dokončená výuková aktivita zahájí novou — bez trestu, jen nový den.';

  @override
  String get streakKeepLearning => 'Pokračovat v učení';

  @override
  String get streakBeginAgain => 'Začít znovu';

  @override
  String get pathA1Foundations => 'Základy A1';

  @override
  String get pathA1Everyday => 'Každodenní čeština A1';

  @override
  String get pathA2Grammar => 'Rozšíření gramatiky A2';

  @override
  String get pathA2RealLife => 'Čeština pro skutečný život A2';

  @override
  String pathExamConsolidation(String level) {
    return 'Zkouška $level a upevnění znalostí';
  }

  @override
  String get pathFallbackPayoff => 'Získejte jistotu pro další úkol v češtině.';

  @override
  String get homeSmallWin => 'Čeká na vás malé české vítězství.';

  @override
  String get homeProgressToday => 'Dnes už jste v češtině udělali pokrok.';

  @override
  String get homeDailyGoal => 'Denní cíl';

  @override
  String get homeGoalDone => 'Pro dnešek hotovo. Všechno další je bonus.';

  @override
  String get homeGoalStart => 'Jedna krátká lekce rozjede dnešní učení.';

  @override
  String get homeContinueLearning => 'POKRAČOVAT V UČENÍ';

  @override
  String get homeCompleteLesson => 'Dokončit jednu lekci';

  @override
  String get homeReviewFive => 'Zopakovat pět kartiček';

  @override
  String get homeSpeakTwoMinutes => 'Dvě minuty mluvení';

  @override
  String get homeSmallSteps => 'Dnes po malých krocích';

  @override
  String get homeDone => 'Hotovo';

  @override
  String get homeMethodOfDay => 'DNEŠNÍ METODA';

  @override
  String get homeWriteBeforeType => 'Nejdřív napište rukou, pak na klávesnici';

  @override
  String get homeCopybookCta => 'Otevřít dnešní písanku';

  @override
  String homeXpRemaining(int xp) {
    return 'Do denního rytmu zbývá $xp XP.';
  }

  @override
  String get homeFreezeLeft => 'Zbývá 1 zmrazení';

  @override
  String homeTotalXp(int xp) {
    return 'Celkem $xp XP';
  }

  @override
  String get homeMethodBody =>
      'Psaní rukou zpomalí češtinu právě natolik, aby byly koncovky a diakritika dobře vidět.';

  @override
  String get homeUnlockedComplete => 'Všechny odemčené lekce jsou dokončené.';

  @override
  String get homeLoading => 'Načítání…';

  @override
  String get onboardingBack => 'Zpět';

  @override
  String get onboardingEditableLater =>
      'Všechno můžete později upravit v Nastavení.';

  @override
  String get onboardingContinue => 'Pokračovat';

  @override
  String get onboardingStartLearning => 'Začít se učit';

  @override
  String get onboardingSkip => 'Přeskočit — nastavit později';

  @override
  String get onboardingNameTitle => 'Jak vám má Lenka říkat?';

  @override
  String get onboardingNameBody =>
      'Nepovinné. Použije se pro český pozdrav a nikdy neopustí vaše zařízení.';

  @override
  String get onboardingFirstName => 'KŘESTNÍ JMÉNO';

  @override
  String get onboardingLevelTitle => 'Jaká je vaše úroveň češtiny?';

  @override
  String get onboardingLevelBody =>
      'Podle toho se nastaví obtížnost AI lektora. Lekce vždy začínají 1. jednotkou, aby vám nic neuteklo.';

  @override
  String get onboardingBeginner => 'Úplný začátečník';

  @override
  String get onboardingBeginnerBody => 'Česky zatím vůbec neumím';

  @override
  String get onboardingA1 => 'Trochu češtiny (A1)';

  @override
  String get onboardingA1Body => 'Znám základní pozdravy a jednoduché fráze';

  @override
  String get onboardingA2 => 'Mírně pokročilý (A2)';

  @override
  String get onboardingA2Body => 'Zvládnu jednoduchou konverzaci';

  @override
  String get onboardingTakePlacement =>
      'Nevíte si jistí? absolvujte test úrovně';

  @override
  String get onboardingVoiceTitle => 'Vyberte si hlas lektora';

  @override
  String get onboardingVoiceBody =>
      'Tímto hlasem zní každé české slovo v kurzu. Klepnutím si ho poslechnete a kdykoli ho můžete změnit v Nastavení.';

  @override
  String get onboardingFemaleVoice => 'Ženský hlas';

  @override
  String get onboardingMaleVoice => 'Mužský hlas';

  @override
  String get onboardingVoiceSample => 'Klepnutím přehrajete ukázku';

  @override
  String get onboardingNativeVoices =>
      'Oba hlasy jsou studiové nahrávky rodilých mluvčích.';

  @override
  String get onboardingGoalTitle => 'Nastavte si denní cíl';

  @override
  String get onboardingGoalBody => 'Kolik chcete každý den procvičovat?';

  @override
  String get onboardingPlanReady => 'Váš plán je připravený';

  @override
  String get onboardingPlanBody =>
      '1. jednotka začíná zvuky češtiny — včetně toho, který má jen čeština.';

  @override
  String get onboardingName => 'Jméno';

  @override
  String get onboardingLearner => 'Student';

  @override
  String get onboardingStartingPoint => 'Výchozí úroveň';

  @override
  String get onboardingTeacher => 'Lektor';

  @override
  String get onboardingFirstUnit => 'První jednotka';

  @override
  String get onboardingSoundsOfCzech => 'Zvuky češtiny';

  @override
  String get scenarioCasual => 'Neformální rozhovor';

  @override
  String get scenarioCasualBody =>
      'Běžná konverzace — pozdravy, počasí a jak se máte';

  @override
  String get scenarioRestaurant => 'V restauraci';

  @override
  String get scenarioRestaurantBody =>
      'Objednejte si jídlo, zeptejte se na menu a zaplaťte';

  @override
  String get scenarioDirections => 'Ptáme se na cestu';

  @override
  String get scenarioDirectionsBody =>
      'Ptejte se na cestu po městě a popisujte ji';

  @override
  String get scenarioShopping => 'Nakupování';

  @override
  String get scenarioShoppingBody =>
      'Nakupujte, ptejte se na ceny a domlouvejte se';

  @override
  String get scenarioDoctor => 'U lékaře';

  @override
  String get scenarioDoctorBody => 'Popište příznaky a objednejte se';

  @override
  String get scenarioInterview => 'Pracovní pohovor';

  @override
  String get scenarioInterviewBody =>
      'Procvičte si jednoduchý pracovní pohovor v češtině';

  @override
  String get scenarioCafeImage => 'Student si objednává v pražské kavárně';

  @override
  String get scenarioDirectionsImage =>
      'Student se ptá na cestu u pražské tramvaje';

  @override
  String get scenarioShoppingImage => 'Student nakupuje na českém trhu';

  @override
  String get scenarioRestaurantImage =>
      'Student si objednává v české restauraci';

  @override
  String get scenarioDoctorImage => 'Student mluví s lékařem';

  @override
  String get scenarioInterviewImage => 'Student se účastní pracovního pohovoru';

  @override
  String get onboardingTagline => 'Čeština,\nkterá se\nudrží.';

  @override
  String get onboardingWelcomeBody =>
      'Pro lidi žijící v Česku — od prvního slova až ke zkoušce A1.';

  @override
  String get onboardingHeroImage =>
      'Student procvičuje češtinu s lektorkou v pražské kavárně';

  @override
  String get onboardingOffline =>
      'Funguje offline — lekce i nahrávky máte v telefonu';

  @override
  String get onboardingStartFree => 'Začít se učit zdarma';

  @override
  String get onboardingHaveAccount => 'Už mám účet';

  @override
  String get homeSpeakTitle => 'Řekněte to nahlas';

  @override
  String homeSpeakReviews(int count) {
    return 'Dvě minuty češtiny a potom $count opakování.';
  }

  @override
  String get homeSpeakSound =>
      'Dvě minuty s ř — hláskou, kterou stojí za to procvičit.';

  @override
  String get chatVoiceRetry =>
      'Nerozuměl jsem. Zkuste to znovu v tišším prostředí nebo odpověď napište.';

  @override
  String get chatVoiceUnavailable =>
      'Hlasový vstup není dostupný. Každou odpověď můžete napsat.';

  @override
  String get chatDismiss => 'Zavřít';

  @override
  String get curriculumPathTitle => 'Vaše cesta češtinou';

  @override
  String get curriculumAddingLessons =>
      'Lekce pro tuto úroveň právě doplňujeme.';

  @override
  String get curriculumA1Complete =>
      'To je celá cesta A1. Dokončete ji a otevře se A2.';

  @override
  String get curriculumA2Complete => 'To je celá cesta A2.';

  @override
  String curriculumUnit(int number) {
    return 'JEDNOTKA $number';
  }

  @override
  String get curriculumInProgress => 'PROBÍHÁ';

  @override
  String curriculumUnitOf(int number, int total, String level) {
    return 'Jednotka $number z $total · $level';
  }

  @override
  String curriculumUnlocksAfter(int number) {
    return 'Odemkne se po jednotce $number';
  }

  @override
  String curriculumLessonCount(int done, int total) {
    return '$done / $total lekcí';
  }

  @override
  String get curriculumStateDone => 'Hotovo';

  @override
  String get curriculumStateReady => 'Připraveno';

  @override
  String get curriculumStateLocked => 'Zamčeno';

  @override
  String get curriculumNextUp => 'NA ŘADĚ';

  @override
  String get curriculumMap => 'Mapa';

  @override
  String get curriculumList => 'Seznam';

  @override
  String get lessonTypeLesson => 'Lekce';

  @override
  String get lessonTypePractice => 'Procvičení';

  @override
  String get lessonTypeApply => 'Použití';

  @override
  String get lessonTypeReview => 'Opakování';

  @override
  String get settingsDone => 'Hotovo';

  @override
  String get statsTitle => 'Vaše čeština';

  @override
  String get statsSubtitle => 'Kde právě jste a na čem pracovat dál.';

  @override
  String get statsCourseActivityInfo =>
      'Aktivita v kurzu ukazuje, co jste procvičovali. Nejde o certifikaci CEFR.';

  @override
  String get statsAboutNumber => 'O tomto údaji';

  @override
  String get statsAchievements => 'Úspěchy';

  @override
  String get statsAchievementsEmpty => 'První úspěchy už máte na dosah.';

  @override
  String get placementTitle => 'Najít výchozí úroveň';

  @override
  String placementSuggestedUnit(int unit) {
    return 'Doporučená výchozí jednotka: $unit';
  }

  @override
  String get placementProvisional =>
      'Jde o předběžné doporučení, ne výsledek CEFR — upravuje se podle vašeho výkonu.';

  @override
  String get placementChooseUnit => 'Vybrat jinou výchozí jednotku';

  @override
  String get placementUseStart => 'Použít tuto výchozí úroveň';

  @override
  String get placementAnswerLabel => 'Vaše odpověď v češtině';

  @override
  String get placementNext => 'Další';

  @override
  String get placementFinishLater => 'Dokončit později';

  @override
  String get reviewNew => 'Nové';

  @override
  String get reviewLearning => 'Učím se';

  @override
  String get reviewReview => 'Opakování';

  @override
  String get reviewDue => 'K opakování';

  @override
  String get lessonMeetWords =>
      'Nejdřív se seznamte s těmito slovy. Klepnutím si je poslechněte a pak je procvičte.';

  @override
  String get teachingLookAndGuess =>
      'Podívejte se na obrázek. Co podle vás toto české slovo znamená?';

  @override
  String get teachingTapWordMeaning =>
      'Klepnutím na české slovo zobrazíte význam';

  @override
  String get teachingMeaning => 'Význam';

  @override
  String get teachingInSentence => 'Teď si slovo poslechněte v užitečné větě';

  @override
  String get teachingTapSentenceTranslation =>
      'Klepnutím na větu zobrazíte překlad';

  @override
  String get teachingNextWord => 'Další slovo';

  @override
  String get teachingSeeExample => 'Ukázat ve větě';

  @override
  String get teachingStartExercises => 'Začít procvičování';

  @override
  String teachingWordProgress(int current, int total) {
    return 'Slovo $current z $total';
  }

  @override
  String get a11yTapToFlipCard => 'Klepnutím otočíte kartu';

  @override
  String get a11yPlayPronunciation => 'Přehrát výslovnost';

  @override
  String a11yTapToHear(String text) {
    return 'Klepnutím poslechnete: $text';
  }

  @override
  String get a11yTapToHearSentence => 'Klepnutím poslechnete větu';

  @override
  String a11yInsertCharacter(String char) {
    return 'Vložit znak: $char';
  }

  @override
  String get a11yAddVocabToDeck => 'Přidat do balíčku na opakování';

  @override
  String a11yScenarioCard(String title, String description) {
    return 'Scénář: $title. $description';
  }

  @override
  String a11yFeedback(String title) {
    return 'Zpětná vazba: $title';
  }

  @override
  String a11yContinueButton(String label) {
    return 'Tlačítko $label';
  }

  @override
  String get a11ySendMessage => 'Odeslat zprávu';

  @override
  String get reminderStepTitle => 'Kdy bychom ti měli připomínat?';

  @override
  String get reminderStepBody =>
      'Vyber si čas a pošleme ti jemnou připomínku zhruba v tomto čase, abys procvičil/a češtinu.';

  @override
  String get reminderStepToggle => 'Ano, připomínej mi denně';

  @override
  String get reminderStepCatchUp =>
      'Plus jemná večerní připomínka v 21:30, pokud jsi ještě nestudoval/a.';

  @override
  String get reminderStepChangeAnytime =>
      'Toto můžeš kdykoli změnit v Nastavení.';

  @override
  String get reminderSettingsTitle => 'Připomínky ke studiu';

  @override
  String get reminderSettingsBody =>
      'Budeme ti připomínat zhruba ve zvoleném čase. Plus jemná večerní připomínka, pokud jsi ještě nestudoval/a.';

  @override
  String get reminderTimeLabel => 'Čas připomínky';

  @override
  String get reminderEnabled => 'Připomínky zapnuty';

  @override
  String get reminderDisabled => 'Připomínky vypnuty';

  @override
  String get reminderCatchUpLabel => 'Večerní připomínka';

  @override
  String get reminderCatchUpSuppressed =>
      'Večerní připomínka je vypnutá, protože tvůj čas připomínky je blízko 21:30.';

  @override
  String get reminderPermissionBlocked =>
      'Oznámení jsou blokována. Otevři Nastavení → Oznámení → Czechify pro povolení.';

  @override
  String get reminderOpenSettings => 'Otevřít nastavení';

  @override
  String get reminderSettingsEntryBanner =>
      'Dostávej denní připomínky a udržuj svou sérii.';
}
