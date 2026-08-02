import 'dart:convert';
import 'dart:io';

import 'package:ceskina_pro/core/diagnostics/safe_diagnostics.dart';
import 'package:ceskina_pro/core/notifications/navigation_intent.dart';
import 'package:ceskina_pro/core/notifications/reminder_scheduler.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Singleton wrapper around [FlutterLocalNotificationsPlugin].
///
/// Owns the Android notification channel, timezone setup, permission flow,
/// and the daily + one-shot scheduling surface used by the study-reminder
/// feature. All native plugin calls are wrapped in try-catch and routed to
/// [SafeDiagnostics.error] on failure — the service never rethrows.
class NotificationService {
  NotificationService._();

  /// Singleton instance.
  static final instance = NotificationService._();

  static const _channelId = 'study_reminders';
  static const _channelName = 'Study Reminders';
  static const _channelDesc = 'Daily reminders to practice Czech';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  ReminderScheduler _scheduler = const ReminderScheduler();

  /// Allows tests / wiring code to inject a [ReminderScheduler].
  @visibleForTesting
  void setScheduler(ReminderScheduler scheduler) => _scheduler = scheduler;

  /// Initializes the notification channel, plugin, and timezone database.
  ///
  /// Sets up the notification-tap callback to enqueue
  /// [NavigationTarget.curriculum]. Never rethrows — errors are logged via
  /// [SafeDiagnostics.error].
  Future<void> initialize() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create the Android channel (no-op on other platforms, guarded inside).
      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );
      }

      await _initTimezone();
    } catch (e, st) {
      SafeDiagnostics.error('notification_init_failed', e, st);
    }
  }

  /// Notification-tap callback — enqueues the curriculum navigation target.
  void _onNotificationTapped(NotificationResponse response) {
    try {
      NavigationIntent.queue(NavigationTarget.curriculum);
    } catch (e, st) {
      SafeDiagnostics.error('notification_tap_callback_failed', e, st);
    }
  }

  /// Loads the tz database and sets the local location from the device tz.
  Future<void> _initTimezone() async {
    try {
      tz_data.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e, st) {
      SafeDiagnostics.error('notification_timezone_init_failed', e, st);
    }
  }

  /// Returns the device's IANA timezone identifier, or `null` on failure.
  Future<String?> getCurrentTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return info.identifier;
    } catch (e, st) {
      SafeDiagnostics.error('notification_timezone_read_failed', e, st);
      return null;
    }
  }

  /// Requests notification permission. Returns `true` when granted.
  ///
  /// On Android uses [AndroidFlutterLocalNotificationsPlugin]
  /// `.requestNotificationsPermission()`; on iOS uses
  /// [IOSFlutterLocalNotificationsPlugin]
  /// `.requestPermissions(alert: true, badge: true, sound: true)`.
  /// Returns `false` on any error or denial.
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted =
            await androidPlugin?.requestNotificationsPermission() ?? false;
        return granted;
      }
      if (Platform.isIOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        return granted;
      }
      return false;
    } catch (e, st) {
      SafeDiagnostics.error('notification_permission_request_failed', e, st);
      return false;
    }
  }

  /// Schedules a repeating daily reminder at [time] (local) with [title]/[body].
  ///
  /// Cancels the previous daily reminder first (stable ID), then uses
  /// `zonedSchedule` with [DateTimeComponents.time] so it repeats every day
  /// at the same local time. Uses [AndroidScheduleMode.inexact] so the app
  /// needs no `SCHEDULE_EXACT_ALARM` permission.
  Future<void> scheduleDailyReminder({
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    try {
      final id = ReminderScheduler.dailyReminderId;
      await _plugin.cancel(id: id);

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      // If the time has already passed today, start tomorrow.
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final payload = json.encode(const {'target': 'curriculum'});

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (e, st) {
      SafeDiagnostics.error('notification_schedule_daily_failed', e, st);
    }
  }

  /// Schedules a one-shot notification at [scheduledDate] (local) with no
  /// repeat.
  Future<void> scheduleOneShot({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
  }) async {
    try {
      final scheduled = tz.TZDateTime.from(scheduledDate, tz.local);

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexact,
        // null → no repeat (one-shot).
        matchDateTimeComponents: null,
        payload: json.encode(const {'target': 'curriculum'}),
      );
    } catch (e, st) {
      SafeDiagnostics.error('notification_schedule_oneshot_failed', e, st);
    }
  }

  /// Cancels a single notification by [id].
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e, st) {
      SafeDiagnostics.error('notification_cancel_failed', e, st);
    }
  }

  /// Cancels every ID owned by [ReminderScheduler] (daily + 30 evening slots).
  Future<void> cancelOwnedIds() async {
    try {
      for (final id in _scheduler.ownedIds) {
        await _plugin.cancel(id: id);
      }
    } catch (e, st) {
      SafeDiagnostics.error('notification_cancel_owned_failed', e, st);
    }
  }

  /// Returns the current permission state if known, or `null` if unknown.
  Future<bool?> areNotificationsEnabled() async {
    try {
      // Touch launch details to ensure the plugin is wired up.
      await _plugin.getNotificationAppLaunchDetails();

      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await androidPlugin?.areNotificationsEnabled();
      }
      if (Platform.isIOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final permissions = await iosPlugin?.checkPermissions();
        return permissions?.isEnabled;
      }
      return null;
    } catch (e, st) {
      SafeDiagnostics.error('notification_enabled_check_failed', e, st);
      return null;
    }
  }

  /// Returns the list of currently pending notification requests.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e, st) {
      SafeDiagnostics.error('notification_pending_read_failed', e, st);
      return const <PendingNotificationRequest>[];
    }
  }
}