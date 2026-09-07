import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one thing about notification sound that fails silently.
///
/// Android freezes a channel's sound, importance and vibration at creation
/// and ignores every later change — deliberately, so an app cannot make
/// itself louder after the learner has approved it. The consequence is that
/// editing the sound without changing the channel id ships a no-op: correct
/// on a fresh install, and completely unchanged on every device that already
/// has the app. That is invisible in review, invisible on the emulator you
/// just wiped, and only shows up as "the alert sound didn't change for me".
///
/// This is a source scan rather than a widget test because the failure is a
/// mismatch between two constants and the platform's rules about them —
/// nothing renders, and no fake plugin can reproduce Android's refusal.
void main() {
  final source =
      File(
        'lib/core/notifications/notification_service.dart',
      ).readAsStringSync();

  String constant(String name) {
    final match = RegExp("static const $name = '([^']+)'").firstMatch(source);
    expect(
      match,
      isNotNull,
      reason:
          '$name is no longer a simple string constant; this guard reads '
          'it textually and needs updating alongside it',
    );
    return match!.group(1)!;
  }

  test('the channel id is versioned', () {
    // A bare id cannot be revised. The version is what makes a future sound
    // or importance change possible at all.
    expect(
      constant('_channelId'),
      matches(RegExp(r'_v\d+$')),
      reason:
          'The channel id needs a version suffix so its sound and importance '
          'can ever be changed again',
    );
  });

  test('the channel a sound was added to is not the one already installed', () {
    // The whole point: v1 exists on every device that has run this app, and
    // its sound is fixed at the system default forever.
    final current = constant('_channelId');
    final legacy = RegExp(
      r'_legacyChannelIds = <String>\[([^\]]*)\]',
    ).firstMatch(source);
    expect(legacy, isNotNull, reason: 'No legacy channel list to retire');
    expect(
      legacy!.group(1),
      contains("'study_reminders'"),
      reason:
          'The original channel must stay in the retire list, or it lingers '
          'in Android settings as a dead second entry',
    );
    expect(current, isNot('study_reminders'));
  });

  test('the retired channels are actually deleted', () {
    expect(
      source,
      contains('deleteNotificationChannel(channelId: legacy)'),
      reason:
          'Listing a legacy channel without deleting it leaves the learner '
          'two Study Reminders entries in Android settings, one of them dead',
    );
  });

  test('the sound resource exists, with a name Android accepts', () {
    final match = RegExp(
      r"RawResourceAndroidNotificationSound\(\s*'([^']+)'",
    ).firstMatch(source);
    expect(match, isNotNull, reason: 'No raw resource sound is configured');
    final resource = match!.group(1)!;

    // Android resource names: lowercase letters, digits and underscores, and
    // referenced without an extension. A capital or a dash fails at build.
    expect(
      resource,
      matches(RegExp(r'^[a-z][a-z0-9_]*$')),
      reason: '"$resource" is not a legal Android resource name',
    );

    final candidates = Directory(
      'android/app/src/main/res/raw',
    ).listSync().whereType<File>().map((f) => f.uri.pathSegments.last);
    expect(
      candidates.where((f) => f.startsWith('$resource.')),
      isNotEmpty,
      reason:
          'res/raw has no $resource.* — the notification would fall back to '
          'the system sound. Present: ${candidates.join(', ')}',
    );
  });

  test(
    'every scheduled notification names the sound, not just the channel',
    () {
      // Some OEM builds fall back to the channel default when the notification
      // itself does not carry the sound, so each block has to repeat it.
      //
      // Each block is checked rather than counted: the channel carries a
      // `sound:` of its own, so a total would stay above the number of blocks
      // even after one of them lost it — which is exactly how the first version
      // of this test passed while the bug it describes was present.
      final missing = <int>[];
      var from = 0;
      while (true) {
        final open = source.indexOf('AndroidNotificationDetails(', from);
        if (open == -1) break;
        var depth = 0;
        var i = source.indexOf('(', open);
        final bodyStart = i + 1;
        for (; i < source.length; i++) {
          if (source[i] == '(') depth++;
          if (source[i] == ')') {
            depth--;
            if (depth == 0) break;
          }
        }
        final body = source.substring(bodyStart, i);
        if (!body.contains('sound: _alertSound')) missing.add(open);
        from = i;
      }

      expect(
        missing,
        isEmpty,
        reason:
            '${missing.length} AndroidNotificationDetails block(s) do not name '
            'the alert sound, at character offsets $missing',
      );
    },
  );

  test('the channel exists before anything can schedule against it', () {
    // The v2 channel is created, and v1 deleted, inside
    // NotificationService.initialize(). If that ran after `runApp`, a
    // coordinator replenishing on cold launch could schedule against a
    // channel that did not exist yet, and the delete could land after the
    // reschedule and take the new notifications with it.
    final main = File('lib/main.dart').readAsStringSync();
    final init = main.indexOf('NotificationService.instance.initialize()');
    final run = main.indexOf('runApp(');
    expect(
      init,
      greaterThan(-1),
      reason: 'Notifications are never initialized',
    );
    expect(run, greaterThan(-1));
    expect(
      init,
      lessThan(run),
      reason:
          'Notification setup must complete before runApp, or the reminder '
          'coordinator can schedule against a channel that is not there yet',
    );
    expect(
      main.substring(init - 30, init),
      contains('await'),
      reason: 'initialize() is not awaited, so runApp can race it',
    );
  });
}
