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
}
