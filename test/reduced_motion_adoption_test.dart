import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Implicit animations have to ask for reduced motion; nothing asks for them.
///
/// Flutter does not disable `AnimatedContainer` and friends when the platform
/// requests less motion — they animate from a `duration:` and nothing else. So
/// a widget that hardcodes one keeps moving for a learner who turned Reduce
/// Motion on, and does it silently: no lint, no exception, no failing test.
///
/// That is not hypothetical. Two selection surfaces shipped with a bare
/// `Duration(milliseconds: 160)` and kept animating, through a suite of 853
/// green tests, because every one of those tests validated the motion
/// *primitives* rather than their adoption at the call sites.
///
/// `motion_release_validation_test.dart` covers the primitives. This covers
/// whether the app actually uses them.
void main() {
  test('every implicit animation resolves its duration through AppMotion', () {
    final sites = _scanLib();

    // A scanner that silently matches nothing would pass this file forever.
    expect(
      sites.length,
      greaterThanOrEqualTo(15),
      reason:
          'only ${sites.length} implicit animations found — the scanner has '
          'probably stopped matching real code rather than the app having '
          'genuinely shed them',
    );

    final violations = sites.where((site) => !site.isCompliant).toList();

    expect(
      violations,
      isEmpty,
      reason:
          'these implicit animations keep animating under Reduce Motion:\n'
          '${violations.map((v) => '  $v').join('\n')}\n\n'
          'Wrap the duration in context.motionDuration(AppMotion.x) — see '
          'lib/core/theme/app_motion.dart. If the site is already safe by a '
          'route this scanner cannot see (an enclosing motionDisabled branch, '
          'say), add it to _reviewed below with a reason.',
    );
  });

  test('every allowlisted exception still exists', () {
    // An allowlist entry that no longer matches anything is a decision that has
    // quietly expired — drop it rather than leaving a licence lying around.
    final seen = <String, Set<String>>{};
    for (final site in _scanLib()) {
      (seen[site.path] ??= <String>{}).add(site.expression);
    }

    for (final entry in _reviewed.entries) {
      for (final expression in entry.value) {
        expect(
          seen[entry.key],
          contains(expression),
          reason:
              '${entry.key} no longer contains `$expression` — remove that '
              'entry from _reviewed',
        );
      }
    }
  });
}

/// Sites that are reduced-motion correct by a route this scanner cannot see.
///
/// Keyed by the exact duration expression rather than a line number: lines
/// drift whenever the file is reformatted, the expression does not, and editing
/// one of these drops it out of the allowlist so the change gets looked at
/// again instead of being grandfathered in.
const _reviewed = <String, Set<String>>{
  // The primitives themselves. `resolved` is context.motionDuration(duration),
  // computed a few lines above each use, and the file carries its own coverage
  // in motion_widgets_test.dart and motion_release_validation_test.dart.
  'lib/presentation/widgets/common/motion_widgets.dart': {'resolved'},

  // Guarded one level out: under reduced motion the enclosing conditional swaps
  // in a plain FractionallySizedBox, so the animated widget is never built at
  // all. Stronger than resolving the duration to zero.
  'lib/presentation/screens/exam/mock_exam_screen.dart': {
    'AppMotion.selection',
  },

  // `instant` is MediaQuery.disableAnimationsOf(context), read in the same
  // build method. Correct, just not expressed through the token scale.
  'lib/presentation/widgets/common/lesson_ui.dart': {
    'instant ? Duration.zero : const Duration(milliseconds: 180)',
    'instant ? Duration.zero : const Duration(milliseconds: 120)',
  },
  'lib/presentation/widgets/lesson/exercises/error_correction_view.dart': {
    'instant ? Duration.zero : const Duration(milliseconds: 180)',
  },
};

class _Site {
  _Site({
    required this.path,
    required this.line,
    required this.widget,
    required this.parameter,
    required this.expression,
  });

