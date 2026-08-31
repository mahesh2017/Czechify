import 'package:czechify/data/content/curriculum_pack_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const verifier = ContentReleaseVerifier();
  const key = 'assets/curriculum/test.json';
  final content = {
    'nested': {'b': 2, 'a': 1},
    'items': [true, 'česky'],
  };
  final checksum = verifier.checksum(content);
  final ref = PackRef(packKey: key, version: 3, checksum: checksum);
  final release = ContentRelease(
    releaseId: 'release-3',
    version: 3,
    contentChecksum: verifier.aggregateChecksum([ref]),
    packRefs: [ref],
  );

  test('accepts exact versioned packs with canonical JSON checksums', () {
    expect(
      () => verifier.verify(
        release: release,
        requiredPackKeys: {key},
        packs: {key: (version: 3, checksum: checksum, content: content)},
      ),
      returnsNormally,
    );
    expect(
      verifier.checksum({
        'items': [true, 'česky'],
        'nested': {'a': 1, 'b': 2},
      }),
      checksum,
    );
  });

  test('rejects content corruption even when row identity looks valid', () {
    expect(
      () => verifier.verify(
        release: release,
        requiredPackKeys: {key},
        packs: {
          key: (version: 3, checksum: checksum, content: {'changed': true}),
        },
      ),
      throwsStateError,
    );
  });

  test('rejects wrong versions, incomplete sets, and aggregate tampering', () {
    expect(
      () => verifier.verify(
        release: release,
        requiredPackKeys: {key},
        packs: {key: (version: 2, checksum: checksum, content: content)},
      ),
      throwsStateError,
    );
    expect(
      () => verifier.verify(
        release: release,
        requiredPackKeys: {key, 'assets/curriculum/missing.json'},
        packs: {key: (version: 3, checksum: checksum, content: content)},
      ),
      throwsStateError,
    );
    final tamperedRelease = ContentRelease(
      releaseId: release.releaseId,
      version: release.version,
      contentChecksum: List.filled(64, '0').join(),
      packRefs: release.packRefs,
    );
    expect(
      () => verifier.verify(
        release: tamperedRelease,
        requiredPackKeys: {key},
        packs: {key: (version: 3, checksum: checksum, content: content)},
      ),
      throwsStateError,
    );
  });
}
