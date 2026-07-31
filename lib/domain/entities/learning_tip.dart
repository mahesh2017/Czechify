import 'dart:math';

/// Evidence-based learning tips shown on the home screen.
///
/// Each tip rotates daily so the learner sees a fresh strategy each day.
/// Tips are grounded in spaced repetition, active recall, and motor-memory
/// research — adapted for Czech language learning.
class LearningTip {
  final String emoji;
  final String title;
  final String body;

  const LearningTip({
    required this.emoji,
    required this.title,
    required this.body,
  });

  static const List<LearningTip> all = [
    LearningTip(
      emoji: '✍️',
      title: 'Write it down',
      body:
          'Writing Czech words by hand engages motor memory. Studies show '
          'handwritten notes are remembered better than typed ones. Keep a '
          'small notebook for new vocabulary.',
    ),
    LearningTip(
      emoji: '🔁',
      title: 'Spaced repetition works',
      body:
          'Reviewing material at increasing intervals is the single most '
          'effective way to retain vocabulary. That\'s exactly what the SRS '
          'review cards do — do them every day, even briefly.',
    ),
    LearningTip(
      emoji: '🗣️',
      title: 'Shadow the audio',
      body:
          'Listen to a Czech phrase, then immediately repeat it out loud '
          'trying to match the pronunciation exactly. This "shadowing" '
          'technique trains both your ear and your mouth muscles.',
    ),
    LearningTip(
      emoji: '🧠',
      title: 'Active recall over re-reading',
      body:
          'Instead of re-reading grammar rules, test yourself. Try to '
          'explain a rule out loud without looking. If you can\'t, you '
          'don\'t know it yet — that\'s where learning happens.',
    ),
    LearningTip(
      emoji: '🔗',
      title: 'Link words to images',
      body:
          'Associate each new Czech word with a vivid mental image. The '
          'stranger the image, the better it sticks. For "kočka" (cat), '
          'imagine a cat wearing a traditional Czech kroj.',
    ),
    LearningTip(
      emoji: '⏰',
      title: 'Short sessions beat long ones',
      body:
          'Three 10-minute sessions spread through the day are more '
          'effective than one 30-minute block. Your brain consolidates '
          'language between sessions, not just during them.',
    ),
    LearningTip(
      emoji: '📚',
      title: 'Learn in context',
      body:
          'Don\'t memorize isolated word lists. Learn words inside full '
          'sentences — "Dám si pivo, prosím" (I\'ll have a beer, please) '
          'sticks better than "pivo = beer".',
    ),
    LearningTip(
      emoji: '😴',
      title: 'Sleep on it',
      body:
          'Your brain reinforces language learning during sleep. Reviewing '
          'vocabulary before bed can improve recall the next morning. Don\'t '
          'cram — a little each day with good rest in between.',
    ),
    LearningTip(
      emoji: '🎯',
      title: 'Make mistakes on purpose',
      body:
          'Try to use a Czech word you\'re unsure about. The correction '
          'that follows creates a stronger memory than passive study. The '
          'AI chat tutor is perfect for this — it won\'t judge you.',
    ),
    LearningTip(
      emoji: '🎵',
      title: 'Listen to Czech music',
      body:
          'Czech songs, podcasts, or radio in the background train your '
          'ear to the rhythm and intonation of the language, even when you '
          'don\'t understand every word. Try ČRo (Czech Radio) online.',
    ),
  ];

  /// Pick today's tip based on the day of the year, so it rotates daily
  /// but is deterministic — everyone sees the same tip each day.
  static LearningTip forToday() {
    final dayOfYear = DateTime.now().difference(DateTime(2026)).inDays;
    return all[dayOfYear % all.length];
  }

  /// Pick a random tip (for variety when the user refreshes).
  static LearningTip random() {
    final rng = Random();
    return all[rng.nextInt(all.length)];
  }
}
