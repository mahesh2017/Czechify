import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reminder settings persist and reload together', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    addTearDown(first.dispose);
    final notifier = first.read(settingsProvider.notifier);
    await notifier.ready;

    await notifier.setPreferredTime(const TimeOfDay(hour: 18, minute: 45));
    await notifier.setRemindersEnabled(true);
    await notifier.setCatchUpEnabled(false);
    await notifier.setLastKnownTimezone('Europe/Prague');

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final reloaded = second.read(settingsProvider.notifier);
    await reloaded.ready;
    final state = second.read(settingsProvider);

    expect(state.preferredTime, const TimeOfDay(hour: 18, minute: 45));
    expect(state.remindersEnabled, isTrue);
    expect(state.catchUpEnabled, isFalse);
    expect(state.lastKnownTimezone, 'Europe/Prague');
  });

  test('invalid persisted clock values are ignored safely', () async {
    SharedPreferences.setMockInitialValues({
      'settings_reminder_hour': 25,
      'settings_reminder_minute': -1,
      'settings_reminders_enabled': true,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);
    await notifier.ready;

    expect(container.read(settingsProvider).preferredTime, isNull);
  });
}
