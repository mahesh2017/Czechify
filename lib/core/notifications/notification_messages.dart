import 'dart:math';

/// Static notification message templates for study reminders.
///
/// Design rules (enforced here, not at call sites):
///   (a) No {name} substitution in the title — lock-screen privacy.
///   (b) Name is only prepended to the body when non-empty: `$name, $body`.
///   (c) No punitive streak language — encouragement only.
///   (d) Say "one lesson", never "one exercise".
///   (e) Messages are encouraging and action-specific.
class NotificationMessages {
  NotificationMessages._();

  static final _random = Random();

  /// Eight daily-reminder variants as `(title, body)` records.
  static const List<({String title, String body})> dailyVariants = [
    (
      title: 'Time for Czech! 🇨🇿',
      body:
          'Just 5 minutes keeps your streak alive. Your next lesson is waiting!',
    ),
    (
      title: 'Ready for Czech? 💪',
      body: "Open the app, do one lesson, feel amazing. That's the deal.",
    ),
    (
      title: 'Czech is calling 📚',
      body: 'Five minutes now, one lesson done. Your future self says thanks.',
    ),
    (
      title: 'Ahoj! Let\'s practice 💚',
      body: "One lesson today keeps the momentum going. You've got this!",
    ),
    (
      title: 'Your daily Czech awaits ⚡',
      body: 'Open Czechify and finish one lesson. Just five minutes.',
    ),
    (
      title: 'Dobrý den! 🌙',
      body: 'Perfect time for Czech. One lesson, then relax.',
    ),
    (
      title: 'Keep the magic going ✨',
      body: 'Every word you learn today is a word you didn\'t know yesterday.',
    ),
    (
      title: 'One lesson away 🎯',
      body: 'Open Czechify, pick up where you left off, done in minutes.',
    ),
  ];

  /// Five evening catch-up variants as `(title, body)` records.
  static const List<({String title, String body})> eveningVariants = [
    (
      title: 'Your Czech missed you today 😊',
      body: "It's not too late! One lesson before bed keeps your streak alive.",
    ),
    (
      title: 'Last chance to practice today! 🌙',
      body: 'One lesson — about 5 minutes — and you\'re done for today.',
    ),
    (
      title: 'Czech is waiting 💚',
      body: "The day's almost over, but one lesson fits. Open Czechify?",
    ),
    (
      title: 'One more day, one more word 📖',
      body: "A quick lesson now keeps your streak going. You've got this!",
    ),
    (
      title: "Don't miss today 🌟",
      body: 'Five minutes of Czech before you call it a day. One lesson!',
    ),
  ];

  /// Picks a random daily-reminder variant and optionally prepends [name].
  ///
  /// The name is only prepended to the body when non-empty (never to the
  /// title), producing `$name, $body`.
  static ({String title, String body}) daily([String name = '']) {
    final variant = dailyVariants[_random.nextInt(dailyVariants.length)];
    return (title: variant.title, body: _withName(variant.body, name));
  }

  /// Picks a random evening catch-up variant and optionally prepends [name].
  static ({String title, String body}) evening([String name = '']) {
    final variant = eveningVariants[_random.nextInt(eveningVariants.length)];
    return (title: variant.title, body: _withName(variant.body, name));
  }

  /// Prepends the name to [body] only when [name] is non-empty.
  static String _withName(String body, String name) {
    if (name.isEmpty) return body;
    return '$name, $body';
  }
}
