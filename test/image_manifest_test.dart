import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic image manifest references existing workspace assets', () {
    final manifest =
        jsonDecode(File('assets/images/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final assets = manifest['assets'] as Map<String, dynamic>;

    expect(assets, isNotEmpty);
    for (final entry in assets.entries) {
      final spec = entry.value as Map<String, dynamic>;
      final path = spec['path'] as String;
      final label = spec['semantic_label'] as String;
      expect(File(path).existsSync(), isTrue, reason: entry.key);
      expect(label.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('every incomplete art family declares a deterministic fallback', () {
    final manifest =
        jsonDecode(File('assets/images/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final fallbacks = manifest['fallbacks'] as Map<String, dynamic>;

    expect(
      fallbacks.keys,
      containsAll(['unit', 'vocabulary', 'scenario', 'badge']),
    );
    expect(fallbacks.values, everyElement(isNotEmpty));
  });
}
