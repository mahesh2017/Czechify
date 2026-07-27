import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Shared 0–1 score → colour/label mapping so pronunciation, exercises, and
/// stats all grade on the same scale instead of each re-deriving thresholds.
class ScoreColors {
  ScoreColors._();

  static const goodThreshold = 0.8;
  static const okThreshold = 0.65;

  /// Takes a context because the grade colours come from [AppTokens] — the
  /// raw Material greens and reds this used to return were unreadable
  /// against the dark theme's background.
  static Color of(BuildContext context, double score) {
    final t = context.tokens;
    if (score >= goodThreshold) return t.green;
    if (score >= okThreshold) return t.amber;
    return t.red;
  }

  /// Bilingual (Czech/English) encouragement label for a score.
  static String label(double score) {
    if (score >= goodThreshold) return 'Výborně! Excellent!';
    if (score >= okThreshold) return 'Dobře. Good — keep practicing.';
    return 'Zkuste znovu. Try again.';
  }
}
