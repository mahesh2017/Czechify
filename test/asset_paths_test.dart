import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every illustration a lesson names has to be on disk.
///
/// The paths live in content, not in code, so nothing type-checks them: a
/// renamed or re-encoded file leaves the JSON pointing at something that is
/// gone, and the only symptom is a broken-image icon on one exercise deep in
/// one unit. The re-encode to WebP moved 92 of these at once, which is exactly
/// the operation this guards.
void main() {
  final reference = RegExp(r'assets/images/[A-Za-z0-9_./-]+\.(?:png|webp|svg)');

  test('every image a lesson names exists on disk', () {
    final missing = <String, Set<String>>{};
    var found = 0;

    for (final file in Directory('assets/curriculum')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      for (final match in reference.allMatches(file.readAsStringSync())) {
        final path = match.group(0)!;
        found++;
        if (!File(path).existsSync()) {
          missing.putIfAbsent(file.path, () => <String>{}).add(path);
        }
      }
    }

    // A regex that silently matches nothing would otherwise pass forever.
    expect(
      found,
      greaterThanOrEqualTo(80),
      reason:
          'Expected the curriculum to name at least 80 illustrations; finding '
          'far fewer means this scan stopped seeing them, not that the '
          'content shrank.',
    );
    expect(
      missing,
      isEmpty,
      reason:
          'These lesson files name illustrations that are not on disk. If the '
          'files were re-encoded, rerun tool/compress_images.py and update the '
          'references with them.',
    );
  });

  test('every image a screen names literally exists on disk', () {
    final missing = <String, Set<String>>{};

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final match in reference.allMatches(source)) {
        final path = match.group(0)!;
        // Interpolated paths ('teacher_$gender.png') resolve at runtime; the
        // literal fragment around the hole is not itself an asset.
        if (path.contains(r'$')) continue;
        if (!File(path).existsSync()) {
          missing.putIfAbsent(file.path, () => <String>{}).add(path);
        }
      }
    }

    expect(missing, isEmpty);
  });

  test('the alpha images that stay PNG are still PNG', () {
    // tool/compress_images.py skips these deliberately: two launcher-icon
    // sources that flutter_launcher_icons reads from pubspec.yaml, four Google
    // sign-in brand buttons, and the two teacher portraits. If one turns up as
    // WebP, the icon build or the brand asset has been quietly re-encoded.
    for (final name in const [
      'app_icon',
      'app_icon_foreground',
      'google_sign_in_android_dark',
      'google_sign_in_android_light',
      'google_sign_in_ios_dark',
      'google_sign_in_ios_light',
      'teacher_female',
      'teacher_male',
    ]) {
      expect(
        File('assets/images/$name.png').existsSync(),
        isTrue,
        reason: '$name.png must stay a PNG',
      );
      expect(
        File('assets/images/$name.webp').existsSync(),
        isFalse,
        reason: '$name was re-encoded but must stay a PNG',
      );
    }
  });
}
