import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../core/notifications/notification_messages.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/reminder_scheduler.dart';
import 'gamification_providers.dart';
import 'settings_providers.dart';

/// Derived provider exposing the learner's current daily XP as an int.
///
/// Watches the existing [gamificationProvider] (already invalidated/reloaded
/// after any XP change — lesson completion, review completion, badge rewards)
/// and projects it down to a single int. No code is inserted into any DAO or
/// repository; this single listener catches every XP source.
final gamificationDailyXpProvider = Provider<int>((ref) {
  final gamification = ref.watch(gamificationProvider);
  return gamification.dailyXp;
});

/// Coordinates study reminder notifications based on settings and app
/// lifecycle.
///
/// Watches [settingsProvider] for reminder-related changes, watches
/// [gamificationDailyXpProvider] for the zero→positive XP transition (to
/// cancel today's evening catch-up), and listens to app lifecycle events to
/// replenish the 30-day evening horizon on resume.
///
/// This provider has no state of its own — it is a [Notifier<void>] whose
/// [build] method exists solely to set up listeners. It must be read (or
/// watched) somewhere in the widget tree for the listeners to be active;
/// typically the app shell does `ref.watch(reminderCoordinatorProvider)`.
class ReminderCoordinator extends Notifier<void> {
  static final _log = Logger('ReminderCoordinator');

  late final NotificationService _service;
  late final ReminderScheduler _scheduler;
  AppLifecycleListener? _lifecycleListener;
  Future<void>? _replenishInFlight;

  @override
  void build() {
    _service = NotificationService.instance;
    _scheduler = const ReminderScheduler();

    // 1. Watch settings changes — schedule/cancel/reschedule as needed.
    ref.listen(settingsProvider, (prev, next) {
      _onSettingsChanged(prev, next);
    });

    // 2. Watch dailyXp for zero→positive transition — cancel today's evening.
    ref.listen(gamificationDailyXpProvider, (prev, next) {
      if (prev == 0 && next > 0) {
        _cancelTodaysEvening();
      }
    });

    // 3. App lifecycle — replenish on resume/restart.
    _lifecycleListener = AppLifecycleListener(
      onResume: replenish,
      onRestart: replenish,
    );

    // A cold launch does not necessarily produce a resume callback after this
    // listener is installed. Replenish once immediately so a consumed horizon,
    // a timezone change, or an OS permission change is handled at startup.
    unawaited(replenish());

    // Clean up when the provider is disposed.
    ref.onDispose(() {
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
    });
  }

  // ── Settings change handler ──

  Future<void> _onSettingsChanged(AppSettings? prev, AppSettings next) async {
    // Reminders toggled on/off — the primary switch.
    if (prev?.remindersEnabled != next.remindersEnabled) {
      if (next.remindersEnabled) {
        final granted = await _service.requestPermission();
        if (granted) {
          await _scheduleAll(next);
        } else {
          // Keep the learner's preference enabled. Settings can then explain
          // that the OS has blocked delivery and offer a real settings link;
          // replenishment schedules automatically after permission is granted.
          _log.warning(
            'Notification permission denied; reminders remain pending.',
          );
          await _cancelAllOwned();
        }
      } else {
        await _cancelAllOwned();
      }
      return;
    }

    // Preferred time changed — reschedule everything.
    if (prev?.preferredTime != next.preferredTime) {
      await _cancelAllOwned();
      if (next.remindersEnabled) {
        await _scheduleAll(next);
      }
      return;
    }

    // Catch-up toggled — only the evening horizon needs refreshing.
    if (prev?.catchUpEnabled != next.catchUpEnabled) {
      await _cancelEveningHorizon();
      if (next.remindersEnabled && next.catchUpEnabled) {
        await _scheduleEveningHorizon(next);
      }
      return;
    }

    // Timezone persistence is bookkeeping performed by replenish(); it has
    // already rescheduled using the new tz.local before updating the setting.
  }

  // ── Scheduling helpers ──

