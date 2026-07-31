/// The app's sound palette.
///
/// Every clip is synthesized by `tool/generate_sfx.py` from sine partials —
/// original work, so nothing here carries an attribution requirement.
///
/// The file extension is deliberate, not incidental. MP3 decoders prepend
/// ~26 ms of encoder delay, which reads as lag on a sound meant to land in
/// the same instant as a tap, so anything the learner triggers directly stays
/// uncompressed. The ceremony sounds start under a screen transition where
/// 26 ms is invisible, and compressing them saves most of the pack's size.
enum Sfx {
  /// Correct answer. Three rising steps so consecutive right answers
  /// escalate instead of repeating — this one fires ~790 times per course.
  correct1('correct_1.wav'),
  correct2('correct_2.wav'),
  correct3('correct_3.wav'),

  /// A run of correct answers reaching a milestone.
  combo('combo.wav'),

  /// Wrong answer. Low and soft on purpose: mistakes are where the learning
  /// happens, and this should read as a nudge rather than a penalty.
  wrong('wrong.wav'),

  lessonComplete('lesson_complete.mp3'),
  perfectLesson('perfect_lesson.mp3'),
  unitComplete('unit_complete.mp3'),
  badge('badge.mp3');

  const Sfx(this.file);

  final String file;

  String get asset => 'assets/sfx/$file';

  /// Sounds preloaded at startup because they fire mid-interaction, where
  /// the cost of loading on first use would be audible.
  static const latencyCritical = [correct1, correct2, correct3, combo, wrong];

  /// The rising correct-answer note for a run of [streak] right answers.
  /// Saturates at the top step — the escalation is a reward, not a siren.
  static Sfx correctForStreak(int streak) => switch (streak) {
    <= 1 => correct1,
    2 => correct2,
    _ => correct3,
  };
}

/// Physical feedback, named by intent rather than by platform API so call
/// sites read as "this is a small confirmation" not "this is a 10 ms buzz".
enum Haptic {
  none,

  /// A tick. Correct answers, selections.
  light,

  /// A definite bump. Wrong answers, lesson completion.
  medium,

  /// The heaviest single impact. Unit completion only.
  heavy,

  /// Two beats — reserved for the rarest moments, where a single impact
  /// would not read as different from an ordinary completion.
  double,
}
