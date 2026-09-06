import 'dart:math';

import '../../l10n/app_localizations.dart';

/// Notification message templates for study reminders.
///
/// Design rules (enforced here, not at call sites):
///   (a) No {name} substitution in the title — lock-screen privacy.
///   (b) Name is only prepended to the body when non-empty.
///   (c) No punitive streak language — encouragement only.
///   (d) Say "one lesson", never "one exercise".
///   (e) Messages are encouraging and action-specific.
///
/// The wording lives in the ARB and arrives as [AppLocalizations] rather than
/// being read from a `BuildContext`. Nothing here has one: the variants are
/// picked when the reminder is *scheduled*, which happens in a provider, and
/// the text is then handed to the platform to display up to thirty days later.
/// That also means a reminder is written in whatever language was current when
/// it was scheduled — see the locale branch in `ReminderCoordinator`, which
/// reschedules when the interface language changes so the queue does not keep
/// speaking the old one.
class NotificationMessages {
  NotificationMessages._();

  static final _random = Random();

  /// Eight daily-reminder variants as `(title, body)` records.
  static List<({String title, String body})> dailyVariants(
    AppLocalizations l10n,
  ) => [
    (title: l10n.notifyDaily1Title, body: l10n.notifyDaily1Body),
    (title: l10n.notifyDaily2Title, body: l10n.notifyDaily2Body),
    (title: l10n.notifyDaily3Title, body: l10n.notifyDaily3Body),
    (title: l10n.notifyDaily4Title, body: l10n.notifyDaily4Body),
    (title: l10n.notifyDaily5Title, body: l10n.notifyDaily5Body),
    (title: l10n.notifyDaily6Title, body: l10n.notifyDaily6Body),
    (title: l10n.notifyDaily7Title, body: l10n.notifyDaily7Body),
    (title: l10n.notifyDaily8Title, body: l10n.notifyDaily8Body),
  ];

  /// Five evening catch-up variants as `(title, body)` records.
  static List<({String title, String body})> eveningVariants(
    AppLocalizations l10n,
  ) => [
    (title: l10n.notifyEvening1Title, body: l10n.notifyEvening1Body),
    (title: l10n.notifyEvening2Title, body: l10n.notifyEvening2Body),
    (title: l10n.notifyEvening3Title, body: l10n.notifyEvening3Body),
    (title: l10n.notifyEvening4Title, body: l10n.notifyEvening4Body),
    (title: l10n.notifyEvening5Title, body: l10n.notifyEvening5Body),
  ];

  /// Picks a random daily-reminder variant and optionally prepends [name].
  static ({String title, String body}) daily(
    AppLocalizations l10n, [
    String name = '',
  ]) {
    final variants = dailyVariants(l10n);
    final variant = variants[_random.nextInt(variants.length)];
    return (title: variant.title, body: _withName(l10n, variant.body, name));
  }

  /// Picks a random evening catch-up variant and optionally prepends [name].
  static ({String title, String body}) evening(
    AppLocalizations l10n, [
    String name = '',
  ]) {
    final variants = eveningVariants(l10n);
    final variant = variants[_random.nextInt(variants.length)];
    return (title: variant.title, body: _withName(l10n, variant.body, name));
  }

  /// Prepends the name to [body] only when [name] is non-empty.
  ///
  /// Through the ARB rather than `'$name, $body'`: where a name sits in a
  /// sentence, and whether a comma belongs after it at all, is a decision each
  /// language makes for itself.
  static String _withName(AppLocalizations l10n, String body, String name) {
    if (name.isEmpty) return body;
    return l10n.notifyBodyWithName(name, body);
  }
}
