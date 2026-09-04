import 'package:czechify/l10n/app_localizations.dart';
import 'package:czechify/l10n/app_localizations_cs.dart';
import 'package:czechify/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> reminderStrings(AppLocalizations l10n) => [
    l10n.reminderStepTitle,
    l10n.reminderStepBody,
    l10n.reminderStepToggle,
    l10n.reminderStepCatchUp,
    l10n.reminderStepChangeAnytime,
    l10n.reminderSettingsTitle,
    l10n.reminderSettingsBody,
    l10n.reminderTimeLabel,
    l10n.reminderEnabled,
    l10n.reminderDisabled,
    l10n.reminderCatchUpLabel,
    l10n.reminderCatchUpSuppressed,
    l10n.reminderPermissionBlocked,
    l10n.reminderOpenSettings,
    l10n.reminderSettingsEntryBanner,
  ];

  test('all reminder UI strings resolve in English and Czech', () {
    final english = reminderStrings(AppLocalizationsEn());
    final czech = reminderStrings(AppLocalizationsCs());

    expect(english, hasLength(15));
    expect(czech, hasLength(15));
    expect(english.every((value) => value.trim().isNotEmpty), isTrue);
    expect(czech.every((value) => value.trim().isNotEmpty), isTrue);
    expect(czech, isNot(english));
  });
}
