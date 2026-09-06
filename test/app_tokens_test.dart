import 'package:czechify/core/theme/app_tokens.dart';
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

  test('every filled surface meets AA contrast under onFill', () {
    // This used to cover `priFill` alone, which passed — while five badges
    // filled themselves with `pri`, `violet` and `red` instead and put white
    // on top. The accent tokens go *lighter* in dark mode, by design, because
    // they are meant for text and icons sitting on the page; under white they
    // land at 2.5–2.7:1. The `*Fill` tokens are the ones that may carry
    // [AppTokens.onFill], so every one of them is checked here, and any new
    // fill added to the palette has to clear the same bar.
    for (final tokens in [AppTokens.light, AppTokens.dark]) {
      for (final fill in <String, Color>{
        'priFill': tokens.priFill,
        'violetFill': tokens.violetFill,
        'redFill': tokens.redFill,
      }.entries) {
        expect(
          _contrast(tokens.onFill, fill.value),
          greaterThanOrEqualTo(4.5),
          reason:
              '${fill.key} carries onFill text; at this contrast the label is '
              'not readable',
        );
      }
    }
  });

  test('accent tokens are not mistaken for fills', () {
    // Records why the `*Fill` variants exist at all: the accents they were
    // being substituted for genuinely fail. If a palette change ever made
    // these pass, the separate tokens could be reconsidered — until then this
    // is the evidence that they are not redundant.
    for (final accent in [
      AppTokens.dark.pri,
      AppTokens.dark.violet,
      AppTokens.dark.red,
    ]) {
      expect(_contrast(AppTokens.dark.onFill, accent), lessThan(4.5));
    }
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = [foreground.computeLuminance(), background.computeLuminance()]
    ..sort();
  return (lighter.last + 0.05) / (lighter.first + 0.05);
}
