import 'dart:ui';

import 'package:czechify/core/notifications/notification_messages.dart';
import 'package:czechify/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The catalogue is read from the ARB now, and scheduling has no
  // BuildContext, so the lookup is by locale here exactly as it is in
  // ReminderCoordinator.
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('message catalog avoids unsupported exercise promises', () {
    final variants = [
      ...NotificationMessages.dailyVariants(l10n),
      ...NotificationMessages.eveningVariants(l10n),
    ];

    expect(variants, isNotEmpty);
    for (final variant in variants) {
      expect(variant.title, isNotEmpty);
      expect(variant.body, isNotEmpty);
      expect(variant.body.toLowerCase(), isNot(contains('one exercise')));
      expect(variant.title, isNot(contains('{name}')));
      expect(variant.body, isNot(contains('{name}')));
    }
  });

  test('learner name is omitted when empty and never enters title', () {
    final anonymous = NotificationMessages.daily(l10n);
    final named = NotificationMessages.evening(l10n, 'Mahesh');

    expect(anonymous.body, isNot(startsWith(',')));
    expect(named.title, isNot(contains('Mahesh')));
    expect(named.body, startsWith('Mahesh, '));
  });
}
