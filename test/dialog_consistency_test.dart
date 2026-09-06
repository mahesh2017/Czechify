import 'dart:io';

import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/presentation/widgets/common/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the two ways a dialog goes wrong here.
///
/// The first is drift. Ten dialogs were assembled by hand from `AlertDialog`
/// and had already diverged — some with an icon, most without; a destructive
/// action styled as an error `TextButton` in one place and a primary
/// `FilledButton` in another; two of them shipping hardcoded English into a
/// Czech UI. None of that fails a build, and reviewing one dialog tells you
/// nothing about the other nine.
///
/// The second is the layout that made this worth doing at all. `AlertDialog`
/// puts its actions in an [OverflowBar] and its content in a box that clips
/// rather than scrolls, so a long message in Czech at a large text size lost
/// both the end of its sentence and any way to read it. That failure is
/// invisible in every test that only asks whether the words are present.
void main() {
  final dartFiles =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

  /// Source with `//` comments removed — the dialog's own documentation
  /// explains what it replaced, and would otherwise match every scan below.
  String sourceOf(File file) => file
      .readAsStringSync()
      .split('\n')
      .map((line) {
        final comment = line.indexOf('//');
        return comment == -1 ? line : line.substring(0, comment);
      })
      .join('\n');

  test('no screen builds a bare AlertDialog', () {
    final offenders = [
      for (final file in dartFiles)
        if (sourceOf(file).contains('AlertDialog(')) file.path,
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'These build a stock AlertDialog, which does not follow the app\'s '
          'palette, wraps its actions into a lopsided two-row bar at ordinary '
          'phone widths, and clips a long message instead of scrolling it: '
          '${offenders.join(', ')}. Use AppDialog.',
    );
  });

  test('dialog wording comes from the ARB, not a Dart literal', () {
    // Two dialogs shipped English titles and bodies straight into the Czech
    // build. `l10n_parity_test` compares the two ARB files against each other,
    // so a string that never reached either one is invisible to it.
    final literal = RegExp(
      r"(title|message|confirmLabel|dismissLabel):\s*'",
    );
    final offenders = <String>[];
    for (final file in dartFiles) {
      final source = sourceOf(file);
      var index = source.indexOf('AppDialog(');
      while (index != -1) {
        // Far enough to cover the argument list of any dialog in the app.
        final window = source.substring(
          index,
          (index + 900).clamp(0, source.length),
        );
        final match = literal.firstMatch(window);
        if (match != null) offenders.add('${file.path}: ${match.group(0)}');
        index = source.indexOf('AppDialog(', index + 1);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These pass a hardcoded string to AppDialog, so a Czech learner '
          'reads it in English: ${offenders.join(', ')}. Add the wording to '
          'both ARB files and read it from AppLocalizations.',
    );
  });

  testWidgets('actions stay reachable when the message cannot fit', (
    tester,
  ) async {
    // A small screen at 200% text with a long body: the case that clipped the
    // old dialog. Both actions must still be on screen and must still fire.
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var confirmed = false;
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
        home: AppDialog(
          icon: Icons.cloud_outlined,
          title: 'A title long enough to wrap onto several lines by itself',
          message:
              'A body long enough that it cannot possibly fit beside the '
              'actions on a short screen at twice the normal text size, which '
              'is exactly when a learner most needs to be able to reach them. '
              'It keeps going for a while so that the scroll extent is real '
              'rather than a rounding error in the layout.',
          confirmLabel: 'Confirm',
          onConfirm: () => confirmed = true,
          dismissLabel: 'Dismiss',
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'The dialog overflowed rather than scrolling its message',
    );

    // `warnIfMissed` stays on: a tap that lands on nothing is the failure this
    // test exists to catch, and silently missing it would pass.
    await tester.tap(find.byKey(AppDialog.confirmKey));
    await tester.tap(find.byKey(AppDialog.dismissKey));
    await tester.pump();

    expect(confirmed, isTrue, reason: 'Confirm scrolled out of reach');
    expect(dismissed, isTrue, reason: 'Dismiss scrolled out of reach');
  });

  testWidgets('a message that fits is not faded', (tester) async {
    // The fade is an affordance for content that overflows. On the dialogs
    // that fit — nearly all of them — it must not appear at all.
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: const AppDialog(
          title: 'Short',
          message: 'Short enough to fit.',
          confirmLabel: 'Yes',
          dismissLabel: 'No',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsNothing);
  });
}
