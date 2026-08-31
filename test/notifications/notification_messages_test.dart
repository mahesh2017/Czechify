import 'package:czechify/core/notifications/notification_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('message catalog avoids unsupported exercise promises', () {
    final variants = [
      ...NotificationMessages.dailyVariants,
      ...NotificationMessages.eveningVariants,
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
    final anonymous = NotificationMessages.daily();
    final named = NotificationMessages.evening('Mahesh');

    expect(anonymous.body, isNot(startsWith(',')));
    expect(named.title, isNot(contains('Mahesh')));
    expect(named.body, startsWith('Mahesh, '));
  });
}
