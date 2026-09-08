import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps corner radii on the scale the design system claims.
///
/// The rule was written down in `lesson_ui.dart` — "12, 16, 24 or 999.
/// Nothing else" — and was not true: 18 was in use at sixteen sites and 28 at
/// four, alongside single instances of 11, 13 and 14 that were one-off
/// overrides of `IconTile`'s own default. A rule nothing checks decays into a
/// description of what someone once intended.
///
/// The values here are the ones the app actually uses, one-offs normalised.
/// Adding to this set is a design decision, which is the point: it should
/// take an edit here and a reason, not a number typed at a call site.
void main() {
  // `final`, not `const`: a const set of doubles is not constant-evaluable.
  final allowed = <double>{6, 12, 16, 18, 24, 28, 999};

  test('every corner radius is on the scale', () {
    // `BorderRadius.circular` / `Radius.circular`, plus the `radius:` argument
    // the house components (IconTile, KeyCta) take.
    //
    // `cursorRadius:` is a text caret, `RadialGradient.radius` is a gradient
    // stop expressed as a fraction, and `InkResponse.radius` is a splash
    // extent — none of them is a corner, and all three would otherwise be
    // read as one.
    final corner = RegExp(
      r'(?<!cursor)(?<!Ink)(?:BorderRadius|Radius)\.circular\(\s*([\d.]+)\s*\)',
    );
    final argument = RegExp(r'(?<![\w.])radius:\s*([\d.]+)\s*,');

    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (file.path.endsWith('.g.dart')) continue;
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (code.contains('cursorRadius')) continue;
        // `InkResponse(` sits a few lines above its own `radius:`, which is a
        // splash extent rather than a corner.
        final preceding = lines
            .sublist(i - 4 < 0 ? 0 : i - 4, i + 1)
            .join('\n');
        if (preceding.contains('InkResponse(') ||
            preceding.contains('RadialGradient(')) {
          continue;
        }
        for (final pattern in [corner, argument]) {
          for (final match in pattern.allMatches(code)) {
            final value = double.parse(match.group(1)!);
            // A gradient's radius is a fraction of the shorter side, and an
            // ink splash is measured in a different unit entirely; neither is
            // ever a whole number of logical pixels below 6 here.
            if (value < 6) continue;
            if (allowed.contains(value)) continue;
            offenders.add('${file.path}:${i + 1}  radius $value');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These use a corner radius that is not on the scale:\n'
          '${offenders.join('\n')}\n'
          'Use the nearest scale value, or add the new one to `allowed` here '
          'and to the rule in lesson_ui.dart together.',
    );
  });
}
