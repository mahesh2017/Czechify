import 'package:czechify/data/repositories/curriculum_entitlement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses the last server result for the same user while offline', () async {
    final online = CurriculumEntitlementRepository(
      fetchRemote:
          (_) async => {
            'unlock_all': true,
            'expires_at': '2030-01-02T03:04:05Z',
            'reason': 'Internal review',
          },
    );

    final fetched = await online.load('user-a');
    expect(fetched.unlockAll, isTrue);
    expect(fetched.reason, 'Internal review');

    final offline = CurriculumEntitlementRepository(
      fetchRemote: (_) async => throw Exception('offline'),
    );
    final cached = await offline.load('user-a');

    expect(cached.unlockAll, isTrue);
    expect(cached.expiresAt, DateTime.utc(2030, 1, 2, 3, 4, 5));
  });

  test('never carries cached access into another account', () async {
    final online = CurriculumEntitlementRepository(
      fetchRemote: (_) async => {'unlock_all': true},
    );
    await online.load('user-a');

    final offline = CurriculumEntitlementRepository(
      fetchRemote: (_) async => throw Exception('offline'),
    );

    expect((await offline.load('user-b')).unlockAll, isFalse);
  });

  test('an authoritative missing row revokes the cached result', () async {
    final granted = CurriculumEntitlementRepository(
      fetchRemote: (_) async => {'unlock_all': true},
    );
    await granted.load('user-a');

    final revoked = CurriculumEntitlementRepository(
      fetchRemote: (_) async => null,
    );
    expect((await revoked.load('user-a')).unlockAll, isFalse);

    final offline = CurriculumEntitlementRepository(
      fetchRemote: (_) async => throw Exception('offline'),
    );
    expect((await offline.load('user-a')).unlockAll, isFalse);
  });

  test('expired access remains representable but is inactive', () async {
    final repository = CurriculumEntitlementRepository(
      fetchRemote:
          (_) async => {
            'unlock_all': true,
            'expires_at': '2026-01-01T00:00:00Z',
          },
    );

    final entitlement = await repository.load('user-a');
    expect(entitlement.unlockAll, isTrue);
    expect(entitlement.isActiveAt(DateTime.utc(2026, 1, 1)), isFalse);
    expect(entitlement.isActiveAt(DateTime.utc(2025, 12, 31)), isTrue);
  });
}