  final String path;
  final int line;
  final String widget;
  final String parameter;
  final String expression;

  bool get isCompliant =>
      expression.contains('motionDuration') ||
      expression == 'Duration.zero' ||
      (_reviewed[path]?.contains(expression) ?? false);

  @override
  String toString() => '$path:$line  $widget($parameter: $expression)';
}

final _constructor = RegExp(r'\bAnimated([A-Za-z_]\w*)\s*\(');

List<_Site> _scanLib() {
  final sites = <_Site>[];

  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final source = _blankCommentsAndStrings(file.readAsStringSync());

    for (final match in _constructor.allMatches(source)) {
      final open = match.end - 1;
      final close = _matchingParen(source, open);
      if (close == null) continue;

      final args = source.substring(open + 1, close);
      for (final parameter in const ['duration', 'reverseDuration']) {
        final expression = _namedArgument(args, parameter);
        if (expression == null) continue;
        sites.add(
          _Site(
            path: file.path,
            line: '\n'.allMatches(source.substring(0, match.start)).length + 1,
            widget: 'Animated${match.group(1)}',
            parameter: parameter,
            expression: expression,
          ),
        );
      }
    }
  }

  return sites;
}

/// Replaces comment and string bodies with spaces, preserving length so offsets
/// and line numbers still line up with the original file.
String _blankCommentsAndStrings(String source) {
  final out = source.split('');
  var i = 0;

  void blank(int from, int to) {
    for (var j = from; j < to && j < out.length; j++) {
      if (out[j] != '\n') out[j] = ' ';
    }
  }

  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      final stop = end == -1 ? source.length : end;
      blank(i, stop);
      i = stop;
      continue;
    }
    if (source.startsWith('/*', i)) {
      // Dart block comments nest.
      var depth = 0;
      var j = i;
      while (j < source.length) {
        if (source.startsWith('/*', j)) {
          depth++;
          j += 2;
        } else if (source.startsWith('*/', j)) {
          depth--;
          j += 2;
          if (depth == 0) break;
        } else {
          j++;
        }
      }
      blank(i, j);
      i = j;
      continue;
    }

    final quote = _quoteAt(source, i);
    if (quote != null) {
      final start = i + quote.length;
      var j = start;
      while (j < source.length) {
        if (source[j] == r'\') {
          j += 2;
          continue;
        }
        if (source.startsWith(quote, j)) break;
        j++;
      }
      blank(start, j);
      i = (j < source.length ? j : source.length) + quote.length;
      continue;
    }

    i++;
  }

  return out.join();
}

/// The quote token opening a string literal at [i], longest first, or null.
String? _quoteAt(String source, int i) {
  for (final quote in const ["'''", '"""', "'", '"']) {
    if (source.startsWith(quote, i)) return quote;
  }
  return null;
}

int? _matchingParen(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    switch (source[i]) {
      case '(':
      case '[':
      case '{':
        depth++;
      case ')':
      case ']':
      case '}':
        depth--;
        if (depth == 0) return i;
    }
  }
  return null;
}

/// The value of top-level named argument [name] within an argument list.
String? _namedArgument(String args, String name) {
  final label = RegExp('(^|[,\\s])$name\\s*:');
  var depth = 0;
  for (var i = 0; i < args.length; i++) {
    final char = args[i];
    if (char == '(' || char == '[' || char == '{') depth++;
    if (char == ')' || char == ']' || char == '}') depth--;
    if (depth != 0) continue;

    final match = label.matchAsPrefix(args, i == 0 ? 0 : i - 1);
    if (match == null) continue;

    var j = match.end;
    var valueDepth = 0;
    final buffer = StringBuffer();
    while (j < args.length) {
      final c = args[j];
      if (c == '(' || c == '[' || c == '{') valueDepth++;
      if (c == ')' || c == ']' || c == '}') valueDepth--;
      if (c == ',' && valueDepth == 0) break;
      buffer.write(c);
      j++;
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  return null;
}
