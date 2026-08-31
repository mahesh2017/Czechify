import 'package:czechify/core/config/release_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audio manifest URL changes with bundled content revision', () {
    expect(
      ReleaseConfig.audioManifestUrl('https://example.test/manifest.json'),
      'https://example.test/manifest.json?v='
      '${ReleaseConfig.bundledContentRevision}',
    );
  });

  test('audio clip checksum bypasses stale CDN bytes', () {
    expect(
      ReleaseConfig.audioClipUrl('https://example.test/clip.mp3', 'abc123'),
      'https://example.test/clip.mp3?v=abc123',
    );
    expect(
      ReleaseConfig.audioClipUrl('https://example.test/clip.mp3', null),
      'https://example.test/clip.mp3',
    );
  });
}
