import 'dart:async';

import 'package:czechify/data/database/database.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:czechify/presentation/providers/reminder_coordinator.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('native reminder mutations finish in requested order', () async {
    final queue = ReminderOperationQueue();
    final firstGate = Completer<void>();
    final events = <String>[];

    final staleCancellation = queue.run(() async {
      events.add('cancel-start');
      await firstGate.future;
      events.add('cancel-finish');
    });
    final restoredSchedule = queue.run(() async {
      events.add('schedule-start');
      await Future<void>.delayed(Duration.zero);
      events.add('schedule-finish');
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['cancel-start']);

    firstGate.complete();
    await Future.wait([staleCancellation, restoredSchedule]);
    expect(events, [
      'cancel-start',
      'cancel-finish',
      'schedule-start',
      'schedule-finish',
    ]);
  });

  test('one failed mutation does not poison later cleanup', () async {
    final queue = ReminderOperationQueue();
    final events = <String>[];

    await expectLater(
      queue.run(() async => throw StateError('native failure')),
      throwsStateError,
    );
    await queue.run(() async {
      events.add('cleanup');
    });

    expect(events, ['cleanup']);
  });

  test(
    'enabling from an unset time persists the visible 19:00 default',
    () async {
      SharedPreferences.setMockInitialValues({});
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      await database.customSelect('SELECT 1').get();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      await container.read(settingsProvider.notifier).ready;
      expect(container.read(settingsProvider).preferredTime, isNull);

      await container
          .read(reminderCoordinatorProvider.notifier)
          .setRemindersEnabled(true);

      expect(
        container.read(settingsProvider).preferredTime,
        ReminderCoordinator.defaultReminderTime,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('settings_reminder_hour'), 19);
      expect(preferences.getInt('settings_reminder_minute'), 0);
      expect(preferences.getBool('settings_reminders_enabled'), isTrue);
    },
  );
}
