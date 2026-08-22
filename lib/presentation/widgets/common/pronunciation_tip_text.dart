import '../../../domain/entities/pronunciation_result.dart';
import '../../../l10n/app_localizations.dart';

/// Says a [PronunciationTip] in the learner's language.
///
/// The scorers deal in [PronunciationTipCode]; the words live here. Coaching
/// used to be built as English prose inside the engines, so a learner with the
/// app in Czech was told "Practice the ř sound" in English and no amount of
/// translation work could reach it.
extension PronunciationTipL10n on PronunciationTip {
  String localized(AppLocalizations l10n) => switch (code) {
    PronunciationTipCode.excellent => l10n.pronTipExcellent,
    PronunciationTipCode.unrecognisable => l10n.pronTipUnrecognisable,
    PronunciationTipCode.rolledRAsPlainR => l10n.pronTipRolledRAsPlainR,
    PronunciationTipCode.rolledR => l10n.pronTipRolledR,
    PronunciationTipCode.softeningE => l10n.pronTipSofteningE,
    PronunciationTipCode.vowelLength => l10n.pronTipVowelLength,
    PronunciationTipCode.vowelTooShort => l10n.pronTipVowelTooShort(
      sound ?? '',
    ),
    PronunciationTipCode.vowelTooLong => l10n.pronTipVowelTooLong(sound ?? ''),
    PronunciationTipCode.palatal => l10n.pronTipPalatal(sound ?? ''),
    PronunciationTipCode.soundDropped => l10n.pronTipSoundDropped(sound ?? ''),
    PronunciationTipCode.soundSubstituted => l10n.pronTipSoundSubstituted(
      sound ?? '',
      heard ?? '',
    ),
    PronunciationTipCode.repeatWord => l10n.pronTipRepeatWord(word ?? ''),
    PronunciationTipCode.checkSound => l10n.pronTipCheckSound(
      sound ?? '',
      word ?? '',
    ),
  };
}

/// The whole of a result's coaching as one block, one tip per line.
String localizedTips(Iterable<PronunciationTip> tips, AppLocalizations l10n) =>
    tips.map((tip) => tip.localized(l10n)).join('\n');
