import 'package:czechify/core/notifications/reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scheduler = ReminderScheduler();

  test('builds a thirty-day date-specific evening horizon', () {
    final reminders = scheduler.buildEveningSchedule(
      today: DateTime(2026, 8, 2, 10),
      catchUpEnabled: true,
      preferredTime: const TimeOfDay(hour: 19, minute: 0),
    );

    expect(reminders, hasLength(30));
    expect(reminders.first.id, 2000);
    expect(reminders.last.id, 2029);
    expect(reminders.first.scheduledDate, DateTime(2026, 8, 2, 21, 30));
    expect(reminders.last.scheduledDate, DateTime(2026, 8, 31, 21, 30));
    expect(reminders.map((item) => item.id).toSet(), hasLength(30));
  });

  test('every reminder keeps 21:30 local across a DST transition', () {
    // A 30-day horizon starting in late October spans the end of summer time.
    // Adding `Duration(days:)` adds exact elapsed hours, so every reminder
    // after the change landed an hour early — 20:30 for the rest of the month.
    final reminders = scheduler.buildEveningSchedule(
      today: DateTime(2026, 10, 20, 8),
      catchUpEnabled: true,
      preferredTime: const TimeOfDay(hour: 8, minute: 0),
    );

    expect(reminders, hasLength(30));
    for (final reminder in reminders) {
      expect(
        reminder.scheduledDate.hour,
        21,
        reason: 'wall-clock hour drifted on ${reminder.scheduledDate}',
      );
      expect(reminder.scheduledDate.minute, 30);
    }
    // Consecutive calendar days, so the horizon neither skips nor repeats a
    // date while crossing the transition.
    expect(reminders.first.scheduledDate, DateTime(2026, 10, 20, 21, 30));
    expect(reminders.last.scheduledDate, DateTime(2026, 11, 18, 21, 30));
  });

  test('skips only the elapsed slot when today is past catch-up time', () {
    final reminders = scheduler.buildEveningSchedule(
      today: DateTime(2026, 8, 2, 22),
      catchUpEnabled: true,
      preferredTime: const TimeOfDay(hour: 18, minute: 0),
    );

    expect(reminders, hasLength(29));
    expect(reminders.first.id, 2001);
    expect(reminders.first.scheduledDate, DateTime(2026, 8, 3, 21, 30));
  });

  test('suppresses catch-up inside two hours but permits exact boundary', () {
    expect(
      scheduler.shouldSuppressEvening(const TimeOfDay(hour: 20, minute: 0)),
      isTrue,
    );
    expect(
      scheduler.shouldSuppressEvening(const TimeOfDay(hour: 19, minute: 30)),
      isFalse,
    );
  });

  test('disabled catch-up produces no scheduled requests', () {
    expect(
      scheduler.buildEveningSchedule(
        today: DateTime(2026, 8, 2, 10),
        catchUpEnabled: false,
        preferredTime: const TimeOfDay(hour: 18, minute: 0),
      ),
      isEmpty,
    );
  });

  test('owned IDs contain only daily and evening slots', () {
    expect(scheduler.ownedIds, hasLength(31));
    expect(scheduler.ownedIds.first, ReminderScheduler.dailyReminderId);
    expect(
      scheduler.ownedIds.skip(1),
      orderedEquals(List.generate(30, (i) => 2000 + i)),
    );
  });
}
