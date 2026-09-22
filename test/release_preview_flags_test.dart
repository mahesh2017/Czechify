import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The preview flags turn commercial features on without the server. A
/// release build must never honour them, or a stray dart-define would put a
/// paywall in front of every learner. Tests run in debug mode, so this reads
/// the source: every preview flag is guarded by `!kReleaseMode`.
void main() {
  test('every monetization preview flag is off in release builds', () {
    final flags = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in RegExp(
        r"const (\w+) =\s*([^;]*?)bool\.fromEnvironment\('MONETIZATION_\w+_PREVIEW'\)",
      ).allMatches(source)) {
        flags.add(match.group(1)!);
        expect(
          match.group(2),
          contains('!kReleaseMode &&'),
          reason: '${match.group(1)} in ${file.path} could turn on in release',
        );
      }
    }
    expect(flags, hasLength(4), reason: 'the regex must find every flag');
  });
}