  /// Schedule the daily repeating reminder plus the 30-day evening horizon.
  Future<void> _scheduleAll(AppSettings settings) async {
    if (settings.preferredTime == null) return;

    final timezone = await _service.refreshTimezone();
    if (timezone != null && timezone != settings.lastKnownTimezone) {
      await ref.read(settingsProvider.notifier).setLastKnownTimezone(timezone);
      settings = ref.read(settingsProvider);
    }

    final gamification = ref.read(gamificationProvider);
    final learnerName = settings.learnerName;

    // 1. Daily repeating reminder (ID 1001).
    final dailyMessage = NotificationMessages.daily(learnerName);
    await _service.scheduleDailyReminder(
      time: settings.preferredTime!,
      title: dailyMessage.title,
      body: dailyMessage.body,
    );

    // 2. 30-day evening catch-up horizon (IDs 2000–2029).
    if (settings.catchUpEnabled) {
      await _scheduleEveningHorizon(settings);
    }

    // 3. If the user already has XP today, cancel today's evening reminder.
    if (gamification.dailyXp > 0) {
      await _cancelTodaysEvening();
    }
  }

  /// Schedule the 30-day evening catch-up horizon.
  ///
  /// [ReminderScheduler.buildEveningSchedule] already fills each
  /// [ScheduledReminder] with a random evening message, so we pass those
  /// titles/bodies straight through to the service.
  Future<void> _scheduleEveningHorizon(AppSettings settings) async {
    if (settings.preferredTime == null) return;

    final reminders = _scheduler.buildEveningSchedule(
      today: DateTime.now(),
      catchUpEnabled: settings.catchUpEnabled,
      preferredTime: settings.preferredTime!,
    );

    for (final reminder in reminders) {
      await _service.scheduleOneShot(
        id: reminder.id,
        scheduledDate: reminder.scheduledDate,
        title: reminder.title,
        body: reminder.body,
      );
    }
  }

  /// Cancel the daily reminder plus all evening horizon IDs.
  Future<void> _cancelAllOwned() async {
    await _service.cancelOwnedIds();
  }

  /// Cancel all 30 evening catch-up IDs (2000–2029), leaving the daily
  /// repeating reminder (1001) untouched.
  Future<void> _cancelEveningHorizon() async {
    final dailyId = ReminderScheduler.dailyReminderId;
    for (final id in _scheduler.ownedIds) {
      if (id == dailyId) continue; // skip the daily reminder
      await _service.cancel(id);
    }
  }

  /// Cancel only today's evening catch-up notification.
  Future<void> _cancelTodaysEvening() async {
    final id = _scheduler.eveningIdForToday();
    await _service.cancel(id);
  }

  // ── Public API ──

  /// Called on app resume/restart. Ensures the daily reminder is scheduled,
  /// refreshes the 30-day evening horizon, and cancels today's evening
  /// notification if the user has already earned XP.
  Future<void> replenish() {
    final active = _replenishInFlight;
    if (active != null) return active;
    final future = _replenish();
    _replenishInFlight = future;
    return future.whenComplete(() {
      if (identical(_replenishInFlight, future)) {
        _replenishInFlight = null;
      }
    });
  }

  Future<void> _replenish() async {
    await ref.read(settingsProvider.notifier).ready;
    await ref.read(gamificationProvider.notifier).ready;

    var settings = ref.read(settingsProvider);
    if (!settings.remindersEnabled || settings.preferredTime == null) return;

    final permission = await _service.areNotificationsEnabled();
    if (permission == false) return;

    final timezone = await _service.refreshTimezone();
    final timezoneChanged =
        timezone != null && timezone != settings.lastKnownTimezone;
    if (timezoneChanged) {
      await _cancelAllOwned();
      await ref.read(settingsProvider.notifier).setLastKnownTimezone(timezone);
      settings = ref.read(settingsProvider);
    }

    final gamification = ref.read(gamificationProvider);
    final learnerName = settings.learnerName;

    // 1. Ensure daily repeating reminder is scheduled (refreshes message).
    final dailyMessage = NotificationMessages.daily(learnerName);
    await _service.scheduleDailyReminder(
      time: settings.preferredTime!,
      title: dailyMessage.title,
      body: dailyMessage.body,
    );

    // 2. Cancel all existing evening IDs, then re-schedule a fresh horizon.
    await _cancelEveningHorizon();
    await _scheduleEveningHorizon(settings);

    // 3. If the user already has XP today, cancel today's evening reminder.
    if (gamification.dailyXp > 0) {
      await _cancelTodaysEvening();
    }
  }
}

/// Provider for the reminder coordinator. Watch this from the app shell to
/// keep the notification listeners active for the lifetime of the app.
final reminderCoordinatorProvider = NotifierProvider<ReminderCoordinator, void>(
  ReminderCoordinator.new,
);
