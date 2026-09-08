import 'package:czechify/core/notifications/notification_messages.dart';
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

  test('every notification variant is translated, in both halves', () {
    // The reminder queue holds text, not keys: a variant is picked and its
    // words handed to the platform when the reminder is *scheduled*, up to
    // thirty days before it appears. An untranslated variant is therefore not
    // a string that renders in English — it is one that was already written
    // into the notification tray in English, and nothing on screen can
    // correct it afterwards.
    for (final l10n in [AppLocalizationsEn(), AppLocalizationsCs()]) {
      final variants = [
        ...NotificationMessages.dailyVariants(l10n),
        ...NotificationMessages.eveningVariants(l10n),
      ];
      expect(variants, hasLength(13));
      for (final variant in variants) {
        expect(variant.title.trim(), isNotEmpty);
        expect(variant.body.trim(), isNotEmpty);
      }
    }

    // Same catalogue, different words — a locale that silently fell back to
    // the template would pass every check above.
    final english = NotificationMessages.dailyVariants(AppLocalizationsEn());
    final czech = NotificationMessages.dailyVariants(AppLocalizationsCs());
    for (var i = 0; i < english.length; i++) {
      expect(
        czech[i].body,
        isNot(english[i].body),
        reason: 'Daily variant ${i + 1} is still the English body in Czech',
      );
    }
  });

  test('the name joins the body through the ARB, not a hardcoded comma', () {
    // Where a name sits in a sentence is a per-language decision; this only
    // asserts that each locale produces something containing the name and the
    // body, not that it looks like "Name, body".
    for (final l10n in [AppLocalizationsEn(), AppLocalizationsCs()]) {
      final named = NotificationMessages.daily(l10n, 'Mahesh');
      expect(named.body, contains('Mahesh'));
      expect(named.title, isNot(contains('Mahesh')));
    }
  });
}
