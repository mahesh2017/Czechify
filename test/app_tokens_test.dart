import 'package:ceskina_pro/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic ink colors meet AA contrast on their soft surfaces', () {
    for (final tokens in [AppTokens.light, AppTokens.dark]) {
      expect(
        _contrast(tokens.priInk, tokens.priSoft),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(tokens.amberInk, tokens.amberSoft),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(tokens.redInk, tokens.redSoft),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(tokens.greenInk, tokens.greenSoft),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(tokens.violetInk, tokens.violetSoft),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('primary filled actions meet AA contrast', () {
    for (final tokens in [AppTokens.light, AppTokens.dark]) {
      expect(
        _contrast(tokens.onFill, tokens.priFill),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = [foreground.computeLuminance(), background.computeLuminance()]
    ..sort();
  return (lighter.last + 0.05) / (lighter.first + 0.05);
}
