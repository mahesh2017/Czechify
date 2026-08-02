import 'package:ceskina_pro/core/notifications/notification_messages.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// A single scheduled reminder produced by [ReminderScheduler].
class ScheduledReminder {
  final int id;
  final DateTime scheduledDate;
  final String title;
  final String body;

  const ScheduledReminder({
    required this.id,
    required this.scheduledDate,
    required this.title,
    required this.body,
  });

  @override
  String toString() =>
      'ScheduledReminder(id: $id, scheduledDate: $scheduledDate, '
      'title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ScheduledReminder && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Pure-Dart helper that computes date-specific notification IDs and the
/// 30-day evening catch-up horizon.
///
/// No Flutter plugin imports — only [TimeOfDay] from `flutter/material.dart`
/// (a foundation type). All scheduling side-effects live in
/// [NotificationService].
class ReminderScheduler {
  /// Constructible so [NotificationService] and tests can hold an instance.
  const ReminderScheduler();

  /// Base ID for evening catch-up notifications. Day *N* (0-indexed from today
  /// after replenishment) uses `_eveningBaseId + N`.
  static const _eveningBaseId = 2000;

  /// How many days ahead the evening schedule covers.
  static const _horizonDays = 30;

  /// Stable ID for the repeating daily reminder.
  static const _dailyReminderId = 1001;

  /// Local time at which evening catch-up notifications fire.
  static const eveningHour = 21;
  static const eveningMinute = 30;

  /// Returns the evening notification ID for [dayOffset] days from today.
  int eveningIdForDay(int dayOffset) => _eveningBaseId + dayOffset;

  /// Returns the evening notification ID for "today" (offset 0 = today after
  /// replenishment).
  int eveningIdForToday() => _eveningBaseId;

  /// Returns true when [preferredTime] is within two hours (120 minutes) of
  /// 21:30, meaning the evening catch-up would fire too close to the user's
  /// preferred daily reminder and should be suppressed.
  bool shouldSuppressEvening(TimeOfDay preferredTime) {
    const eveningTotal = eveningHour * 60 + eveningMinute;
    final preferredTotal = preferredTime.hour * 60 + preferredTime.minute;
    final diff = (eveningTotal - preferredTotal).abs();
    return diff < 120;
  }

  /// Builds up to [_horizonDays] [ScheduledReminder]s, each at 21:30 local.
  ///
  /// - Skips today when the current local time is already past 21:30.
  /// - Skips everything when [catchUpEnabled] is `false` or
  ///   [shouldSuppressEvening] returns `true`.
  /// - Each reminder gets a fresh random evening message from
  ///   [NotificationMessages.evening].
  List<ScheduledReminder> buildEveningSchedule({
    required DateTime today,
    required bool catchUpEnabled,
    required TimeOfDay preferredTime,
  }) {
    if (!catchUpEnabled || shouldSuppressEvening(preferredTime)) {
      return const <ScheduledReminder>[];
    }

    final reminders = <ScheduledReminder>[];
    for (var dayOffset = 0; dayOffset < _horizonDays; dayOffset++) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
        eveningHour,
        eveningMinute,
      ).add(Duration(days: dayOffset));

      // Skip today if 21:30 has already passed.
      if (dayOffset == 0 && date.isBefore(today)) {
        continue;
      }

      final message = NotificationMessages.evening();
      reminders.add(
        ScheduledReminder(
          id: eveningIdForDay(dayOffset),
          scheduledDate: date,
          title: message.title,
          body: message.body,
        ),
      );
    }
    return reminders;
  }

  /// All notification IDs owned by this scheduler, for bulk cancellation.
  ///
  /// Always `[1001, 2000, 2001, … 2029]` — the daily reminder plus 30 evening
  /// slots — regardless of how many are currently scheduled.
  List<int> get ownedIds => [
    _dailyReminderId,
    for (var i = 0; i < _horizonDays; i++) _eveningBaseId + i,
  ];

  /// The stable daily-reminder ID, exposed for cancellation by callers that
  /// don't hold a [ReminderScheduler] instance.
  static int get dailyReminderId => _dailyReminderId;
}
